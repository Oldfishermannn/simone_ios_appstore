import Foundation

@inline(__always)
private func spliceDbg(_ msg: @autoclosure () -> String) {
    #if DEBUG
    let t = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
    print("[Splice \(String(format: "%.3f", t))] \(msg())")
    #endif
}

/// v1.3 · Lock 无缝续接核心 · 客户端 20s ring buffer + 重连期 fallback loop。
///
/// 机制：
/// 1. AudioEngine.handleAudioChunk 分叉每个 Lyria chunk 到本类的 ring buffer
/// 2. LyriaClient.reconnectAndRestore 起点调 beginFallbackLoop() → 把 ring buffer 最近 20s
///    切片多 chunk enqueue 进 AudioEngine.bufferQueue 循环播放，覆盖重连空档
/// 3. onReconnected 回调调 endFallbackLoop(crossfade:) → 最后一批 loop 音频线性淡出，
///    同时 arm softFadeIn 让新 Lyria chunk 柔和进入
///
/// 线程安全：所有公开方法用 lock 保护。recordIncoming 在 LyriaClient 接收线程；
/// beginFallbackLoop / endFallbackLoop 从 main/AppState 线程调用。
final class SplicePlayback: @unchecked Sendable {
    // PCM 16-bit stereo 48kHz
    static let bytesPerSecond = 48_000 * 2 * 2   // 192_000
    static let ringSeconds = 20
    static let ringCapacity = bytesPerSecond * ringSeconds   // 3_840_000 B (~3.84 MB)

    // Loop 微接缝 crossfade：80ms equal-power（sin²/cos²）
    static let loopSeamMs: Int = 80
    static let loopSeamBytes = bytesPerSecond * loopSeamMs / 1000   // 15_360 B

    /// Ring buffer 底层存储（循环写入）
    private var ring: [UInt8] = Array(repeating: 0, count: ringCapacity)
    private var writeOffset: Int = 0
    private var recordedBytes: Int = 0   // 饱和后恒为 ringCapacity
    private let lock = NSLock()

    private(set) var isFallbackActive: Bool = false

    /// Fallback loop 期间，每"一轮"把多少秒的 data 塞进播放队列。
    /// 20s ring buffer → 切 10 段每段 ~2s，低延迟触发下一轮加样。
    private let fallbackChunkSeconds: Int = 2

    /// 调用方（AudioEngine）提供 enqueue 到播放队列的 closure —
    /// 解耦 SplicePlayback 不直接依赖 AudioBufferQueue。
    var enqueuePlayback: ((Data) -> Void)?

    /// 调用方（AudioEngine）提供 arm 软淡入 hook，endFallback 时触发。
    var armFadeIn: ((TimeInterval) -> Void)?

    /// 调用方（AudioEngine）提供 arm 软淡出 hook（新增对称 ramp）。
    var armFadeOut: ((TimeInterval) -> Void)?

    /// 调用方（AudioEngine）提供 flush scheduled playerNode 队列 hook。
    /// endFallbackLoop 在 fadeOut 完成后用它清掉 playerNode 内部残留的 fallback chunk。
    var flushPlayback: (() -> Void)?

    // MARK: - Public API

    /// 每个 Lyria chunk 到达时调用，append 到 ring buffer。溢出循环覆盖。
    func recordIncoming(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !chunk.isEmpty else { return }

        chunk.withUnsafeBytes { raw in
            guard let src = raw.baseAddress else { return }
            var written = 0
            let total = chunk.count
            while written < total {
                let space = Self.ringCapacity - writeOffset
                let toWrite = min(space, total - written)
                ring.withUnsafeMutableBufferPointer { dst in
                    memcpy(dst.baseAddress! + writeOffset,
                           src.advanced(by: written),
                           toWrite)
                }
                writeOffset = (writeOffset + toWrite) % Self.ringCapacity
                written += toWrite
            }
            recordedBytes = min(recordedBytes + total, Self.ringCapacity)
        }
    }

    /// 触发 fallback：读 ring buffer 最近内容，切成 chunk 塞进播放队列，
    /// 设 isFallbackActive = true。AudioEngine 应在其 drainQueue 检测到
    /// !isFallbackActive 之前的最后一 chunk 播完后再检查 fallback 是否还 active，
    /// 是 → 再次塞一轮；否则退出 fallback 模式恢复正常流。
    ///
    /// 简化实现：一次性塞**两轮**（40s）到 bufferQueue。Lyria 典型重连 1-5s，
    /// 极端 10-15s，40s 覆盖 99%+ 场景。若 40s 仍没回来，watchdog 会再触发
    /// 一轮 reconnect，SplicePlayback 也会被重新 begin。
    func beginFallbackLoop() {
        lock.lock()
        let available = recordedBytes
        guard available > 0, let enqueue = enqueuePlayback else {
            lock.unlock()
            spliceDbg("🟠 fallback loop SKIP (no recorded data)")
            return
        }

        // 提取有序的 playableData（从最旧到最新）
        let playableData = makeOrderedSnapshot()
        isFallbackActive = true
        lock.unlock()
        spliceDbg("🟠 fallback loop START (recorded=\(available / Self.bytesPerSecond)s)")

        // 处理 loop 接缝（equal-power crossfade 80ms）
        let seamed = applySeamCrossfade(playableData)

        // 切成 2s 一段的 chunk enqueue（塞两轮 = 40s 覆盖）
        let rounds = 2
        let chunkBytes = Self.bytesPerSecond * fallbackChunkSeconds
        for _ in 0..<rounds {
            var offset = 0
            while offset < seamed.count {
                let end = min(offset + chunkBytes, seamed.count)
                let slice = seamed.subdata(in: offset..<end)
                enqueue(slice)
                offset = end
            }
        }
    }

    /// 标记退出 fallback + fadeOut ramp → crossfade 秒后 flush playerNode 清残留 fallback
    /// + arm 新 chunk 的 fadeIn。
    ///
    /// 为什么要 flushPlayback：beginFallbackLoop 把 40s fallback 一次性 scheduleBuffer 到
    /// AVAudioPlayerNode 内部队列；armFadeOut 只 ramp 前 crossfade 秒到 0，剩余 fallback
    /// 会恢复满音量继续播。必须在 fadeOut 完成的瞬间 flush playerNode 才能让新 Lyria chunk
    /// 立即接上（否则听感 = 循环老音频 ~38.5s 后才出现新风格）。
    func endFallbackLoop(crossfade: TimeInterval) {
        lock.lock()
        isFallbackActive = false
        lock.unlock()
        spliceDbg("🟢 fallback loop END (crossfade=\(crossfade)s)")
        armFadeOut?(crossfade)
        DispatchQueue.main.asyncAfter(deadline: .now() + crossfade) { [weak self] in
            guard let self else { return }
            self.flushPlayback?()
            self.armFadeIn?(crossfade)
        }
    }

    /// 用户手操（切频道/切 style/换 visualizer）立即打断 fallback。
    /// AudioEngine 侧 clearQueue 后 splice 也要回到 idle。
    func abortFallback() {
        lock.lock()
        isFallbackActive = false
        lock.unlock()
    }

    // MARK: - Private

    /// 把 ring buffer 里的数据按时间顺序（最旧 → 最新）展平成一段 Data。
    /// 未饱和时从 [0, writeOffset)；饱和后从 writeOffset wrap 到 writeOffset。
    private func makeOrderedSnapshot() -> Data {
        var data = Data(capacity: recordedBytes)
        if recordedBytes < Self.ringCapacity {
            // 未饱和：数据是 [0, writeOffset)
            data.append(contentsOf: ring[0..<writeOffset])
        } else {
            // 饱和：[writeOffset, end) + [0, writeOffset)
            data.append(contentsOf: ring[writeOffset..<Self.ringCapacity])
            data.append(contentsOf: ring[0..<writeOffset])
        }
        return data
    }

    /// Equal-power crossfade：把 data 的 tail 80ms 和 head 80ms 做加权叠加，
    /// 结果覆盖到 head 80ms 上，并把 tail 80ms 去掉。loop 点无 click pop。
    ///
    /// sin²(θ) + cos²(θ) = 1 保证 RMS 恒定（equal power），优于线性 crossfade。
    /// θ 在 [0, π/2] 线性推进。
    private func applySeamCrossfade(_ data: Data) -> Data {
        let seamBytes = Self.loopSeamBytes
        guard data.count > seamBytes * 2 else { return data }

        let samplesPerSeam = seamBytes / 2   // Int16 stereo interleaved -> 2 bytes/sample/ch
        let channels = 2

        var mutable = data
        let headStart = 0
        let tailStart = data.count - seamBytes

        // 取出 Int16 视图
        mutable.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let base = raw.bindMemory(to: Int16.self).baseAddress else { return }
            let headPtr = base.advanced(by: headStart / 2)
            let tailPtr = base.advanced(by: tailStart / 2)
            let frameCount = samplesPerSeam / channels   // stereo frames
            for frame in 0..<frameCount {
                let theta = (Float.pi / 2) * Float(frame) / Float(frameCount)
                let gainHead = sin(theta)   // 0 → 1
                let gainTail = cos(theta)   // 1 → 0
                for ch in 0..<channels {
                    let idx = frame * channels + ch
                    let hv = Float(headPtr[idx]) * gainHead
                    let tv = Float(tailPtr[idx]) * gainTail
                    let mixed = max(-32768.0, min(32767.0, hv + tv))
                    headPtr[idx] = Int16(mixed)
                }
            }
        }

        // 去掉 tail seam（已经混进了 head）
        return mutable.subdata(in: 0..<(data.count - seamBytes))
    }
}

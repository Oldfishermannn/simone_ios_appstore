import AVFoundation
import Accelerate
import Observation

@Observable
final class AudioEngine {
    var spectrumData: [Float] = Array(repeating: 0, count: 64)
    var isPlaying = false
    var volume: Float = 0.65 {
        didSet { playerNode?.volume = volume }
    }

    private let sampleRate: Double = 48000
    private let channels: AVAudioChannelCount = 2
    private let bufferMin = 1
    private let fadeSamples = 48 // 1ms at 48kHz — imperceptible but kills pops

    // v1.3 · Lock 10min 跳风格修复：reconnectAndRestore 后对接下来的音频做软淡入，
    // 降低用户对「Lyria 重新生成新音乐」跳变的感知。
    // softFadeInTotal 是整段淡入的总长度（ramp 分母），softFadeInConsumed 是已处理的样本数，
    // 两者共同维持跨 drainQueue / 跨 buffer 的连续线性 ramp。
    private var softFadeInTotal: Int = 0
    private var softFadeInConsumed: Int = 0
    private let softFadeInLock = NSLock()

    // v1.3 · Lock 无缝续接：与 softFadeIn 对称的尾部 ramp，用于 fallback loop 结束时
    // 对末端音频线性淡出。语义：接下来播放的 softFadeOutTotal 个样本从 1.0 → 0 linear。
    private var softFadeOutTotal: Int = 0
    private var softFadeOutConsumed: Int = 0
    private let softFadeOutLock = NSLock()

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let bufferQueue = AudioBufferQueue()
    private var isDraining = false

    // v1.3 · Lock 无缝续接
    let splice = SplicePlayback()

    // v1.3 · playerNode.volume ramp timer（armSoftFadeOut 用；per-sample ramp 对已 scheduled
    // 的 fallback buffer 无效，必须用 node-level volume 实时衰减）
    private var volumeRampTimer: Timer?

    /// Tracks how many buffers are scheduled but not yet played
    private var scheduledBufferCount = 0
    private let scheduleLock = NSLock()

    // Playback watchdog — 卡死检测（isPlaying 但长时间无新 chunk 且 buffer 排空 → 触发外部重连）
    var onPlaybackStalled: (() -> Void)?
    private var lastChunkReceivedAt: Date?
    private var watchdogTimer: Timer?
    // v1.3 · Lock 10min 跳风格修复：10s → 20s。Lyria chunk 偶尔 >10s 间隔但不是真 stall，
    // 降低误触发频率，避免把自然的 chunk 抖动当成卡死而强制重连。
    private let stallThreshold: TimeInterval = 20

    // Interruption observer token
    private var interruptionObserver: NSObjectProtocol?

    // FFT
    private let fftSize = 2048
    private let displayBins = 64
    private var fftSetup: vDSP_DFT_Setup?
    private var logBinMap: [ClosedRange<Int>] = []

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        let nyquist = fftSize / 2
        let minFreqBin = 1
        let maxFreqBin = nyquist / 2  // Cap at ~12kHz — music content lives here
        let logMin = log2(Float(minFreqBin))
        let logMax = log2(Float(maxFreqBin))
        for i in 0..<displayBins {
            let t0 = Float(i) / Float(displayBins)
            let t1 = Float(i + 1) / Float(displayBins)
            let lo = Int(pow(2.0, logMin + t0 * (logMax - logMin)))
            let hi = max(lo, Int(pow(2.0, logMin + t1 * (logMax - logMin))) - 1)
            logBinMap.append(lo...min(hi, maxFreqBin))
        }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        // 增大 IO buffer（默认~5ms → 46ms），防止 UI 动画/截图导致的系统级 audio pop
        try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.046)
        try? AVAudioSession.sharedInstance().setActive(true)
        setupInterruptionObserver()
        #endif

        // Splice hooks：把录音-播放-ramp 三个能力注入给 SplicePlayback
        splice.enqueuePlayback = { [weak self] data in
            self?.bufferQueue.enqueue(data)
            self?.drainQueue()
        }
        splice.armFadeIn = { [weak self] duration in
            self?.armSoftFadeIn(duration: duration)
        }
        splice.armFadeOut = { [weak self] duration in
            self?.armSoftFadeOut(duration: duration)
        }
        splice.flushPlayback = { [weak self] in
            self?.flushScheduledBuffers()
        }

        // Pre-warm the entire audio pipeline at init
        // so the first real playback has zero transient pop
        warmUpEngine()
    }

    deinit {
        stop()
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
        removeInterruptionObserver()
    }

    private func warmUpEngine() {
        guard engine == nil else { return }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        player.volume = volume

        engine.attach(player)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        )!

        engine.connect(player, to: engine.mainMixerNode, format: format)

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: nil
        ) { [weak self] buffer, _ in
            self?.processFFT(buffer: buffer)
        }

        do {
            try engine.start()
            player.play()

            // Schedule silent buffer to fully activate the system audio graph
            if let silentBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: 4800
            ) {
                silentBuffer.frameLength = 4800
                player.scheduleBuffer(silentBuffer)
            }

            self.engine = engine
            self.playerNode = player
            // Don't set isPlaying = true, engine is just pre-warmed
        } catch {
            print("AudioEngine warmup failed: \(error)")
        }
    }

    func start() {
        // Engine is already warm from init
        if engine == nil {
            warmUpEngine()
        }
        isPlaying = true
        startWatchdog()
    }

    func stop() {
        playerNode?.stop()
        engine?.mainMixerNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        playerNode = nil
        isPlaying = false
        stopWatchdog()
        bufferQueue.clear()
        resetScheduledCount()
        spectrumData = Array(repeating: 0, count: displayBins)
    }

    func pause() {
        playerNode?.pause()
        isPlaying = false
        stopWatchdog()
    }

    func resume() {
        // Re-activate session in case it was deactivated
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if let engine, !engine.isRunning {
            try? engine.start()
        }
        playerNode?.play()
        isPlaying = true
        startWatchdog()
    }

    func handleAudioChunk(_ data: Data) {
        lastChunkReceivedAt = Date()
        // v1.3 · 分叉录到 ring buffer（用于 Lock 无缝续接 fallback loop）
        splice.recordIncoming(data)
        bufferQueue.enqueue(data)

        if !isDraining && bufferQueue.count >= bufferMin {
            drainQueue()
        } else if isDraining {
            drainQueue()
        }
    }

    func clearQueue() {
        splice.abortFallback()
        volumeRampTimer?.invalidate()
        volumeRampTimer = nil
        playerNode?.volume = 1.0
        softFadeOutLock.lock()
        softFadeOutTotal = 0
        softFadeOutConsumed = 0
        softFadeOutLock.unlock()
        bufferQueue.clear()
        isDraining = false
        resetScheduledCount()
    }

    /// v1.3 · Lock 10min 跳风格修复：安排下一批音频的软淡入。
    /// 典型用法：LyriaClient.reconnectAndRestore 成功重连后调用，duration≈0.5s，
    /// 新 session 第一批 chunk 渐入，降低跳变感知。
    func armSoftFadeIn(duration: TimeInterval) {
        let samples = max(0, Int(duration * sampleRate))
        softFadeInLock.lock()
        softFadeInTotal = samples
        softFadeInConsumed = 0
        softFadeInLock.unlock()
    }

    /// v1.3 · Lock 无缝续接：playerNode.volume ramp 1.0 → 0.0 over duration。
    /// 用 node-level volume 而不是 per-sample ramp——因为 fallback 已全 scheduleBuffer，
    /// per-sample ramp 对已 scheduled 的 buffer 无效（buffer PCM 内容已固定）。
    func armSoftFadeOut(duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let node = self.playerNode else { return }
            self.volumeRampTimer?.invalidate()
            node.volume = 1.0
            let steps = max(30, Int(duration * 60))
            let interval = duration / Double(steps)
            let delta: Float = -1.0 / Float(steps)
            var currentStep = 0
            self.volumeRampTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self, let node = self.playerNode else { timer.invalidate(); return }
                currentStep += 1
                if currentStep >= steps {
                    node.volume = 0.0
                    timer.invalidate()
                    self.volumeRampTimer = nil
                } else {
                    node.volume = 1.0 + delta * Float(currentStep)
                }
            }
        }
    }

    func flushScheduledBuffers() {
        splice.abortFallback()
        volumeRampTimer?.invalidate()
        volumeRampTimer = nil
        softFadeOutLock.lock()
        softFadeOutTotal = 0
        softFadeOutConsumed = 0
        softFadeOutLock.unlock()
        bufferQueue.clear()
        isDraining = false
        resetScheduledCount()
        playerNode?.stop()
        // v1.3 · reset volume 让新 chunk 能听见（armSoftFadeOut 把 volume ramp 到 0）
        playerNode?.volume = 1.0
        playerNode?.play()
    }

    // MARK: - Interruption Handling

    private func setupInterruptionObserver() {
        #if os(iOS)
        removeInterruptionObserver()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            if type == .ended {
                try? AVAudioSession.sharedInstance().setActive(true)
                if let engine = self.engine, !engine.isRunning {
                    try? engine.start()
                    self.playerNode?.play()
                }
            }
        }
        #endif
    }

    private func removeInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    // MARK: - Scheduled buffer tracking

    private var isUnderrun: Bool {
        scheduleLock.lock()
        defer { scheduleLock.unlock() }
        return scheduledBufferCount == 0
    }

    private func incrementScheduled() {
        scheduleLock.lock()
        scheduledBufferCount += 1
        scheduleLock.unlock()
    }

    private func decrementScheduled() {
        scheduleLock.lock()
        scheduledBufferCount = max(0, scheduledBufferCount - 1)
        scheduleLock.unlock()
    }

    private func resetScheduledCount() {
        scheduleLock.lock()
        scheduledBufferCount = 0
        scheduleLock.unlock()
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        stopWatchdog()
        lastChunkReceivedAt = Date()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkStall()
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func checkStall() {
        guard isPlaying, let last = lastChunkReceivedAt else { return }
        let elapsed = Date().timeIntervalSince(last)
        // 卡死条件：长时间没新 chunk + player 已经把 30s ring buffer 吃空
        if elapsed > stallThreshold, isUnderrun {
            // 先 bump 时间戳防止重复触发
            lastChunkReceivedAt = Date()
            DispatchQueue.main.async { [weak self] in
                self?.onPlaybackStalled?()
            }
        }
    }

    // MARK: - Buffer processing

    /// Apply fade-in to the beginning of a buffer
    private func applyFadeIn(_ buffer: AVAudioPCMBuffer, frames: Int) {
        let count = min(frames, Int(buffer.frameLength))
        for ch in 0..<Int(channels) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<count {
                data[i] *= Float(i) / Float(count)
            }
        }
    }

    /// Apply fade-out to the end of a buffer
    private func applyFadeOut(_ buffer: AVAudioPCMBuffer, frames: Int) {
        let total = Int(buffer.frameLength)
        let count = min(frames, total)
        let start = total - count
        for ch in 0..<Int(channels) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<count {
                data[start + i] *= Float(count - i) / Float(count)
            }
        }
    }

    /// v1.3 · 软淡入：把 softFadeInRemainingSamples 预算按样本顺序抹在 buffer 前缀上。
    /// 返回 buffer 真正消耗掉的 ramp 样本数，供外部调用方扣减全局预算。
    /// - Parameters:
    ///   - buffer: 目标 PCM buffer
    ///   - totalRampLength: 整段淡入的总长度（用于算线性比例，跨 buffer 保持连续）
    ///   - alreadyRamped: 这段淡入之前已经处理过的样本数
    /// - Returns: 本 buffer 内被处理的样本数
    private func applySoftFadeIn(
        _ buffer: AVAudioPCMBuffer,
        totalRampLength: Int,
        alreadyRamped: Int
    ) -> Int {
        guard totalRampLength > 0 else { return 0 }
        let bufferLen = Int(buffer.frameLength)
        let remaining = totalRampLength - alreadyRamped
        guard remaining > 0 else { return 0 }
        let count = min(remaining, bufferLen)
        for ch in 0..<Int(channels) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<count {
                let globalIndex = alreadyRamped + i
                let gain = Float(globalIndex) / Float(totalRampLength)
                data[i] *= gain
            }
        }
        return count
    }

    /// v1.3 · 对称软淡出：与 softFadeIn 镜像——处理 buffer 的前 count 个样本，
    /// gain 从 (1 - alreadyRamped/total) 递减到 ~0。跨 buffer 累加 alreadyRamped。
    /// 返回被处理的样本数供调用方扣减预算。
    private func applySoftFadeOut(
        _ buffer: AVAudioPCMBuffer,
        totalRampLength: Int,
        alreadyRamped: Int
    ) -> Int {
        guard totalRampLength > 0 else { return 0 }
        let bufferLen = Int(buffer.frameLength)
        let remaining = totalRampLength - alreadyRamped
        guard remaining > 0 else { return 0 }
        let count = min(remaining, bufferLen)
        for ch in 0..<Int(channels) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<count {
                let globalIndex = alreadyRamped + i
                let gain = 1.0 - Float(globalIndex) / Float(totalRampLength)
                data[i] *= gain
            }
        }
        return count
    }

    // MARK: - Private

    private func drainQueue() {
        guard let player = playerNode, let engine, engine.isRunning else { return }
        isDraining = true

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        )!

        let wasUnderrun = isUnderrun
        let chunks = bufferQueue.drainAll()

        // v1.3 · 软淡入：一次性快照当前 total/consumed，drain 循环内累加，收尾回写。
        // total 跨 drainQueue 保持不变（ramp 分母），consumed 跨 drain 累计（保证线性连续）。
        softFadeInLock.lock()
        let softFadeTotal = softFadeInTotal
        var softFadeConsumed = softFadeInConsumed
        softFadeInLock.unlock()

        for (idx, chunk) in chunks.enumerated() {
            let numBytes = chunk.count - (chunk.count % (Int(channels) * 2))
            guard numBytes > 0 else { continue }

            let numSamples = numBytes / (Int(channels) * 2)
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(numSamples)
            ) else { continue }

            pcmBuffer.frameLength = AVAudioFrameCount(numSamples)

            chunk.withUnsafeBytes { rawPtr in
                let int16Ptr = rawPtr.bindMemory(to: Int16.self)
                for ch in 0..<Int(channels) {
                    guard let channelData = pcmBuffer.floatChannelData?[ch] else { continue }
                    for i in 0..<numSamples {
                        channelData[i] = Float(int16Ptr[i * Int(channels) + ch]) / 32768.0
                    }
                }
            }

            // v1.3 · 软淡入必须先于 applyFadeIn，避免短 fadeSamples 的 1ms ramp 被软 ramp 压成 0。
            if softFadeTotal > 0 && softFadeConsumed < softFadeTotal {
                let consumed = applySoftFadeIn(
                    pcmBuffer,
                    totalRampLength: softFadeTotal,
                    alreadyRamped: softFadeConsumed
                )
                softFadeConsumed += consumed
            }

            // v1.3 · 软淡出（对称 ramp，fallback loop 收尾）
            softFadeOutLock.lock()
            let softOutTotal = softFadeOutTotal
            var softOutConsumed = softFadeOutConsumed
            softFadeOutLock.unlock()
            if softOutTotal > 0 && softOutConsumed < softOutTotal {
                let consumed = applySoftFadeOut(
                    pcmBuffer,
                    totalRampLength: softOutTotal,
                    alreadyRamped: softOutConsumed
                )
                softOutConsumed += consumed
                softFadeOutLock.lock()
                if softFadeOutTotal == softOutTotal {
                    softFadeOutConsumed = min(softOutConsumed, softOutTotal)
                }
                softFadeOutLock.unlock()
            }

            // Fade-in/out on every buffer: ensures all transitions are smooth
            // - Normal playback: buffer boundaries go through 0 seamlessly (1ms dip, inaudible)
            // - Underrun: both edges fade to/from 0, no pop
            applyFadeIn(pcmBuffer, frames: fadeSamples)
            applyFadeOut(pcmBuffer, frames: fadeSamples)

            incrementScheduled()
            player.scheduleBuffer(pcmBuffer) { [weak self] in
                self?.decrementScheduled()
            }
        }

        // 回写已消耗的样本数；ramp 结束后（consumed >= total）后续 buffer 走全增益
        if softFadeTotal > 0 {
            softFadeInLock.lock()
            // 只在没被 armSoftFadeIn 重置的前提下累加（比较 total 是否还是那批）
            if softFadeInTotal == softFadeTotal {
                softFadeInConsumed = min(softFadeConsumed, softFadeTotal)
            }
            softFadeInLock.unlock()
        }
    }

    private func processFFT(buffer: AVAudioPCMBuffer) {
        guard let setup = fftSetup,
              let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

        var realIn = [Float](repeating: 0, count: fftSize)
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        for i in 0..<fftSize {
            let window = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(fftSize)))
            realIn[i] = channelData[i] * window
        }

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        let nyquist = fftSize / 2
        var linearMags = [Float](repeating: 0, count: nyquist)
        for i in 0..<nyquist {
            linearMags[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        var mapped = [Float](repeating: 0, count: displayBins)
        var globalMax: Float = 0
        vDSP_maxv(linearMags, 1, &globalMax, vDSP_Length(nyquist))
        let normFactor: Float = globalMax > 0 ? 1.0 / globalMax : 0

        for i in 0..<displayBins {
            let range = logBinMap[i]
            var maxVal: Float = 0
            for bin in range {
                maxVal = max(maxVal, linearMags[bin])
            }
            mapped[i] = sqrt(maxVal * normFactor)
        }

        var smoothed = [Float](repeating: 0, count: displayBins)
        for i in 0..<displayBins {
            let lo = max(0, i - 1)
            let hi = min(displayBins - 1, i + 1)
            smoothed[i] = (mapped[lo] + mapped[i] * 2 + mapped[hi]) / 4.0
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var newData = self.spectrumData
            // 不对称 IIR：attack 慢（视觉 fade-in，解决 play 恢复瞬间的割裂），
            // release 保留原速（暂停衰减动画已合适）。
            for i in 0..<self.displayBins {
                let old = newData[i]
                let next = smoothed[i]
                if next >= old {
                    newData[i] = old * 0.72 + next * 0.28
                } else {
                    newData[i] = old * 0.4 + next * 0.6
                }
            }
            self.spectrumData = newData
        }
    }
}

#if os(iOS)
import MediaPlayer
import UIKit

extension AudioEngine {
    func updateNowPlaying(
        scene: String,
        style: String?,
        tintRGB: (CGFloat, CGFloat, CGFloat)? = nil
    ) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = style ?? scene
        info[MPMediaItemPropertyArtist] = "Simone — AI Ambient Radio"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        // 没有 rate 的话锁屏有时不显示 artwork
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0

        let tint: UIColor = {
            if let rgb = tintRGB {
                return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            }
            return UIColor(red: 196/255, green: 166/255, blue: 157/255, alpha: 1)
        }()

        if let artwork = Self.makeArtwork(tint: tint, title: style ?? scene) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 切换锁屏播放状态（不重设 artwork/title，只改 rate）
    func setNowPlayingRate(_ rate: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func makeArtwork(tint: UIColor, title: String) -> UIImage? {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 渐变底（频道色 → 深色）
            let cg = ctx.cgContext
            let colors = [tint.cgColor, UIColor(white: 0.08, alpha: 1).cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            // "Simone" logo
            let brandAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .light),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .kern: 4
            ]
            let brandSize = ("Simone" as NSString).size(withAttributes: brandAttr)
            ("Simone" as NSString).draw(
                at: CGPoint(x: (size.width - brandSize.width) / 2, y: 180),
                withAttributes: brandAttr
            )

            // style/scene 副标题
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55)
            ]
            let subSize = (title as NSString).size(withAttributes: subAttr)
            (title as NSString).draw(
                at: CGPoint(x: (size.width - subSize.width) / 2, y: 260),
                withAttributes: subAttr
            )
        }
    }

    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void
    ) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        center.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
    }
}
#endif

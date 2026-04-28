import Foundation
import Observation

@inline(__always)
private func rotatorDbg(_ msg: @autoclosure () -> String) {
    #if DEBUG
    let t = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
    print("[Rotator \(String(format: "%.3f", t))] \(msg())")
    #endif
}

/// Proactive session rotation: 在 Lyria session 自然超时前 (T+540s) 主动启动 secondary
/// ws, 累积 1s 音频后 crossfade 旧→新, 消除 v1.3 reactive 路径的 38.5s 重复 loop 听感.
///
/// 设计: docs/proactive-rotation-design.md
/// V1 简化: 顺序 fadeOut → flush → fadeIn (复用现有 hooks). 接受 ~200-500ms 静音瞬间.
/// V2 升级: 真双源 PCM mix (待 V1 听感验证决定).
///
/// 触发: AppState.togglePlayPause 启动播放时调 armRotationTimer().
/// 取消: 用户切频道/暂停/sleep timer/播放停止时调 cancelRotation().
/// 失败兜底: secondary 5s 内未 onConnected → cancelRotation, primary 自然超时走 reactive.
@Observable
final class SessionRotator {
    enum State: String { case idle, rotating, warmingUp, crossfading }

    private(set) var state: State = .idle

    /// 当前活跃的 LyriaClient. AppState.lyriaClient 通过 computed property forward 到这里,
    /// 保证 swap 后 AppState 仍然透明引用 active client.
    private(set) var activeClient: LyriaClient

    private var secondary: LyriaClient?
    private weak var audioEngine: AudioEngine?

    /// Closure-based providers — secondary 启动后调用拿最新 prompts/config.
    /// AppState 在 init 时设一次, 不需要每个 sendPrompts/sendConfig 处同步.
    var promptsProvider: (() -> [WeightedPrompt])?
    var configProvider: (() -> [String: Any])?

    /// crossfade 完成后 SessionRotator 通知 AppState 重新绑定 hooks 到新 activeClient.
    var onActiveClientChanged: ((LyriaClient) -> Void)?

    private var rotationTimer: Timer?
    private var secondaryWarmupBuffer: [Data] = []
    private var secondaryWarmupBytes = 0

    // T+540s = 9 min. Lyria 自然超时 ~600s, 60s 安全窗.
    private static let rotationInterval: TimeInterval = 540
    // 1s 音频 (PCM 16-bit stereo 48kHz = 192_000 B/s)
    private static let warmupThreshold = 192_000
    private static let crossfadeDuration: TimeInterval = 1.5
    // secondary onConnected 5s 兜底
    private static let secondaryTimeout: TimeInterval = 5
    // v1.4 fix Bug 2: secondary connected 但不发 chunks (Lyria 异常)
    // 30s 仍未 commitCrossfade → cancel,避免 quota 浪费.
    private static let warmupTimeout: TimeInterval = 30

    init(initialClient: LyriaClient, audioEngine: AudioEngine) {
        self.activeClient = initialClient
        self.audioEngine = audioEngine
    }

    // MARK: - Public API (AppState 调用)

    /// 启动播放后 arm rotation timer (gated by FeatureFlags.proactiveRotation).
    /// 重复调用安全 (旧 timer invalidate).
    func armRotationTimer() {
        guard FeatureFlags.proactiveRotation else { return }
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(
            withTimeInterval: Self.rotationInterval,
            repeats: false
        ) { [weak self] _ in
            self?.startRotation()
        }
        rotatorDbg("⏱️ rotation timer armed (\(Int(Self.rotationInterval))s)")
    }

    /// 用户主动行为 (切台/暂停/停止/sleep) 时立即取消 rotation.
    /// 任何 state 都安全调用 (idempotent).
    func cancelRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        // v1.4 fix Bug 1: 如果在 .crossfading 期间 cancel, primary 已 fadeOut ramp 中,
        // 必须 stop ramp + reset volume,否则用户 resume 后是静音.
        if state == .crossfading {
            audioEngine?.cancelFadeOut()
        }
        if state != .idle {
            rotatorDbg("🚫 cancelRotation from state=\(state.rawValue)")
        }
        secondary?.disconnect()
        secondary = nil
        secondaryWarmupBuffer.removeAll()
        secondaryWarmupBytes = 0
        state = .idle
    }

    // MARK: - Private — Rotation lifecycle

    private func startRotation() {
        guard state == .idle else { return }
        // Re-check FeatureFlag here — covers race: timer armed when ON,
        // toggle OFF before timer fires. Without this, 已 armed timer 仍 startRotation.
        guard FeatureFlags.proactiveRotation else {
            rotatorDbg("⏸ FeatureFlag now disabled — skipping rotation")
            return
        }
        rotatorDbg("🔄 startRotation: launching secondary ws")
        state = .rotating

        let s = LyriaClient()
        // onAudioChunk 来自 receive thread — dispatch 到 main 保证 SessionRotator
        // 内部状态访问 thread-safe.
        s.onAudioChunk = { [weak self] data in
            DispatchQueue.main.async {
                self?.handleSecondaryChunk(data)
            }
        }
        s.onConnected = { [weak self] in
            // onConnected 已在 main (LyriaClient 内部 DispatchQueue.main.async)
            self?.handleSecondaryConnected()
        }
        secondary = s
        s.connect()

        // 5s 兜底: secondary 没在 5s 内 onConnected (即仍在 .rotating) → cancel
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.secondaryTimeout) { [weak self] in
            guard let self, self.state == .rotating else { return }
            rotatorDbg("⚠️ secondary timeout (\(Self.secondaryTimeout)s) — cancelRotation")
            self.cancelRotation()
            // 不重新 arm timer — 让 primary 自然超时走 reactive 路径,避免无限失败循环.
        }
    }

    private func handleSecondaryConnected() {
        guard state == .rotating else { return }
        let prompts = promptsProvider?() ?? []
        let config = configProvider?() ?? [:]
        rotatorDbg("✓ secondary onConnected — prompts=\(prompts.count) config keys=\(config.keys.count)")
        guard !prompts.isEmpty else {
            // 没有 prompts (selectedStyle == nil) → cancel,等下一轮
            rotatorDbg("⚠️ no prompts — cancelRotation")
            cancelRotation()
            return
        }
        secondary?.sendPrompts(prompts)
        secondary?.sendConfig(config)
        secondary?.sendCommand("play")
        state = .warmingUp

        // v1.4 fix Bug 2: warmup timeout watchdog —
        // secondary 30s 仍卡 .warmingUp (不发 chunks) → cancel + 让 primary 自然超时.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.warmupTimeout) { [weak self] in
            guard let self, self.state == .warmingUp else { return }
            rotatorDbg("⚠️ warmup timeout (\(Int(Self.warmupTimeout))s) — secondary not producing chunks")
            self.cancelRotation()
        }
    }

    private func handleSecondaryChunk(_ data: Data) {
        switch state {
        case .warmingUp:
            secondaryWarmupBuffer.append(data)
            secondaryWarmupBytes += data.count
            if secondaryWarmupBytes >= Self.warmupThreshold {
                commitCrossfade()
            }
        case .crossfading, .idle, .rotating:
            // crossfading: V1 丢弃 secondary chunks (避免 latency 累积);
            // idle/rotating: race condition (cancel 后但 chunk 仍在路上) → 丢弃.
            break
        }
    }

    private func commitCrossfade() {
        guard state == .warmingUp else { return }
        rotatorDbg("⚡ commitCrossfade (warmup=\(secondaryWarmupBytes / 1024)KB)")
        state = .crossfading

        // V1 顺序版: primary fadeOut 1.5s, secondary chunks 期间丢弃, 1.5s 后 swap.
        audioEngine?.armSoftFadeOut(duration: Self.crossfadeDuration)

        // 清掉 warmup buffer (V1 不 dump,避免 latency 累积)
        secondaryWarmupBuffer.removeAll()
        secondaryWarmupBytes = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.crossfadeDuration) { [weak self] in
            self?.completeCrossfade()
        }
    }

    private func completeCrossfade() {
        guard state == .crossfading else { return }  // 期间被 cancel
        guard let audioEngine, let new = secondary else {
            rotatorDbg("⚠️ completeCrossfade: missing audioEngine or secondary")
            cancelRotation()
            return
        }

        rotatorDbg("✅ completeCrossfade — promoting secondary to primary")

        // v1.4 fix Bug 4: 顺序矩阵 — flush 必须在 onAudioChunk 切换之前.
        // 若先切 onAudioChunk, secondary chunk 在 microsecond 窗口内可能到达 →
        // 进 audioEngine.bufferQueue → 紧接 flushScheduledBuffers 把它清掉.
        // 倒过来: flush + arm fadeIn 先, 再切 onAudioChunk → 新 chunks 进 fresh queue.

        // 1. flush primary 残留 buffer (清 queue, reset volume to 1.0)
        audioEngine.flushScheduledBuffers()
        // 2. arm fadeIn (per-sample ramp, 适用于下一个进入的 chunk)
        audioEngine.armSoftFadeIn(duration: Self.crossfadeDuration)
        // 3. 切换 secondary onAudioChunk → 直接喂 audioEngine (新 chunks 进 fresh queue)
        new.onAudioChunk = { [weak audioEngine] data in
            audioEngine?.handleAudioChunk(data)
        }
        new.onConnected = nil  // 不再需要

        // 3. swap activeClient + disconnect old primary
        let old = activeClient
        old.disconnect()
        activeClient = new
        secondary = nil
        state = .idle

        // 4. 通知 AppState 重新绑定 hooks (onConnected / onReconnectStarted / onReconnected)
        //    onAudioChunk 已在 step 1 绑定到 audioEngine, 不需要重新绑.
        onActiveClientChanged?(new)

        // 5. 重新 arm 下一轮 (T+540s 再触发)
        armRotationTimer()
    }
}

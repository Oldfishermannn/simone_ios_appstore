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

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let bufferQueue = AudioBufferQueue()
    private var isDraining = false

    /// Tracks how many buffers are scheduled but not yet played
    private var scheduledBufferCount = 0
    private let scheduleLock = NSLock()

    // Playback watchdog — 卡死检测（isPlaying 但长时间无新 chunk 且 buffer 排空 → 触发外部重连）
    var onPlaybackStalled: (() -> Void)?
    private var lastChunkReceivedAt: Date?
    private var watchdogTimer: Timer?
    private let stallThreshold: TimeInterval = 10

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
        bufferQueue.enqueue(data)

        if !isDraining && bufferQueue.count >= bufferMin {
            drainQueue()
        } else if isDraining {
            drainQueue()
        }
    }

    func clearQueue() {
        bufferQueue.clear()
        isDraining = false
        resetScheduledCount()
    }

    func flushScheduledBuffers() {
        bufferQueue.clear()
        isDraining = false
        resetScheduledCount()
        playerNode?.stop()
        // Restart player so it's ready for new buffers
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
            for i in 0..<self.displayBins {
                newData[i] = newData[i] * 0.4 + smoothed[i] * 0.6
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

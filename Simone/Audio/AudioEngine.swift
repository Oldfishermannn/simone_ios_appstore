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

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let bufferQueue = AudioBufferQueue()
    private var isDraining = false
    private var needsFadeIn = true // fade in first buffer after gap

    // Interruption observer token
    private var interruptionObserver: NSObjectProtocol?

    // FFT — use 2048 for better frequency resolution
    private let fftSize = 2048
    private let displayBins = 64
    private var fftSetup: vDSP_DFT_Setup?
    private var logBinMap: [ClosedRange<Int>] = []

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        let nyquist = fftSize / 2
        let minFreqBin = 1
        let maxFreqBin = nyquist - 1
        let logMin = log2(Float(minFreqBin))
        let logMax = log2(Float(maxFreqBin))
        for i in 0..<displayBins {
            let t0 = Float(i) / Float(displayBins)
            let t1 = Float(i + 1) / Float(displayBins)
            let lo = Int(pow(2.0, logMin + t0 * (logMax - logMin)))
            let hi = max(lo, Int(pow(2.0, logMin + t1 * (logMax - logMin))) - 1)
            logBinMap.append(lo...min(hi, maxFreqBin))
        }
    }

    deinit {
        stop()
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    func start() {
        guard engine == nil else { return }

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
        setupInterruptionObserver()
        #endif

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
            self.engine = engine
            self.playerNode = player
            self.needsFadeIn = true
            isPlaying = true
        } catch {
            print("AudioEngine start failed: \(error)")
        }
    }

    func stop() {
        playerNode?.stop()
        engine?.mainMixerNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        playerNode = nil
        isPlaying = false
        bufferQueue.clear()
        needsFadeIn = true
        spectrumData = Array(repeating: 0, count: displayBins)
        removeInterruptionObserver()
    }

    func pause() {
        playerNode?.pause()
        isPlaying = false
    }

    func resume() {
        needsFadeIn = true
        playerNode?.play()
        isPlaying = true
    }

    func handleAudioChunk(_ data: Data) {
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
        needsFadeIn = true
    }

    func flushScheduledBuffers() {
        bufferQueue.clear()
        isDraining = false
        needsFadeIn = true
        playerNode?.stop()
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

            switch type {
            case .began:
                break // mixWithOthers prevents engine stop
            case .ended:
                try? AVAudioSession.sharedInstance().setActive(true)
                if let engine = self.engine, !engine.isRunning {
                    try? engine.start()
                    self.playerNode?.play()
                }
                self.needsFadeIn = true
            @unknown default:
                break
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

    // MARK: - Private

    private func drainQueue() {
        guard let player = playerNode, let engine, engine.isRunning else { return }
        isDraining = true

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        )!

        let chunks = bufferQueue.drainAll()
        for chunk in chunks {
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

            // Apply fade-in on first buffer after a gap to prevent pop
            if needsFadeIn {
                let fadeFrames = min(numSamples, 480) // 10ms at 48kHz
                for ch in 0..<Int(channels) {
                    guard let channelData = pcmBuffer.floatChannelData?[ch] else { continue }
                    for i in 0..<fadeFrames {
                        let gain = Float(i) / Float(fadeFrames)
                        channelData[i] *= gain
                    }
                }
                needsFadeIn = false
            }

            player.scheduleBuffer(pcmBuffer)
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

extension AudioEngine {
    func updateNowPlaying(scene: String, style: String?) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = style.map { "\(scene) × \($0)" } ?? scene
        info[MPMediaItemPropertyArtist] = "Simone"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
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

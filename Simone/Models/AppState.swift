import Foundation
import Observation

@Observable
final class AppState {
    // Selection
    var selectedStyle: MoodStyle? = nil
    var selectedVisualizer: VisualizerStyle = .horizon

    // Style history (for previous/next navigation)
    var styleHistory: [MoodStyle] = []

    // Explore (kept for compatibility)
    var exploredStyles: [MoodStyle] = []
    var exploredIndex: Int = 0

    // Pinned (persisted)
    var pinnedStyles: [MoodStyle] = []

    // Playback
    var isGenerating = false
    var statusMessage = ""

    // Auto-Evolve
    enum EvolveMode: String, CaseIterable {
        case locked = "锁定"
        case auto10s = "10 sec"
        case auto1m = "1 min"
        case auto5m = "5 min"
    }
    var evolveMode: EvolveMode = .auto10s {
        didSet { restartEvolveTimer() }
    }
    private var evolveTimer: Timer?

    // Playback Mode
    enum PlaybackMode: String, CaseIterable {
        case sequential = "顺序"
        case shuffle = "随机"
    }
    var playbackMode: PlaybackMode = .sequential

    // Sleep Timer
    enum SleepDuration: Int, CaseIterable {
        case fifteen = 15
        case thirty = 30
        case sixty = 60
        case twoHours = 120

        var label: String {
            switch self {
            case .fifteen: "15分"
            case .thirty: "30分"
            case .sixty: "1小时"
            case .twoHours: "2小时"
            }
        }
    }
    var activeSleepDuration: SleepDuration? = nil
    var sleepTimerEnd: Date? = nil
    private var sleepTimer: Timer?

    // Config
    var temperature: Float = 1.1
    var guidance: Float = 4.0
    var bpm: Int = 0           // 0 = 由模型决定
    var density: Float = -1    // -1 = 由模型决定
    var brightness: Float = -1 // -1 = 由模型决定
    var topK: Int = 40
    var muteBass: Bool = false
    var muteDrums: Bool = false
    var onlyBassAndDrums: Bool = false
    var musicMode: String = "QUALITY"  // QUALITY / DIVERSITY / VOCALIZATION

    /// UI 切换参数后调用，立刻发送完整 config 给服务端
    func applyConfig() {
        guard lyriaClient.connectionState == .connected else { return }
        lyriaClient.sendConfig(buildFullConfig())
    }

    // Dependencies
    let audioEngine = AudioEngine()
    let lyriaClient = LyriaClient()

    private let pinnedKey = "pinnedStyles"

    init() {
        // Load pinned styles from UserDefaults
        if let data = UserDefaults.standard.data(forKey: pinnedKey),
           let decoded = try? JSONDecoder().decode([MoodStyle].self, from: data) {
            pinnedStyles = decoded
        }

        // Populate initial exploration list
        exploredStyles = MoodStyle.randomSelection(count: 4, excluding: [])

        lyriaClient.onAudioChunk = { [weak self] data in
            self?.audioEngine.handleAudioChunk(data)
        }
        lyriaClient.onConnected = { [weak self] in
            self?.sendCurrentPrompts()
        }
        #if os(iOS)
        audioEngine.setupRemoteCommandCenter(
            onPlay: { [weak self] in
                self?.lyriaClient.sendCommand("play")
                self?.audioEngine.resume()
            },
            onPause: { [weak self] in
                self?.lyriaClient.sendCommand("pause")
                self?.audioEngine.pause()
            }
        )
        #endif
    }

    // MARK: - Actions

    func selectStyle(_ style: MoodStyle) {
        selectedStyle = style
        applySelection()
    }

    func togglePlayPause() {
        if audioEngine.isPlaying {
            lyriaClient.sendCommand("pause")
            audioEngine.pause()
        } else if lyriaClient.connectionState == .connected {
            lyriaClient.sendCommand("play")
            audioEngine.resume()
        } else {
            // Auto-select first pinned style if nothing selected
            if selectedStyle == nil {
                if let first = pinnedStyles.first {
                    selectedStyle = first
                } else if let first = exploredStyles.first {
                    selectedStyle = first
                }
            }
            audioEngine.start()
            lyriaClient.connect()
            isGenerating = true
        }
    }

    func regenerate() {
        guard let style = selectedStyle else { return }
        let prompts = PromptBuilder.build(style: style)
        guard !prompts.isEmpty else { return }

        if lyriaClient.connectionState == .disconnected {
            audioEngine.start()
            lyriaClient.connect()
            isGenerating = true
        } else {
            audioEngine.clearQueue()
            // 重置 Lyria 上下文，强制全新生成
            lyriaClient.sendCommand("reset_context")
            let nudge = Float.random(in: -0.3...0.3)
            let config: [String: Any] = [
                "temperature": temperature + nudge,
                "guidance": guidance
            ]
            lyriaClient.sendConfig(config)
            lyriaClient.sendPrompts(prompts)
        }
    }

    func nextStyle() {
        if let current = selectedStyle {
            styleHistory.append(current)
        }
        let exclude = [selectedStyle?.id ?? ""]
        let next = MoodStyle.randomSelection(count: 1, excluding: exclude)
        if let style = next.first {
            selectStyle(style)
        }
    }

    func previousStyle() {
        guard let prev = styleHistory.popLast() else { return }
        selectStyle(prev)
    }

    // MARK: - Pin / Unpin

    func pinStyle(_ style: MoodStyle) {
        guard !pinnedStyles.contains(where: { $0.id == style.id }) else { return }
        pinnedStyles.append(style)
        savePinnedStyles()
    }

    func unpinStyle(_ style: MoodStyle) {
        pinnedStyles.removeAll { $0.id == style.id }
        savePinnedStyles()
    }

    // MARK: - Explore

    func exploreMore() {
        let excludedIDs = exploredStyles.map(\.id)
        let newStyles = MoodStyle.randomSelection(count: 4, excluding: excludedIDs)
        exploredStyles.append(contentsOf: newStyles)
    }

    // MARK: - Sleep Timer

    func startSleepTimer(_ duration: SleepDuration) {
        sleepTimer?.invalidate()
        activeSleepDuration = duration
        sleepTimerEnd = Date().addingTimeInterval(TimeInterval(duration.rawValue * 60))
        sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration.rawValue * 60), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.lyriaClient.sendCommand("pause")
            self.audioEngine.pause()
            self.activeSleepDuration = nil
            self.sleepTimerEnd = nil
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        activeSleepDuration = nil
        sleepTimerEnd = nil
    }

    // MARK: - Playlist

    func playNextInPlaylist() {
        guard !pinnedStyles.isEmpty else { return }
        let currentIndex = pinnedStyles.firstIndex(where: { $0.id == selectedStyle?.id })

        let next: MoodStyle
        switch playbackMode {
        case .sequential:
            let nextIndex = ((currentIndex ?? -1) + 1) % pinnedStyles.count
            next = pinnedStyles[nextIndex]
        case .shuffle:
            let available = pinnedStyles.filter { $0.id != selectedStyle?.id }
            next = available.randomElement() ?? pinnedStyles[0]
        }
        selectStyle(next)
    }

    func playPreviousInPlaylist() {
        guard !pinnedStyles.isEmpty else { return }
        let currentIndex = pinnedStyles.firstIndex(where: { $0.id == selectedStyle?.id })

        switch playbackMode {
        case .sequential:
            let prevIndex = ((currentIndex ?? 1) - 1 + pinnedStyles.count) % pinnedStyles.count
            selectStyle(pinnedStyles[prevIndex])
        case .shuffle:
            previousStyle()
        }
    }

    func refreshRecommendations() {
        exploredStyles = MoodStyle.generateNewStyles(count: 4)
    }

    // MARK: - Private

    private func savePinnedStyles() {
        if let data = try? JSONEncoder().encode(pinnedStyles) {
            UserDefaults.standard.set(data, forKey: pinnedKey)
        }
    }

    private func applySelection() {
        guard let style = selectedStyle else { return }
        let prompts = PromptBuilder.build(style: style)
        guard !prompts.isEmpty else { return }

        if lyriaClient.connectionState == .disconnected {
            audioEngine.start()
            lyriaClient.connect()
            isGenerating = true
        } else {
            if audioEngine.isPlaying {
                // 播放中切歌：只清队列，不打断播放
                audioEngine.clearQueue()
            } else {
                // 暂停状态切歌：flush 旧 buffer，保持暂停
                audioEngine.flushScheduledBuffers()
            }
            lyriaClient.sendPrompts(prompts)
        }
        #if os(iOS)
        audioEngine.updateNowPlaying(
            scene: "Simone",
            style: style.name
        )
        #endif
    }

    private func sendCurrentPrompts() {
        guard let style = selectedStyle else { return }
        let prompts = PromptBuilder.build(style: style)
        guard !prompts.isEmpty else { return }
        lyriaClient.sendPrompts(prompts)
        lyriaClient.sendCommand("play")
        lyriaClient.sendConfig(buildFullConfig())
    }

    private func buildFullConfig() -> [String: Any] {
        var config: [String: Any] = [
            "temperature": temperature,
            "guidance": guidance,
            "top_k": topK
        ]
        if bpm > 0 { config["bpm"] = bpm }
        if density >= 0 { config["density"] = density }
        if brightness >= 0 { config["brightness"] = brightness }
        if muteBass { config["mute_bass"] = true }
        if muteDrums { config["mute_drums"] = true }
        if onlyBassAndDrums { config["only_bass_and_drums"] = true }
        config["music_generation_mode"] = musicMode
        return config
    }

    // MARK: - Auto Evolve

    private func restartEvolveTimer() {
        evolveTimer?.invalidate()
        evolveTimer = nil

        let interval: TimeInterval
        switch evolveMode {
        case .locked: return
        case .auto10s: interval = 10
        case .auto1m: interval = 60
        case .auto5m: interval = 300
        }

        evolveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, self.audioEngine.isPlaying else { return }
            self.evolve()
        }
    }

    private func evolve() {
        guard let style = selectedStyle,
              lyriaClient.connectionState == .connected else { return }

        let newTemp = max(0.1, min(3.0, temperature + Float.random(in: -0.2...0.2)))
        let newGuidance = max(0.0, min(6.0, guidance + Float.random(in: -0.5...0.5)))
        temperature = newTemp
        guidance = newGuidance

        if density >= 0 {
            density = max(0.0, min(1.0, density + Float.random(in: -0.15...0.15)))
        }
        if brightness >= 0 {
            brightness = max(0.0, min(1.0, brightness + Float.random(in: -0.15...0.15)))
        }

        let config = buildFullConfig()
        lyriaClient.sendConfig(config)

        let prompts = PromptBuilder.build(style: style)
        lyriaClient.sendPrompts(prompts)
    }
}

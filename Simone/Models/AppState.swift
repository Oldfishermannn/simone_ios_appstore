import Foundation
import Observation

@Observable
final class AppState {
    // Selection
    var selectedStyle: MoodStyle? = nil
    var selectedVisualizer: VisualizerStyle = .horizon

    // Category navigation
    var currentCategory: StyleCategory = .lofi

    // Style history (for previous/next navigation)
    var styleHistory: [MoodStyle] = []

    // Pinned (persisted)
    var pinnedStyles: [MoodStyle] = []

    // Playback
    var isGenerating = false
    var statusMessage = ""

    // Auto-Evolve
    enum EvolveMode: String, CaseIterable {
        case locked = "Lock"
        case auto10s = "10 sec"
        case auto1m = "1 min"
        case auto5m = "5 min"
    }
    var evolveMode: EvolveMode = .auto10s {
        didSet { restartEvolveTimer() }
    }
    private var evolveTimer: Timer?

    // Sleep Timer
    enum SleepDuration: Int, CaseIterable {
        case thirty = 30
        case sixty = 60
        case twoHours = 120

        var label: String {
            switch self {
            case .thirty: "30 min"
            case .sixty: "1 hour"
            case .twoHours: "2 hours"
            }
        }
    }
    var activeSleepDuration: SleepDuration? = nil
    var sleepTimerEnd: Date? = nil
    private var sleepTimer: Timer?

    // Session Rotation — 规避 Lyria 长连接老化，25min 后主动在同频道内换台
    // 可逆：用户可在设置关闭，回退到"纯手动换台"行为
    var sessionRotationEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(sessionRotationEnabled, forKey: sessionRotationKey)
            if sessionRotationEnabled, audioEngine.isPlaying {
                restartSessionRotationTimer()
            } else {
                sessionRotationTimer?.invalidate()
                sessionRotationTimer = nil
            }
        }
    }
    private let sessionRotationKey = "sessionRotationEnabled"
    private let sessionRotationInterval: TimeInterval = 25 * 60  // 25min
    private var sessionRotationTimer: Timer?


    // Config
    var temperature: Float = 1.1
    var guidance: Float = 4.0
    var bpm: Int = 0           // 0 = model decides
    var density: Float = -1    // -1 = model decides
    var brightness: Float = -1 // -1 = model decides
    var topK: Int = 40
    var muteBass: Bool = false
    var muteDrums: Bool = false
    var onlyBassAndDrums: Bool = false
    var musicMode: String = "QUALITY"  // QUALITY / DIVERSITY / VOCALIZATION

    // Energy / Mood sliders (Max feature, sent as config)
    var energy: Float = 0.5    // 0..1
    var mood: Float = 0.5      // 0..1

    /// Apply current config to server
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

        // Load session rotation preference（首次启动默认开启）
        if UserDefaults.standard.object(forKey: sessionRotationKey) != nil {
            sessionRotationEnabled = UserDefaults.standard.bool(forKey: sessionRotationKey)
        }

        lyriaClient.onAudioChunk = { [weak self] data in
            self?.audioEngine.handleAudioChunk(data)
        }
        lyriaClient.onConnected = { [weak self] in
            self?.sendCurrentPrompts()
        }
        // 卡死自救：AudioEngine 发现 10s 无新 chunk + buffer 空 → 触发重连
        audioEngine.onPlaybackStalled = { [weak self] in
            guard let self, self.audioEngine.isPlaying else { return }
            self.statusMessage = "Recovering stream..."
            self.lyriaClient.disconnect()
            self.lyriaClient.connect()
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
            sessionRotationTimer?.invalidate()
            sessionRotationTimer = nil
        } else if lyriaClient.connectionState == .connected {
            lyriaClient.sendCommand("play")
            audioEngine.resume()
            restartSessionRotationTimer()
        } else {
            // Auto-select Lo-fi Chill preset if nothing selected
            if selectedStyle == nil {
                selectedStyle = MoodStyle.presets.first(where: { $0.id == "lofi-chill" })
                    ?? MoodStyle.presets.first
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

    /// Next style — cycles within current category
    func nextStyle() {
        if let current = selectedStyle {
            styleHistory.append(current)
        }
        let categoryStyles = MoodStyle.presets(for: currentCategory)
        guard !categoryStyles.isEmpty else { return }

        if let current = selectedStyle,
           let idx = categoryStyles.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = (idx + 1) % categoryStyles.count
            selectStyle(categoryStyles[nextIdx])
        } else {
            selectStyle(categoryStyles[0])
        }
    }

    /// Previous style — cycles within current category or pops history
    func previousStyle() {
        if let prev = styleHistory.popLast() {
            selectStyle(prev)
            return
        }
        let categoryStyles = MoodStyle.presets(for: currentCategory)
        guard !categoryStyles.isEmpty else { return }

        if let current = selectedStyle,
           let idx = categoryStyles.firstIndex(where: { $0.id == current.id }) {
            let prevIdx = (idx - 1 + categoryStyles.count) % categoryStyles.count
            selectStyle(categoryStyles[prevIdx])
        } else {
            selectStyle(categoryStyles.last!)
        }
    }

    /// Random style — used by Free tier (random radio)
    func randomStyle() {
        if let current = selectedStyle {
            styleHistory.append(current)
        }
        let exclude = [selectedStyle?.id ?? ""]
        let next = MoodStyle.randomSelection(count: 1, excluding: exclude)
        if let style = next.first {
            selectStyle(style)
        }
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

    func isPinned(_ style: MoodStyle) -> Bool {
        pinnedStyles.contains(where: { $0.id == style.id })
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
            self.sessionRotationTimer?.invalidate()
            self.sessionRotationTimer = nil
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
                audioEngine.clearQueue()
            } else {
                audioEngine.flushScheduledBuffers()
            }
            lyriaClient.sendPrompts(prompts)
        }
        restartSessionRotationTimer()
        #if os(iOS)
        audioEngine.updateNowPlaying(
            scene: currentCategory.displayName,
            style: style.name,
            tintRGB: Self.tintRGB(for: currentCategory)
        )
        #endif
    }

    #if os(iOS)
    /// 频道色→UIColor RGB 三元组（避免 UI 层依赖渗进 Audio 层）
    private static func tintRGB(for category: StyleCategory) -> (CGFloat, CGFloat, CGFloat) {
        switch category {
        case .lofi:       return (196/255, 166/255, 157/255)  // rose
        case .jazz:       return (201/255, 178/255, 135/255)  // sand
        case .blues:      return (146/255, 162/255, 181/255)  // blue
        case .rnb:        return (181/255, 160/255, 181/255)  // mauve
        case .rock:       return (180/255, 140/255, 140/255)
        case .pop:        return (190/255, 175/255, 160/255)
        case .electronic: return (146/255, 162/255, 181/255)
        case .classical:  return (166/255, 178/255, 156/255)  // sage
        case .ambient:    return (181/255, 160/255, 181/255)
        case .folk:       return (166/255, 178/255, 156/255)
        }
    }
    #endif

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

    // MARK: - Session Rotation（25min 自动在同频道内换台，规避 Lyria 长连接老化）

    private func restartSessionRotationTimer() {
        sessionRotationTimer?.invalidate()
        sessionRotationTimer = nil
        guard sessionRotationEnabled else { return }

        sessionRotationTimer = Timer.scheduledTimer(
            withTimeInterval: sessionRotationInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self, self.audioEngine.isPlaying else { return }
            // 同频道下一台，触发 applySelection → 再次 restart 定时器（形成滚动）
            self.nextStyle()
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

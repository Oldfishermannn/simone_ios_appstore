import Foundation
import Observation

@Observable
final class AppState {
    // Selection
    var selectedStyle: MoodStyle? = nil
    var selectedVisualizer: VisualizerStyle = .horizon

    // Category navigation
    var currentCategory: StyleCategory = .lofi

    // v1.1.1 top-level nav unit (Favorites + 10 categories).
    // currentCategory preserved as one-version fallback per reversibility policy.
    var currentChannel: Channel = .category(.lofi) {
        didSet { saveCurrentChannel() }
    }

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
    private let currentChannelKey = "currentChannel"

    init() {
        // v1.1.1 migration: clean up legacy key from v1.1.0's reverted session rotation.
        UserDefaults.standard.removeObject(forKey: "sessionRotationEnabled")

        // Load pinned styles from UserDefaults, re-tag any preset carried over from
        // the old 10-genre taxonomy (blues/pop/classical/ambient/folk) by looking up
        // the canonical definition in the new preset pool. User-generated presets
        // (id prefix "gen-") keep their current category field.
        if let data = UserDefaults.standard.data(forKey: pinnedKey),
           let decoded = try? JSONDecoder().decode([MoodStyle].self, from: data) {
            var needsRewrite = false
            pinnedStyles = decoded.map { old in
                if let canonical = MoodStyle.presets.first(where: { $0.id == old.id }),
                   canonical.category != old.category {
                    needsRewrite = true
                    return canonical
                }
                return old
            }
            if needsRewrite { savePinnedStyles() }
        }

        // Restore last channel (no didSet side-effect during init)
        if let raw = UserDefaults.standard.string(forKey: currentChannelKey),
           let channel = Channel(rawKey: raw) {
            currentChannel = channel
            selectedVisualizer = channel.visualizer
            if case .category(let c) = channel {
                currentCategory = c
            }
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

    // MARK: - Channel

    /// Styles visible in the current channel (pinned for Favorites, preset pool for categories).
    var stylesInCurrentChannel: [MoodStyle] {
        switch currentChannel {
        case .favorites:       return pinnedStyles
        case .category(let c): return MoodStyle.presets(for: c)
        }
    }

    /// Switch to a channel: persist, rebind visualizer, play the first preset.
    /// No-op if the channel is already active.
    func switchToChannel(_ channel: Channel) {
        guard channel != currentChannel else { return }
        currentChannel = channel
        selectedVisualizer = channel.visualizer
        if case .category(let c) = channel {
            currentCategory = c
        }
        styleHistory.removeAll()
        if let first = stylesInCurrentChannel.first {
            selectStyle(first)
        }
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
            #if os(iOS)
            audioEngine.setNowPlayingRate(0)
            #endif
        } else if lyriaClient.connectionState == .connected {
            lyriaClient.sendCommand("play")
            audioEngine.resume()
            pushNowPlaying()
        } else {
            // Auto-select Lo-fi Chill preset if nothing selected
            if selectedStyle == nil {
                selectedStyle = MoodStyle.presets.first(where: { $0.id == "lofi-chill" })
                    ?? MoodStyle.presets.first
            }
            audioEngine.start()
            lyriaClient.connect()
            isGenerating = true
            pushNowPlaying()
        }
    }

    /// 把当前风格同步到锁屏/控制中心，确保任意路径进入播放都有 NowPlaying
    private func pushNowPlaying() {
        #if os(iOS)
        guard let style = selectedStyle else { return }
        audioEngine.updateNowPlaying(
            scene: currentCategory.displayName,
            style: style.name,
            tintRGB: Self.tintRGB(for: currentCategory)
        )
        #endif
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

    /// Next style — cycles within the current channel (category preset pool, or pinned list for Favorites).
    func nextStyle() {
        let channelStyles = stylesInCurrentChannel
        guard !channelStyles.isEmpty else { return }  // Favorites empty → no-op
        if let current = selectedStyle {
            styleHistory.append(current)
        }

        if let current = selectedStyle,
           let idx = channelStyles.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = (idx + 1) % channelStyles.count
            selectStyle(channelStyles[nextIdx])
        } else {
            selectStyle(channelStyles[0])
        }
    }

    /// Previous style — pops history first, then cycles within the current channel.
    func previousStyle() {
        if let prev = styleHistory.popLast() {
            selectStyle(prev)
            return
        }
        let channelStyles = stylesInCurrentChannel
        guard !channelStyles.isEmpty else { return }

        if let current = selectedStyle,
           let idx = channelStyles.firstIndex(where: { $0.id == current.id }) {
            let prevIdx = (idx - 1 + channelStyles.count) % channelStyles.count
            selectStyle(channelStyles[prevIdx])
        } else {
            selectStyle(channelStyles.last!)
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

    private func saveCurrentChannel() {
        UserDefaults.standard.set(currentChannel.rawKey, forKey: currentChannelKey)
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
    /// 与 StyleCategory.color 保持一致，v1.1.1 新 10 调性 + legacy 兼容。
    private static func tintRGB(for category: StyleCategory) -> (CGFloat, CGFloat, CGFloat) {
        switch category {
        case .lofi:       return (196/255, 166/255, 157/255)  // 玉粉黛
        case .jazz:       return (201/255, 178/255, 135/255)  // 沙金
        case .rnb:        return (150/255, 108/255, 148/255)  // 茄紫
        case .rock:       return (140/255,  78/255,  84/255)  // 深酒红
        case .electronic: return (112/255, 182/255, 178/255)  // 霓虹青
        case .midnight:   return ( 74/255, 102/255, 140/255)  // 深海蓝
        case .cafe:       return (200/255, 146/255,  96/255)  // 琥珀橙
        case .rainy:      return (146/255, 162/255, 181/255)  // 雾灰蓝
        case .library:    return (178/255, 158/255, 132/255)  // 温棕米白
        case .dreamscape: return (150/255, 130/255, 190/255)  // 星紫
        // legacy fallbacks route to new category's color
        case .blues:      return (140/255,  78/255,  84/255)
        case .pop:        return (196/255, 166/255, 157/255)
        case .classical:  return (200/255, 146/255,  96/255)
        case .ambient:    return (146/255, 162/255, 181/255)
        case .folk:       return (200/255, 146/255,  96/255)
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

    private func evolve() {
        guard let style = selectedStyle,
              lyriaClient.connectionState == .connected else { return }

        // Prompt-level mutation: per-category vocab variant (primary signal).
        let prompts = PromptBuilder.evolveVariant(style: style)
        lyriaClient.sendPrompts(prompts)

        // Config-level perturbation: reduced amplitude — prompt variant is the main lever.
        let newTemp = max(0.1, min(3.0, temperature + Float.random(in: -0.1...0.1)))
        let newGuidance = max(0.0, min(6.0, guidance + Float.random(in: -0.25...0.25)))
        temperature = newTemp
        guidance = newGuidance

        if density >= 0 {
            density = max(0.0, min(1.0, density + Float.random(in: -0.08...0.08)))
        }
        if brightness >= 0 {
            brightness = max(0.0, min(1.0, brightness + Float.random(in: -0.08...0.08)))
        }

        lyriaClient.sendConfig(buildFullConfig())
    }
}

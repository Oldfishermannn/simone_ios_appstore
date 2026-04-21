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
        case auto30s = "30 sec"
        case auto1m = "1 min"
        case auto5m = "5 min"
    }
    // v1.2.1 default: auto1m — CEO 验收"撑 30 分钟不疲劳"需要持续 evolve，
    // 1min tick × 三维度调制（每次只动 1-2 维度）在 30 分钟内触发约 30 次
    // 微调，足够抗疲劳又不打破沉浸感。Lock 挡保留作为用户手动选项。
    var evolveMode: EvolveMode = .auto1m {
        didSet { restartEvolveTimer() }
    }
    private var evolveTimer: Timer?

    // Auto Tune — default OFF, fires nextStyle() every 25 min when playing.
    var autoTuneEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(autoTuneEnabled, forKey: "autoTuneEnabled")
            restartAutoTuneTimer()
        }
    }
    private var autoTuneTimer: Timer?

    // v1.2 Favorites 评审期：三选一可视化（firefly / letters / drawer）
    var favoritesVisualizer: VisualizerStyle = Channel.favoritesVisualizerPreference {
        didSet {
            UserDefaults.standard.set(favoritesVisualizer.rawValue, forKey: Channel.favoritesVisualizerKey)
            if currentChannel == .favorites {
                selectedVisualizer = favoritesVisualizer
            }
        }
    }

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
    // v1.2.1 · Lock 挡 temperature 从 1.1 → 0.8（RFC §8 Decision 1 = A 方案）。
    // Lyria 内部熵降低，Lock 听感更"实心"；evolve 不再抖 temperature，
    // 变化由三维度调制承担（RFC §1.2 根因 A）。
    var temperature: Float = 0.8
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

    // v1.2.1 · 三维度调制后台状态（RFC §2.1–§2.4）。
    // **不暴露 UI**（CEO 决策 #2），仅 evolve() 读写。不持久化（RFC §R5 特征不是 bug）。
    private var activeAccents: Set<String> = []
    private var activeOptionals: Set<String> = []
    private var currentDensity: Float = 0.6
    private var currentEnergy: Float = 0.55

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

        // Restore Auto Tune preference.
        // v1.2.1 一次性迁移：v1.1.x 时代 Auto Tune 默认 ON，老用户升级后即使 v1.1.1
        // 改默认 OFF，UserDefaults 里的 true 仍会保留，听到第 25 min 触发 nextStyle()
        // 导致"听着听着换风格"。这里一次性重置为 false，用户想开自己去 Settings 再开。
        let autoTuneMigrationKey = "autoTuneMigrationV121Done"
        if !UserDefaults.standard.bool(forKey: autoTuneMigrationKey) {
            UserDefaults.standard.set(false, forKey: "autoTuneEnabled")
            UserDefaults.standard.set(true, forKey: autoTuneMigrationKey)
        }
        autoTuneEnabled = UserDefaults.standard.bool(forKey: "autoTuneEnabled")

        // Restore last channel (no didSet side-effect during init)
        // v1.2: 频道收缩到 5 个，落在旧 channel 上则 fallback 到 lofi。
        if let raw = UserDefaults.standard.string(forKey: currentChannelKey),
           let channel = Channel(rawKey: raw),
           Channel.all.contains(channel) {
            currentChannel = channel
            selectedVisualizer = channel.visualizer
            if case .category(let c) = channel {
                currentCategory = c
            }
        }

        // 冷启动默认选 Lo-fi Chill 作为展示（直接赋值绕过 selectStyle 的播放副作用）
        if selectedStyle == nil {
            selectedStyle = MoodStyle.presets.first(where: { $0.id == "lofi-chill" })
        }

        lyriaClient.onAudioChunk = { [weak self] data in
            self?.audioEngine.handleAudioChunk(data)
        }
        lyriaClient.onConnected = { [weak self] in
            self?.sendCurrentPrompts()
        }
        // v1.3 · Lock 10min 无缝续接修复（升级版）：
        // - reconnectAndRestore 起点：立即从 ring buffer 开始播，覆盖 Lyria 重连空档
        // - onReconnected 成功：endFallbackLoop 做 1.5s crossfade 淡入新 session
        //   （原 0.5s armSoftFadeIn 由 endFallbackLoop 内部 armFadeIn hook 统一接管）
        lyriaClient.onReconnectStarted = { [weak self] in
            self?.audioEngine.splice.beginFallbackLoop()
        }
        lyriaClient.onReconnected = { [weak self] in
            self?.audioEngine.splice.endFallbackLoop(crossfade: 1.5)
        }
        // 卡死自救：AudioEngine 发现 20s 无新 chunk + buffer 空 → 触发会话轮转
        // v1.3 · Lock 10min 跳风格修复：改走 reconnectAndRestore（不走 onConnected
        // → 不触发 sendCurrentPrompts → 不发新 prompt），统一会话轮转逻辑，
        // 减少「Lyria 从零重新生成音乐」的听感跳变。
        audioEngine.onPlaybackStalled = { [weak self] in
            guard let self, self.audioEngine.isPlaying else { return }
            self.statusMessage = "Recovering stream..."
            self.lyriaClient.reconnectAndRestore()
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

    /// Switch to a channel: persist, rebind visualizer, queue up the first preset.
    /// No-op if the channel is already active.
    ///
    /// 关键：横滑频道不自动启动播放。selectStyle → applySelection 在
    /// 未连接时会 audioEngine.start + connect（为了响应用户选风格时"立
    /// 刻出声"的意图）。对频道横滑来说，用户并未按播放键，安静切换才
    /// 是电台感。所以：未连接时只更新 selectedStyle 不走 applySelection；
    /// 已连接时再把新 prompt 推给 Lyria 实现无缝切台。
    func switchToChannel(_ channel: Channel) {
        guard channel != currentChannel else { return }
        currentChannel = channel
        selectedVisualizer = channel.visualizer
        if case .category(let c) = channel {
            currentCategory = c
        }
        styleHistory.removeAll()
        guard let first = stylesInCurrentChannel.first else { return }
        if lyriaClient.connectionState == .disconnected {
            selectedStyle = first
        } else {
            selectStyle(first)
        }
    }

    // MARK: - Actions

    func selectStyle(_ style: MoodStyle) {
        selectedStyle = style
        selectedVisualizer = currentChannel.visualizer
        resetEvolveState(for: style.category)
        applySelection()
    }

    /// v1.2.1 · 切台时重置三维度状态（RFC 附录 B）。
    /// accent 取池内前 2 件、optional 取池内前 1 件，density/energy 回默认中值。
    /// 保证 Lock 挡下仍有 active 乐器被拼进 evolve prompt（如果 evolve 触发）。
    private func resetEvolveState(for category: StyleCategory) {
        let pool = category.instrumentPool
        activeAccents = Set(pool.accent.prefix(2))
        activeOptionals = Set(pool.optional.prefix(1))
        currentDensity = 0.6
        currentEnergy = 0.55
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
        case .auto30s: interval = 30
        case .auto1m: interval = 60
        case .auto5m: interval = 300
        }

        evolveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, self.audioEngine.isPlaying else { return }
            self.evolve()
        }
    }

    // MARK: - Auto Tune

    private func restartAutoTuneTimer() {
        autoTuneTimer?.invalidate()
        autoTuneTimer = nil
        guard autoTuneEnabled else { return }
        autoTuneTimer = Timer.scheduledTimer(withTimeInterval: 25 * 60, repeats: true) { [weak self] _ in
            guard let self, self.audioEngine.isPlaying else { return }
            self.nextStyle()
        }
    }

    /// v1.2.1 · 三维度调制 evolve（RFC §2.4）。
    /// 每 tick 只挑 1-2 个维度动，避免突变；Lock 挡由 restartEvolveTimer 过滤（return）。
    /// Temperature / guidance / brightness 不再由 evolve 抖动（交给手动 config）。
    private func evolve() {
        guard let style = selectedStyle,
              lyriaClient.connectionState == .connected else { return }

        // 1. 随机挑 1-2 个维度
        let picked = EvolveDimension.allCases.shuffled().prefix(Int.random(in: 1...2))

        // 2. 分别调制
        for dim in picked {
            switch dim {
            case .instruments:
                evolveInstruments(category: style.category, mode: evolveMode)
            case .density:
                currentDensity = ScalarWalk.next(currentDensity)
            case .energy:
                currentEnergy = ScalarWalk.next(currentEnergy)
            }
        }

        // 3. 重建 prompt（不 append！长度有界）
        let prompts = PromptBuilder.build(
            style: style,
            activeAccents: activeAccents,
            activeOptionals: activeOptionals,
            density: currentDensity,
            energy: currentEnergy
        )
        lyriaClient.sendPrompts(prompts)

        // 4. 同步 density 到 Lyria 原生 config（描述词 + 数值双保险）
        density = currentDensity
        lyriaClient.sendConfig(["density": currentDensity])
    }

    /// 乐器池加减：按挡位决定动 accent 还是 optional（RFC §2.1）。
    private func evolveInstruments(category: StyleCategory, mode: EvolveMode) {
        let pool = category.instrumentPool
        switch mode {
        case .locked:
            return  // Lock 挡不变 active（restartEvolveTimer 已拦截，此处冗余防御）
        case .auto30s:
            // 只动 optional，±1 件，上限 2
            toggleOne(from: pool.optional, in: &activeOptionals, maxSize: 2)
        case .auto1m:
            // 70% 动 accent（上限 3），30% 动 optional
            if Float.random(in: 0...1) < 0.7 {
                toggleOne(from: pool.accent, in: &activeAccents, maxSize: 3)
            } else {
                toggleOne(from: pool.optional, in: &activeOptionals, maxSize: 2)
            }
        case .auto5m:
            // 整组 reshuffle：accent 抽 2、optional 抽 1
            activeAccents = Set(pool.accent.shuffled().prefix(2))
            activeOptionals = Set(pool.optional.shuffled().prefix(1))
        }
    }

    /// 有状态的 ±1 加减：满了强制减、空了强制加、否则 50/50。
    private func toggleOne(from pool: [String], in active: inout Set<String>, maxSize: Int) {
        let shouldAdd: Bool
        if active.count >= maxSize { shouldAdd = false }
        else if active.isEmpty { shouldAdd = true }
        else { shouldAdd = Bool.random() }

        if shouldAdd {
            let candidates = pool.filter { !active.contains($0) }
            guard let pick = candidates.randomElement() else { return }
            active.insert(pick)
        } else {
            guard let drop = active.randomElement() else { return }
            active.remove(drop)
        }
    }
}

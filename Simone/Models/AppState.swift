import Foundation
import Observation

@Observable
final class AppState {
    // Selection
    var selectedStyle: MoodStyle? = nil
    var selectedVisualizer: VisualizerStyle = .aurora

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
    var evolveMode: EvolveMode = .locked

    // Config
    var temperature: Float = 1.1
    var guidance: Float = 4.0

    // Details card
    var isDetailsExpanded = false

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
        exploredStyles = MoodStyle.randomSelection(count: 8, excluding: [])

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
            // Stop current, clear, re-send with nudged temperature to force new generation
            lyriaClient.sendCommand("pause")
            audioEngine.clearQueue()

            lyriaClient.sendPrompts(prompts)

            let nudge = Float.random(in: -0.05...0.05)
            let config: [String: Any] = [
                "temperature": temperature + nudge,
                "guidance": guidance
            ]
            lyriaClient.sendConfig(config)
            lyriaClient.sendCommand("play")
            audioEngine.resume()
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
            // 直接切：清本地缓冲（立即静音）→ 发新 prompts（服务端热切换）
            audioEngine.clearQueue()
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

        let config: [String: Any] = [
            "temperature": temperature,
            "guidance": guidance
        ]
        lyriaClient.sendConfig(config)
    }
}

import Foundation
import Observation

@inline(__always)
private func lyriaDbg(_ msg: @autoclosure () -> String) {
    #if DEBUG
    let t = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
    print("[Lyria \(String(format: "%.3f", t))] \(msg())")
    #endif
}

enum LyriaConnectionState {
    case disconnected, connecting, connected, reconnecting
}

/// 直连 Google Gemini Live Music API（BYOK 模式，无需中间服务器）
@Observable
final class LyriaClient {
    var connectionState: LyriaConnectionState = .disconnected
    var statusMessage: String = ""

    var onAudioChunk: ((Data) -> Void)?
    var onConnected: (() -> Void)?
    /// v1.3 · Lock 10min 跳风格修复：reconnectAndRestore 成功续接时触发，
    /// 与 onConnected 区分（后者走 sendCurrentPrompts 重置路径）。
    /// 典型用途：让 AudioEngine 对新 session 第一批音频做软淡入。
    var onReconnected: (() -> Void)?
    // v1.3 · Lock 无缝续接：reconnectAndRestore 起点通知上层准备 fallback。
    // 与 onReconnected（重连成功）配对：started 在 cancel 老 ws 之前触发，
    // started 之后 AudioEngine 立即开始播 ring buffer 内容，覆盖空档。
    var onReconnectStarted: (() -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession
    private var autoReconnect = true
    private var reconnectAttempts = 0
    private var isSetupComplete = false
    /// v1.3 · reconnectAndRestore 主动 cancel 老 ws 时 set true；
    /// handleDisconnect 检查此 flag 决定是否触发自动重连（flag=true 时 skip，
    /// 因为本 session 已在主动重建中，避免嵌套重入）。
    /// setupComplete 或新 ws 失败路径 set false 恢复正常流。
    private var isIntentionallyRestarting = false

    // 记忆最后的参数，用于会话轮转后恢复
    private var lastPrompts: [WeightedPrompt]?
    private var lastConfig: [String: Any]?
    private var isPlaying = false

    private static let endpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateMusic"
    private static let model = "models/lyria-realtime-exp"

    init() {
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Public API (与旧接口完全兼容)

    func connect() {
        guard connectionState == .disconnected else { return }
        lyriaDbg("🔵 connect()")

        guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.statusMessage = "API Key not configured"
            }
            return
        }

        connectionState = .connecting
        statusMessage = "Connecting..."
        isSetupComplete = false
        reconnectAttempts = 0
        autoReconnect = true

        guard let url = URL(string: "\(Self.endpoint)?key=\(apiKey)") else {
            statusMessage = "Invalid API Key"
            connectionState = .disconnected
            return
        }

        let ws = session.webSocketTask(with: url)
        // Lyria 每个 audio chunk 的 base64 约 512KB，需要加大消息限制
        ws.maximumMessageSize = 4 * 1024 * 1024  // 4MB
        webSocket = ws
        ws.resume()

        // 发送 setup 消息
        let setup: [String: Any] = ["setup": ["model": Self.model]]
        sendJSON(setup)

        // 开始接收消息
        receiveMessage()
    }

    func disconnect() {
        autoReconnect = false
        isPlaying = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        statusMessage = "Disconnected"
        isSetupComplete = false
    }

    func sendPrompts(_ prompts: [WeightedPrompt]) {
        lastPrompts = prompts
        guard isSetupComplete else { return }

        let promptDicts = prompts.map { ["text": $0.text, "weight": $0.weight] as [String: Any] }
        let msg: [String: Any] = ["clientContent": ["weightedPrompts": promptDicts]]
        sendJSON(msg)
    }

    func sendCommand(_ command: String) {
        guard isSetupComplete else { return }

        let control: String
        switch command {
        case "play":
            control = "PLAY"
            isPlaying = true
        case "pause":
            control = "PAUSE"
            isPlaying = false
        case "stop":
            control = "STOP"
            isPlaying = false
        case "reset_context":
            control = "RESET_CONTEXT"
        default:
            return
        }
        sendJSON(["playbackControl": control])
    }

    func sendConfig(_ config: [String: Any]) {
        lastConfig = config
        guard isSetupComplete else { return }

        // 转换 key 名称：snake_case → camelCase（匹配 Gemini API 协议）
        var apiConfig: [String: Any] = [:]
        for (key, value) in config {
            let camelKey: String
            switch key {
            case "top_k": camelKey = "topK"
            case "mute_bass": camelKey = "muteBass"
            case "mute_drums": camelKey = "muteDrums"
            case "only_bass_and_drums": camelKey = "onlyBassAndDrums"
            case "music_generation_mode": camelKey = "musicGenerationMode"
            default: camelKey = key
            }
            apiConfig[camelKey] = value
        }
        sendJSON(["musicGenerationConfig": apiConfig])
    }

    // MARK: - Private

    private func resolveAPIKey() -> String? {
        // 优先使用用户自己的 Key
        if let userKey = KeychainHelper.loadAPIKey(), !userKey.isEmpty {
            return userKey
        }
        // 回退到内置试用 Key
        return APIKeyConfig.builtInKey
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(string)) { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.statusMessage = "Send failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()
            case .failure(let error):
                self.handleDisconnect(error: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonData: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return }
            jsonData = d
        case .data(let d):
            // Google Gemini WebSocket 发送 binary frames
            jsonData = d
        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return }

        if json["setupComplete"] != nil {
            // Setup 完成，可以发送命令了
            isSetupComplete = true
            DispatchQueue.main.async {
                self.connectionState = .connected
                self.reconnectAttempts = 0
                self.statusMessage = "Connected"
                self.onConnected?()
            }
        } else if let serverContent = json["serverContent"] as? [String: Any],
                  let audioChunks = serverContent["audioChunks"] as? [[String: Any]] {
            // 收到音频数据
            for chunk in audioChunks {
                if let b64String = chunk["data"] as? String,
                   let audioData = Data(base64Encoded: b64String) {
                    onAudioChunk?(audioData)
                }
            }
        } else if json["filteredPrompt"] != nil {
            DispatchQueue.main.async {
                self.statusMessage = "Prompt filtered by safety"
            }
        }
    }

    private func handleDisconnect(error: Error) {
        // v1.3 · 如果是 reconnectAndRestore 主动 cancel 老 ws 触发的，skip 不重连
        // （outer reconnectAndRestore 已在建新 ws，此处再重连 = 嵌套死循环）
        if isIntentionallyRestarting { return }

        let wasPlaying = isPlaying
        lyriaDbg("🔴 disconnect wasPlaying=\(wasPlaying)")
        isSetupComplete = false

        DispatchQueue.main.async {
            self.connectionState = wasPlaying ? .reconnecting : .disconnected
            self.statusMessage = wasPlaying ? "Reconnecting..." : "Disconnected"
        }

        // Lyria ~30s 超时自动断开，需要自动重连（会话轮转）
        if autoReconnect && wasPlaying {
            reconnectAttempts += 1
            let delay = min(Double(reconnectAttempts) * 0.5, 3.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.autoReconnect else { return }
                self.connectionState = .disconnected
                self.reconnectAndRestore()
            }
        } else if autoReconnect {
            reconnectAttempts += 1
            let delay = min(Double(reconnectAttempts) * 2.0, 15.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.autoReconnect else { return }
                self.connectionState = .disconnected
                self.connect()
            }
        }
    }

    /// 会话轮转：重连后自动恢复 prompts/config/播放状态（不触发 onConnected → 不走 sendCurrentPrompts）
    /// v1.3 起对外开放，onPlaybackStalled 卡死自救也改走这条路径，统一会话轮转逻辑。
    func reconnectAndRestore() {
        // v1.3 · 防重入：isIntentionallyRestarting flag 告诉 handleDisconnect
        // 这是我主动 cancel 老 ws，不要再触发自动重连（否则嵌套导致 fallback 40s
        // 被反复塞 playerNode → 频繁 flush → 听感"鬼畜一小段"）。
        guard !isIntentionallyRestarting else { return }
        guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else { return }

        isIntentionallyRestarting = true
        lyriaDbg("🟡 reconnectAndRestore() start")
        connectionState = .reconnecting
        isSetupComplete = false

        DispatchQueue.main.async { [weak self] in
            self?.onReconnectStarted?()
        }

        guard let url = URL(string: "\(Self.endpoint)?key=\(apiKey)") else { return }

        webSocket?.cancel(with: .goingAway, reason: nil)
        let ws = session.webSocketTask(with: url)
        ws.maximumMessageSize = 4 * 1024 * 1024
        webSocket = ws
        ws.resume()

        // 发送 setup
        sendJSON(["setup": ["model": Self.model]])

        // 用一个专门的接收循环来等 setupComplete，然后恢复状态
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                let msgData: Data?
                switch message {
                case .string(let text): msgData = text.data(using: .utf8)
                case .data(let d): msgData = d
                @unknown default: msgData = nil
                }
                if let msgData,
                   let json = try? JSONSerialization.jsonObject(with: msgData) as? [String: Any],
                   json["setupComplete"] != nil {
                    self.isSetupComplete = true
                    self.isIntentionallyRestarting = false
                    lyriaDbg("🟢 reconnect setupComplete")
                    DispatchQueue.main.async {
                        self.connectionState = .connected
                        self.reconnectAttempts = 0
                        self.statusMessage = "Reconnected"
                        // v1.3 · 通知上层：这是 reconnectAndRestore 而不是首次 connect，
                        // 上层（AppState）据此对 AudioEngine arm 软淡入降低跳变感知。
                        self.onReconnected?()
                    }
                    // 恢复之前的参数
                    if let prompts = self.lastPrompts {
                        self.sendPrompts(prompts)
                    }
                    if let config = self.lastConfig {
                        self.sendConfig(config)
                    }
                    if self.isPlaying {
                        self.sendJSON(["playbackControl": "PLAY"])
                    }
                }
                // 继续正常接收循环
                self.receiveMessage()
            case .failure(let error):
                // 新 ws 失败：清 flag，让 handleDisconnect 正常走自动重连路径
                self.isIntentionallyRestarting = false
                self.handleDisconnect(error: error)
            }
        }
    }
}

// MARK: - 内置试用 Key 配置

enum APIKeyConfig {
    /// 内置的试用 Key（Lyria 目前免费，供用户免费体验）
    /// 正式发布时通过 xcconfig 或环境变量注入，不硬编码在源码中
    static let builtInKey: String? = {
        // 优先从 Bundle 读取（可通过 xcconfig 注入）
        if let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        // 回退到内置试用 Key（XOR 混淆，防 strings 提取）
        let key = APIKeyObfuscator.resolve()
        return key.isEmpty ? nil : key
    }()
}

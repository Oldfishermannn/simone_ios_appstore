import Foundation
import Observation

enum LyriaConnectionState {
    case disconnected, connecting, connected, reconnecting
}

@Observable
final class LyriaClient {
    var connectionState: LyriaConnectionState = .disconnected
    var statusMessage: String = ""

    var onAudioChunk: ((Data) -> Void)?
    var onConnected: (() -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession
    private var serverURL: URL
    private var autoReconnect = true
    private var reconnectAttempts = 0

    init(serverURL: URL = URL(string: "ws://10.0.0.128:8765/ws")!) {
        self.serverURL = serverURL
        self.session = URLSession(configuration: .default)
    }

    func connect() {
        guard connectionState == .disconnected else { return }
        connectionState = .connecting
        statusMessage = "正在连接 Lyria..."

        webSocket = session.webSocketTask(with: serverURL)
        webSocket?.resume()
        receiveMessage()
    }

    func disconnect() {
        autoReconnect = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        statusMessage = "已断开"
    }

    func sendPrompts(_ prompts: [WeightedPrompt]) {
        send(PromptBuilder.toJSON(prompts: prompts))
    }

    func sendCommand(_ command: String) {
        send(PromptBuilder.commandJSON(command))
    }

    func sendConfig(_ config: [String: Any]) {
        send(PromptBuilder.configJSON(config))
    }

    private func send(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(string)) { [weak self] error in
            if let error {
                self?.statusMessage = "发送失败: \(error.localizedDescription)"
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
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            switch type {
            case "audio":
                if let b64String = json["data"] as? String,
                   let audioData = Data(base64Encoded: b64String) {
                    onAudioChunk?(audioData)
                }
            case "status":
                let msg = json["message"] as? String ?? ""
                DispatchQueue.main.async {
                    self.statusMessage = msg
                    if msg == "connected" {
                        self.connectionState = .connected
                        self.reconnectAttempts = 0
                        self.onConnected?()
                    } else if msg == "reconnecting" {
                        self.connectionState = .reconnecting
                    }
                }
            case "error":
                DispatchQueue.main.async {
                    self.statusMessage = json["message"] as? String ?? "未知错误"
                }
            default:
                break
            }
        case .data:
            break
        @unknown default:
            break
        }
    }

    private func handleDisconnect(error: Error) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.statusMessage = "连接断开"
        }
        if autoReconnect {
            reconnectAttempts += 1
            let delay = min(Double(reconnectAttempts) * 2.0, 15.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.connectionState = .disconnected
                self?.connect()
            }
        }
    }
}

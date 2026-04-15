import Foundation

struct WeightedPrompt: Codable {
    let text: String
    let weight: Float
}

enum PromptBuilder {
    static func build(style: MoodStyle) -> [WeightedPrompt] {
        [WeightedPrompt(text: style.prompt, weight: style.promptWeight)]
    }

    static func toJSON(prompts: [WeightedPrompt]) -> Data {
        let payload: [String: Any] = [
            "command": "set_prompts",
            "prompts": prompts.map { ["text": $0.text, "weight": $0.weight] }
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    static func commandJSON(_ command: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["command": command])
    }

    static func configJSON(_ config: [String: Any]) -> Data {
        let payload: [String: Any] = ["command": "set_config", "config": config]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}

import Foundation

struct WeightedPrompt: Codable {
    let text: String
    let weight: Float
}

enum PromptBuilder {
    static func build(style: MoodStyle) -> [WeightedPrompt] {
        [WeightedPrompt(text: style.prompt, weight: style.promptWeight)]
    }
}

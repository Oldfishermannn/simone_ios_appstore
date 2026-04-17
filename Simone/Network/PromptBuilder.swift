import Foundation

struct WeightedPrompt: Codable {
    let text: String
    let weight: Float
}

enum PromptBuilder {
    static func build(style: MoodStyle) -> [WeightedPrompt] {
        [WeightedPrompt(text: style.prompt, weight: style.promptWeight)]
    }

    /// Build a micro-variation of the style's prompt by appending a per-category
    /// evolve variant (one instrument add/remove + one energy + optional texture).
    /// Keeps mutations inside the channel tonality — no cross-genre drift.
    static func evolveVariant(style: MoodStyle) -> [WeightedPrompt] {
        let variant = EvolveVocabulary.variant(for: style.category)
        let mutated = style.prompt + variant
        return [WeightedPrompt(text: mutated, weight: style.promptWeight)]
    }
}

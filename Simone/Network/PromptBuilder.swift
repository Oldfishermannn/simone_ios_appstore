import Foundation

struct WeightedPrompt: Codable {
    let text: String
    let weight: Float
}

enum PromptBuilder {
    /// Single-arg build — used by non-evolve paths (selectStyle / regenerate /
    /// sendCurrentPrompts). Signature preserved for v1.2 compatibility.
    static func build(style: MoodStyle) -> [WeightedPrompt] {
        [WeightedPrompt(text: style.prompt, weight: style.promptWeight)]
    }

    /// v1.2.1 · Three-dimension modulated build — used by `AppState.evolve()`.
    /// RFC §2.5 — re-assemble prompt from style.prompt + active instruments
    /// + density/energy phrases. **Not** an append; every tick rebuilds fresh
    /// so prompt length stays bounded (R1 mitigation).
    ///
    /// - activeAccents / activeOptionals: current in-rotation accent/optional
    ///   instruments (deduped against style.prompt substrings to avoid R2
    ///   conflict).
    /// - density / energy: 0.3-1.0 scalars, mapped via `PromptPhrase`.
    static func build(
        style: MoodStyle,
        activeAccents: Set<String>,
        activeOptionals: Set<String>,
        density: Float,
        energy: Float
    ) -> [WeightedPrompt] {
        var parts: [String] = [style.prompt]

        // Instruments — dedupe against style.prompt (case-insensitive contains).
        // This prevents "Lo-fi with rhodes, rhodes" double-mention (RFC §R2).
        let lowerPrompt = style.prompt.lowercased()
        let merged = (activeAccents.union(activeOptionals))
            .filter { !lowerPrompt.contains($0.lowercased()) }
            .sorted()
        if !merged.isEmpty {
            parts.append("with " + merged.joined(separator: ", "))
        }

        parts.append(PromptPhrase.density(density))
        parts.append(PromptPhrase.energy(energy))

        let text = parts.joined(separator: ", ")
        return [WeightedPrompt(text: text, weight: style.promptWeight)]
    }

    /// Legacy evolve variant — v1.2 EvolveVocabulary-backed word append.
    /// Preserved for reversibility (RFC §4.3) but no longer called by
    /// AppState.evolve() in v1.2.1.
    static func evolveVariant(style: MoodStyle) -> [WeightedPrompt] {
        let variant = EvolveVocabulary.variant(for: style.category)
        let mutated = style.prompt + variant
        return [WeightedPrompt(text: mutated, weight: style.promptWeight)]
    }
}

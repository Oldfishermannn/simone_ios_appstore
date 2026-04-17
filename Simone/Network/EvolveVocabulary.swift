import Foundation

/// Per-category instrument / energy / texture word pools for Evolve micro-variations.
/// Choosing from these pools keeps mutations inside the current channel's tonality —
/// no cross-genre contamination (Rock doesn't suddenly get a harpsichord).
enum EvolveVocabulary {

    // MARK: - Per-category instrument pools
    // Each list holds 6-8 words that sit inside the channel's sonic identity.

    static func instruments(for category: StyleCategory) -> [String] {
        switch category {
        case .lofi:
            return ["soft piano", "warm pads", "rhodes", "mellow guitar",
                    "vinyl crackle", "lazy drums", "lofi bass"]
        case .jazz:
            return ["tenor sax", "upright bass", "brushed drums", "vibraphone",
                    "muted trumpet", "hammond organ", "walking bass", "piano trio"]
        case .rnb:
            return ["rhodes", "808 bass", "finger snaps", "soul organ",
                    "smooth guitar", "string pads", "wah guitar"]
        case .rock:
            return ["electric guitar", "distorted guitar", "overdrive", "warm bass",
                    "punchy drums", "harmonica", "slide guitar"]
        case .electronic:
            return ["analog synth", "arpeggiator", "808 kick", "side-chain bass",
                    "glitch", "hi-hat", "acid bass"]
        case .midnight:
            return ["deep sub bass", "reverb piano", "distant sax", "smoky guitar",
                    "soft kick", "muted trumpet", "late night rhodes"]
        case .cafe:
            return ["acoustic guitar", "nylon guitar", "cello", "flute",
                    "accordion", "brushed drums", "soft shaker"]
        case .rainy:
            return ["rhodes", "ambient pads", "soft piano", "gentle strings",
                    "minimal percussion", "rain texture"]
        case .library:
            return ["solo piano", "string quartet", "wooden flute", "harpsichord",
                    "minimal strings", "soft cello"]
        case .dreamscape:
            return ["shimmering synth", "granular pads", "bell tones", "slow strings",
                    "reverb guitar", "harp", "chimes"]
        // legacy cases fall back to Lo-fi pool (unreachable in v1.1.1 presets)
        case .blues, .pop, .classical, .ambient, .folk:
            return ["soft piano", "warm pads", "rhodes", "mellow guitar"]
        }
    }

    // MARK: - Generic pools

    /// Energy / density descriptors — always applied with `+` direction.
    static let energy: [String] = [
        "denser", "minimal", "lush", "sparse",
        "warmer", "brighter", "softer"
    ]

    /// Texture / surface descriptors — applied 70% of the time.
    static let texture: [String] = [
        "vinyl crackle", "reverb wash", "tape warmth", "subtle distortion",
        "airy", "shimmer"
    ]

    // MARK: - Variant composition

    /// Build a three-piece evolve variant: one instrument add/remove + one energy + 70%-chance texture.
    /// Returns the trailing string to append to a style prompt.
    static func variant(for category: StyleCategory) -> String {
        let instruments = instruments(for: category)
        guard let instrument = instruments.randomElement() else { return "" }
        let addRemove = Bool.random() ? "+" : "-"
        let energyWord = Self.energy.randomElement() ?? "softer"
        var parts = [" \(addRemove) \(instrument)", " + \(energyWord)"]
        if Double.random(in: 0...1) < 0.7, let tex = Self.texture.randomElement() {
            parts.append(" + \(tex)")
        }
        return parts.joined()
    }
}

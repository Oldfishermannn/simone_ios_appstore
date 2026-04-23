import Foundation

/// Top-level channel — v1.4a: Favorites removed. Channel is now a thin
/// wrapper around the 6 active StyleCategory genres
/// (lofi / jazz / rnb / rock / electronic / ambient).
///
/// The wrapper enum is preserved (rather than collapsing to StyleCategory
/// directly) because many call sites pattern-match on `case .category(...)`
/// and we want zero churn there. The old `.favorites` case + its
/// UserDefaults-backed visualizer picker were deleted — the NightWindow
/// visualizer now belongs to `StyleCategory.ambient`.
enum Channel: Hashable {
    case category(StyleCategory)

    static var all: [Channel] {
        StyleCategory.allCases.map { .category($0) }
    }

    var displayName: String {
        switch self {
        case .category(let c): return c.displayName
        }
    }

    /// Spectrum tonality is bound to the channel — no user self-select.
    var visualizer: VisualizerStyle {
        switch self {
        case .category(let c): return c.defaultVisualizer
        }
    }

    /// Stable string for UserDefaults persistence.
    /// v1.4a: the old `"favorites"` key is silently migrated to `.lofi` by
    /// `init?(rawKey:)` so existing users land on the default channel
    /// instead of crashing.
    var rawKey: String {
        switch self {
        case .category(let c): return "category:\(c.rawValue)"
        }
    }

    init?(rawKey: String) {
        // v1.4a migration: old Favorites users → default to Lo-fi.
        if rawKey == "favorites" {
            self = .category(.lofi)
            return
        }
        guard rawKey.hasPrefix("category:") else { return nil }
        let raw = String(rawKey.dropFirst("category:".count))
        guard let category = StyleCategory(rawValue: raw) else { return nil }
        self = .category(category)
    }
}

extension Channel: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Channel(rawKey: raw) ?? .category(.lofi)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawKey)
    }
}

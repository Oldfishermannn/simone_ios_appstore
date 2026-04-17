import Foundation

/// Top-level channel: Favorites sits first, then the 10 StyleCategory channels.
enum Channel: Hashable {
    case favorites
    case category(StyleCategory)

    static var all: [Channel] {
        [.favorites] + StyleCategory.allCases.map { .category($0) }
    }

    var displayName: String {
        switch self {
        case .favorites: return "Favorites"
        case .category(let c): return c.displayName
        }
    }

    /// Spectrum tonality is bound to the channel — no user self-select in v1.1.1.
    /// Favorites is a mixed bag so it falls back to terrain; category channels
    /// delegate to StyleCategory.defaultVisualizer.
    var visualizer: VisualizerStyle {
        switch self {
        case .favorites: return .terrain
        case .category(let c): return c.defaultVisualizer
        }
    }

    /// Stable string for UserDefaults persistence.
    var rawKey: String {
        switch self {
        case .favorites: return "favorites"
        case .category(let c): return "category:\(c.rawValue)"
        }
    }

    init?(rawKey: String) {
        if rawKey == "favorites" {
            self = .favorites
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

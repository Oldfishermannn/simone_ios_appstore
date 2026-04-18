import SwiftUI

enum StyleCategory: String, CaseIterable, Codable {
    // New v1.1.1 taxonomy — 5 genres + 5 atmospheres
    case lofi, jazz, rnb, rock, electronic
    case midnight, cafe, rainy, library, dreamscape

    // Legacy cases — removed in Commit 3 after MoodStyle preset migration
    case blues, pop, classical, ambient, folk

    static var allCases: [StyleCategory] {
        [.lofi, .jazz, .rnb, .rock, .electronic,
         .midnight, .cafe, .rainy, .library, .dreamscape]
    }

    /// Decode fallback: unknown raw values map to .lofi so old user data never crashes.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = StyleCategory(rawValue: raw) ?? .lofi
    }

    var displayName: String {
        switch self {
        case .lofi:       return "Lo-fi"
        case .jazz:       return "Jazz"
        case .rnb:        return "R&B"
        case .rock:       return "Rock"
        case .electronic: return "Electronic"
        case .midnight:   return "Midnight"
        case .cafe:       return "Cafe"
        case .rainy:      return "Rainy"
        case .library:    return "Library"
        case .dreamscape: return "Dreamscape"
        // legacy fallbacks
        case .blues:      return "Rock"
        case .pop:        return "Lo-fi"
        case .classical:  return "Cafe"
        case .ambient:    return "Rainy"
        case .folk:       return "Cafe"
        }
    }

    var color: Color {
        switch self {
        case .lofi:       return Color(red: 196/255, green: 166/255, blue: 157/255) // 玉粉黛
        case .jazz:       return Color(red: 201/255, green: 178/255, blue: 135/255) // 沙金
        case .rnb:        return Color(red: 150/255, green: 108/255, blue: 148/255) // 茄紫
        case .rock:       return Color(red: 140/255, green:  78/255, blue:  84/255) // 深酒红
        case .electronic: return Color(red: 112/255, green: 182/255, blue: 178/255) // 霓虹青
        case .midnight:   return Color(red:  74/255, green: 102/255, blue: 140/255) // 深海蓝
        case .cafe:       return Color(red: 200/255, green: 146/255, blue:  96/255) // 琥珀橙
        case .rainy:      return Color(red: 146/255, green: 162/255, blue: 181/255) // 雾灰蓝
        case .library:    return Color(red: 178/255, green: 158/255, blue: 132/255) // 温棕米白
        case .dreamscape: return Color(red: 150/255, green: 130/255, blue: 190/255) // 星紫
        // legacy fallbacks route to new category color
        case .blues:      return Color(red: 140/255, green:  78/255, blue:  84/255)
        case .pop:        return Color(red: 196/255, green: 166/255, blue: 157/255)
        case .classical:  return Color(red: 200/255, green: 146/255, blue:  96/255)
        case .ambient:    return Color(red: 146/255, green: 162/255, blue: 181/255)
        case .folk:       return Color(red: 200/255, green: 146/255, blue:  96/255)
        }
    }

    /// Visualizer bound to this category — spectrum tonality follows channel.
    var defaultVisualizer: VisualizerStyle {
        switch self {
        case .lofi:       return .horizon
        case .jazz:       return .oscilloscope
        case .rnb:        return .liquor   // v1.2: 频谱威士忌 — 液面随频段起伏
        case .rock:       return .ember    // v1.2: 频谱余烬 — 烟雾顶随频段弯折
        case .electronic: return .matrix
        case .midnight:   return .ringPulse
        case .cafe:       return .lattice
        case .rainy:      return .rainfall
        case .library:    return .prism
        case .dreamscape: return .helix
        // legacy fallbacks
        case .blues:      return .glitch
        case .pop:        return .horizon
        case .classical:  return .lattice
        case .ambient:    return .rainfall
        case .folk:       return .lattice
        }
    }
}

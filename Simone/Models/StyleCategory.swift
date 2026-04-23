import SwiftUI

enum StyleCategory: String, CaseIterable, Codable {
    // New v1.1.1 taxonomy — 5 genres + 5 atmospheres
    // v1.4a: `ambient` promoted from legacy stub to 6th active genre
    // (takes over the NightWindow visualizer that used to live on the
    // now-removed Favorites channel).
    case lofi, jazz, rnb, rock, electronic, ambient
    case midnight, cafe, rainy, library, dreamscape

    // Legacy cases — removed in Commit 3 after MoodStyle preset migration
    case blues, pop, classical, folk

    /// v1.2 精简：只保留 5 个核心频道。midnight/cafe/rainy/library/dreamscape
    /// 作为 case 保留做 Codable 降级兼容，但 UI 不再遍历。
    /// v1.4a: ambient 作为第 6 个活跃频道。频道呈现顺序由此数组决定
    /// （CEO 2026-04-22 拍板：ambient → lofi → rnb → jazz → rock → electronic）。
    static var allCases: [StyleCategory] {
        [.ambient, .lofi, .rnb, .jazz, .rock, .electronic]
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
        case .ambient:    return "Ambient"
        case .midnight:   return "Midnight"
        case .cafe:       return "Cafe"
        case .rainy:      return "Rainy"
        case .library:    return "Library"
        case .dreamscape: return "Dreamscape"
        // legacy fallbacks
        case .blues:      return "Rock"
        case .pop:        return "Lo-fi"
        case .classical:  return "Cafe"
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
        case .ambient:    return Color(red: 130/255, green: 148/255, blue: 186/255) // 夜窗薄雾蓝
        case .midnight:   return Color(red:  74/255, green: 102/255, blue: 140/255) // 深海蓝
        case .cafe:       return Color(red: 200/255, green: 146/255, blue:  96/255) // 琥珀橙
        case .rainy:      return Color(red: 146/255, green: 162/255, blue: 181/255) // 雾灰蓝
        case .library:    return Color(red: 178/255, green: 158/255, blue: 132/255) // 温棕米白
        case .dreamscape: return Color(red: 150/255, green: 130/255, blue: 190/255) // 星紫
        // legacy fallbacks route to new category color
        case .blues:      return Color(red: 140/255, green:  78/255, blue:  84/255)
        case .pop:        return Color(red: 196/255, green: 166/255, blue: 157/255)
        case .classical:  return Color(red: 200/255, green: 146/255, blue:  96/255)
        case .folk:       return Color(red: 200/255, green: 146/255, blue:  96/255)
        }
    }

    /// v1.2.1 · 乐器池三层定义（RFC §2.1）。
    /// core 奠定频道身份（由 style.prompt 自带，不进 active），
    /// accent 1m 粒度 ±1，optional 30s 粒度 ±1。
    /// 10 频道各自一组，legacy 映射到对应新频道。
    var instrumentPool: InstrumentPool {
        switch self {
        case .lofi:
            return InstrumentPool(
                core:     ["soft piano", "mellow beats", "vinyl warmth"],
                accent:   ["rhodes", "warm pads", "lazy guitar", "lofi bass"],
                optional: ["subtle rain", "tape hiss", "vocal chops", "muted trumpet"]
            )
        case .jazz:
            return InstrumentPool(
                core:     ["walking bass", "brushed drums", "piano trio"],
                accent:   ["tenor sax", "muted trumpet", "vibraphone", "hammond organ"],
                optional: ["flute", "clarinet", "soft strings", "gentle shaker"]
            )
        case .rnb:
            return InstrumentPool(
                core:     ["rhodes", "smooth bass", "tight drums"],
                accent:   ["soul organ", "wah guitar", "string pads", "finger snaps"],
                optional: ["soft horns", "vocal pad", "808 sub", "chimes"]
            )
        case .rock:
            return InstrumentPool(
                core:     ["electric guitar", "punchy drums", "warm bass"],
                accent:   ["distorted guitar", "hammond organ", "harmonica", "slide guitar"],
                optional: ["tambourine", "piano accents", "pedal steel", "soft synth pads"]
            )
        case .electronic:
            return InstrumentPool(
                core:     ["analog synth", "pulsing bass", "four-on-the-floor kick"],
                accent:   ["arpeggiator", "acid bass", "crisp hi-hat", "side-chain pad"],
                optional: ["glitch textures", "vocal chops", "vinyl stabs", "riser sweep"]
            )
        case .ambient:
            return InstrumentPool(
                core:     ["ambient pads", "soft drones", "deep reverb"],
                accent:   ["bowed strings", "celesta", "piano resonance", "breath texture"],
                optional: ["distant chimes", "wind texture", "tape loops", "glass harmonica"]
            )
        case .midnight:
            return InstrumentPool(
                core:     ["deep sub bass", "reverb piano", "soft kick"],
                accent:   ["distant sax", "smoky guitar", "muted trumpet", "late night rhodes"],
                optional: ["city ambience", "faint rain", "tape hiss", "sparse chimes"]
            )
        case .cafe:
            return InstrumentPool(
                core:     ["acoustic guitar", "nylon guitar", "warm upright bass"],
                accent:   ["cello", "flute", "accordion", "brushed drums"],
                optional: ["soft shaker", "glockenspiel", "light mandolin", "soprano sax"]
            )
        case .rainy:
            return InstrumentPool(
                core:     ["rhodes", "ambient pads", "soft piano"],
                accent:   ["gentle strings", "minimal percussion", "warm cello", "breathy flute"],
                optional: ["rain texture", "distant thunder", "soft bells", "tape warmth"]
            )
        case .library:
            return InstrumentPool(
                core:     ["solo piano", "minimal strings", "soft cello"],
                accent:   ["wooden flute", "harpsichord", "violin harmonies", "string quartet"],
                optional: ["recorder", "gentle harp", "light woodwinds", "chamber reverb"]
            )
        case .dreamscape:
            return InstrumentPool(
                core:     ["shimmering synth", "granular pads", "slow strings"],
                accent:   ["bell tones", "reverb guitar", "harp", "chimes"],
                optional: ["celesta", "breathy flute", "twinkling bells", "distant pads"]
            )
        // legacy fallbacks route to the migrated channel's pool
        case .blues:     return StyleCategory.rock.instrumentPool
        case .pop:       return StyleCategory.lofi.instrumentPool
        case .classical: return StyleCategory.cafe.instrumentPool
        case .folk:      return StyleCategory.cafe.instrumentPool
        }
    }

    /// Visualizer bound to this category — spectrum tonality follows channel.
    var defaultVisualizer: VisualizerStyle {
        switch self {
        case .lofi:       return .lofiTape  // v1.2 三选一评审中：tape / pad / blinds
        case .jazz:       return .oscilloscope
        case .rnb:        return .liquor   // v1.2: 频谱威士忌 — 液面随频段起伏
        case .rock:       return .ember    // v1.2: 频谱余烬 — 烟雾顶随频段弯折
        case .electronic: return .matrix
        case .ambient:    return .nightWindow  // v1.4a: 窗外夜景 — 从原 Favorites 继承
        case .midnight:   return .ringPulse
        case .cafe:       return .lattice
        case .rainy:      return .rainfall
        case .library:    return .prism
        case .dreamscape: return .helix
        // legacy fallbacks
        case .blues:      return .glitch
        case .pop:        return .horizon
        case .classical:  return .lattice
        case .folk:       return .lattice
        }
    }
}

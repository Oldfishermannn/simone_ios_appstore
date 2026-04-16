import SwiftUI

enum StyleCategory: String, CaseIterable, Codable {
    case lofi, jazz, blues, rnb, rock, pop, electronic, classical, ambient, folk

    var displayName: String {
        switch self {
        case .lofi: return "Lo-fi"
        case .jazz: return "Jazz"
        case .blues: return "Blues"
        case .rnb: return "R&B"
        case .rock: return "Rock"
        case .pop: return "Pop"
        case .electronic: return "Electronic"
        case .classical: return "Classical"
        case .ambient: return "Ambient"
        case .folk: return "Folk"
        }
    }

    var color: Color {
        switch self {
        case .lofi: return MorandiPalette.rose
        case .jazz: return MorandiPalette.sand
        case .blues: return MorandiPalette.blue
        case .rnb: return MorandiPalette.mauve
        case .rock: return Color(red: 180/255, green: 140/255, blue: 140/255)
        case .pop: return Color(red: 190/255, green: 175/255, blue: 160/255)
        case .electronic: return MorandiPalette.blue
        case .classical: return MorandiPalette.sage
        case .ambient: return MorandiPalette.mauve
        case .folk: return MorandiPalette.sage
        }
    }
}

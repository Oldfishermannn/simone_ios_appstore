import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    case horizon, ringPulse, terrain, rainfall, helix, lattice, prism, tide

    var id: String { rawValue }

    var displayName: String { label }

    var label: String {
        switch self {
        case .horizon: "Horizon"
        case .ringPulse: "Ring Pulse"
        case .terrain: "Terrain"
        case .rainfall: "Rainfall"
        case .helix: "Helix"
        case .lattice: "Lattice"
        case .prism: "Prism"
        case .tide: "Tide"
        }
    }

    static var defaultStyle: VisualizerStyle { .horizon }
}

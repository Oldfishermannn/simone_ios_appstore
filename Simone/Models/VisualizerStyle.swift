import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    // Lines group
    case horizon, aurora, cascade, tide, terrain
    // Circles group
    case constellation, ringPulse, waveRipple, prism, vortex
    // Dots/particles group
    case nebula, rainfall, lattice, firefly, helix

    var id: String { rawValue }

    var displayName: String { label }

    var label: String {
        switch self {
        case .horizon: "Horizon"
        case .aurora: "Aurora"
        case .cascade: "Cascade"
        case .tide: "Tide"
        case .terrain: "Terrain"
        case .constellation: "Constellation"
        case .ringPulse: "Ring Pulse"
        case .waveRipple: "Wave Ripple"
        case .prism: "Prism"
        case .vortex: "Vortex"
        case .nebula: "Nebula"
        case .rainfall: "Rainfall"
        case .lattice: "Lattice"
        case .firefly: "Firefly"
        case .helix: "Helix"
        }
    }

    static var defaultStyle: VisualizerStyle { .horizon }
}

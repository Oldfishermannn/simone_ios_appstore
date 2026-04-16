import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    case horizon, ringPulse, terrain, rainfall, helix, lattice, prism
    case matrix, flora, glitch, oscilloscope

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
        case .matrix: "Matrix"
        case .flora: "Flora"
        case .glitch: "Glitch"
        case .oscilloscope: "Oscilloscope"
        }
    }

    static var defaultStyle: VisualizerStyle { .horizon }
}

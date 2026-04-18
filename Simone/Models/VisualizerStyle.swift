import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    case horizon, ringPulse, terrain, rainfall, helix, lattice, prism
    case matrix, flora, glitch, oscilloscope
    // v1.2 Fog 新增：R&B→Liquor，Rock→Ember
    case ember, liquor

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
        case .ember: "Ember"
        case .liquor: "Liquor"
        }
    }

    static var defaultStyle: VisualizerStyle { .horizon }
}

import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    case aurora, fountain, vinyl, silkWave, constellation, particleFlow, ripple, ringPulse

    var id: String { rawValue }

    var displayName: String { label }

    var label: String {
        switch self {
        case .fountain: "Fountain"
        case .aurora: "Aurora"
        case .vinyl: "Vinyl"
        case .silkWave: "Silk Wave"
        case .constellation: "Constellation"
        case .particleFlow: "Particle Flow"
        case .ripple: "Ripple"
        case .ringPulse: "Ring Pulse"
        }
    }

    static var defaultStyle: VisualizerStyle { .aurora }
}

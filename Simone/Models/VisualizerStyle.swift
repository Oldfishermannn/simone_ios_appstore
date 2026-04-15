import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    // Lines group: aurora, horizon, waveform, cascade
    // Circles group: constellation, orbital, pulseBubble, ringPulse
    case aurora, horizon, waveform, cascade, constellation, orbital, pulseBubble, ringPulse

    var id: String { rawValue }

    var displayName: String { label }

    var label: String {
        switch self {
        case .aurora: "Aurora"
        case .horizon: "Horizon"
        case .waveform: "Waveform"
        case .cascade: "Cascade"
        case .constellation: "Constellation"
        case .orbital: "Orbital"
        case .pulseBubble: "Pulse Bubble"
        case .ringPulse: "Ring Pulse"
        }
    }

    static var defaultStyle: VisualizerStyle { .aurora }
}

import Foundation

enum VisualizerStyle: String, CaseIterable, Identifiable {
    // Lines group: horizon, aurora, cascade
    // Circles group: constellation, ringPulse
    case horizon, aurora, cascade, constellation, ringPulse

    var id: String { rawValue }

    var displayName: String { label }

    var label: String {
        switch self {
        case .horizon: "Horizon"
        case .aurora: "Aurora"
        case .cascade: "Cascade"
        case .constellation: "Constellation"
        case .ringPulse: "Ring Pulse"
        }
    }

    static var defaultStyle: VisualizerStyle { .horizon }
}

import Foundation

enum Tier: String, Codable, CaseIterable, Comparable {
    case flow
    case tune
    case studio

    var rank: Int {
        switch self {
        case .flow: return 0
        case .tune: return 1
        case .studio: return 2
        }
    }

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rank < rhs.rank }

    var displayName: String {
        switch self {
        case .flow: return "Flow"
        case .tune: return "Tune"
        case .studio: return "Studio"
        }
    }

    var tagline: String {
        switch self {
        case .flow: return "Press play"
        case .tune: return "Choose your stations"
        case .studio: return "Shape your own atmosphere"
        }
    }

    func canAccess(_ feature: Feature) -> Bool {
        self >= feature.requiredTier
    }
}

enum Feature {
    case selectSpecificStyle
    case favoriteStyle
    case buildNewStyleFromTags
    case directInput
    case evolveDepthControls
    case bpmSlider
    case temperatureSlider
    case visualizerReorder
    case visualizerCustom
    case multiStyleMix
    case offlineRadio
    case exportClip

    var requiredTier: Tier {
        switch self {
        case .selectSpecificStyle,
             .favoriteStyle,
             .buildNewStyleFromTags,
             .visualizerReorder:
            return .tune
        case .directInput,
             .evolveDepthControls,
             .bpmSlider,
             .temperatureSlider,
             .visualizerCustom,
             .multiStyleMix,
             .offlineRadio,
             .exportClip:
            return .studio
        }
    }
}

enum ProductID {
    static let tuneMonthly = "com.simone.ios.tune.monthly"
    static let tuneAnnual = "com.simone.ios.tune.annual"
    static let tuneLifetime = "com.simone.ios.tune.lifetime"
    static let studioMonthly = "com.simone.ios.studio.monthly"
    static let studioAnnual = "com.simone.ios.studio.annual"
    static let studioLifetime = "com.simone.ios.studio.lifetime"

    static let all: [String] = [
        tuneMonthly, tuneAnnual, tuneLifetime,
        studioMonthly, studioAnnual, studioLifetime
    ]

    static func tier(for productID: String) -> Tier? {
        switch productID {
        case tuneMonthly, tuneAnnual, tuneLifetime:
            return .tune
        case studioMonthly, studioAnnual, studioLifetime:
            return .studio
        default:
            return nil
        }
    }
}

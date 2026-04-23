import SwiftUI

/// v1.2.1 — Fog typography scale.
///
/// Six-step modular scale with ratios ≥ 1.15 between neighbors:
///   44 / 28 / 20 / 15 / 13 / 11  →  1.57 / 1.40 / 1.33 / 1.15 / 1.18
///
/// Each case owns its size + font family + tracking. Weight is folded into
/// the family choice so callsites read as one line:
///
///     Text("NEBULA").fog(.displayLg)
///     Text("Preferences").fog(.title)
///     Text("BYOK").fog(.labelCaps)
///
/// The underlying fonts (Unbounded / Fraunces / Archivo) are variable fonts
/// bundled in Resources/Fonts/. Weight is selected via `.weight(...)` on
/// the custom Font — the variable wght axis picks up the value.
///
/// tracking() values are in pt (not em). The impeccable token spec gives
/// tracking in em; here we multiply by the pt size once, rounded to the
/// nearest 0.1pt. For the 0.14em label-caps at 11pt that's 1.54pt.
enum FogType {

    case displayLg   // 44pt · Unbounded Medium · immersive title
    case displaySm   // 28pt · Unbounded Medium · channel card name (+2pt vs v1.2 26)
    case title       // 20pt · Fraunces SemiBold · section headers
    case body        // 15pt · Fraunces Regular  · long-form description
    case meta        // 13pt · Archivo Regular   · time / counts / meta row
    case labelCaps   // 11pt · Archivo Medium    · LOCK / EVOLVE / BYOK

    // MARK: - Size

    var size: CGFloat {
        switch self {
        case .displayLg: return 44
        case .displaySm: return 28
        case .title:     return 20
        case .body:      return 15
        case .meta:      return 13
        case .labelCaps: return 11
        }
    }

    // MARK: - Font (family + weight)

    var font: Font {
        switch self {
        case .displayLg, .displaySm:
            return Font.custom("Unbounded", size: size).weight(.medium)
        case .title:
            return Font.custom("Fraunces", size: size).weight(.semibold)
        case .body:
            return Font.custom("Fraunces", size: size).weight(.regular)
        case .meta:
            return Font.custom("Archivo", size: size).weight(.regular)
        case .labelCaps:
            return Font.custom("Archivo", size: size).weight(.medium)
        }
    }

    // MARK: - Tracking (pt — not em)

    /// Letter-spacing in points, pre-multiplied against size. See header note.
    var tracking: CGFloat {
        switch self {
        case .displayLg: return -0.88   // -0.020em × 44pt
        case .displaySm: return -0.42   // -0.015em × 28pt
        case .title:     return 0
        case .body:      return 0.075   // +0.005em × 15pt
        case .meta:      return 0.39    // +0.030em × 13pt
        case .labelCaps: return 1.54    // +0.140em × 11pt
        }
    }

    // MARK: - Line height multiplier
    //
    // Used on long-form body blocks where we care about comfort. SwiftUI has
    // no single line-height API — callers apply this through lineSpacing.
    var lineSpacing: CGFloat {
        switch self {
        case .displayLg: return size * 0.1    // 1.1 → extra 10%
        case .displaySm: return size * 0.1
        case .title:     return size * 0.3
        case .body:      return size * 0.55
        case .meta:      return size * 0.4
        case .labelCaps: return size * 0.4
        }
    }
}

// MARK: - View sugar

extension View {
    /// Apply a FogType role: font + tracking in one modifier.
    /// Line-spacing is applied on body / multi-line contexts only — callers
    /// that need it can chain `.lineSpacing(FogType.body.lineSpacing)`.
    func fog(_ type: FogType) -> some View {
        self
            .font(type.font)
            .tracking(type.tracking)
    }

    /// Apply FogType.labelCaps with uppercase casing and brass tint — the
    /// small-caps style used on LOCK / EVOLVE / BYOK badges.
    func fogLabelCaps(tint: Color = FogTokens.accentBrass) -> some View {
        self
            .fog(.labelCaps)
            .textCase(.uppercase)
            .foregroundStyle(tint)
    }
}

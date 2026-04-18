import SwiftUI

/// Fog City Nocturne design system.
/// 晚 11 点地下酒吧的雾玻璃感：冷色、极简、视觉让位音乐。
/// Rolled out in feature/fog-redesign; kept alongside MorandiPalette for coexistence.
enum FogTheme {

    // MARK: Color

    /// Base surface gradient (top → bottom on background views).
    static let surfaceTop = Color(red: 10/255, green: 13/255, blue: 18/255)
    static let surfaceBottom = Color(red: 20/255, green: 24/255, blue: 30/255)

    /// Neutrals — very slightly warm-cold-neutral with a hair of violet (h≈280) to echo accent.
    static let ink = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let inkPrimary = Color.white.opacity(0.90)
    static let inkSecondary = Color.white.opacity(0.55)
    static let inkTertiary = Color.white.opacity(0.30)
    static let inkQuiet = Color.white.opacity(0.12)
    static let hairline = Color.white.opacity(0.06)

    /// Accent — sparingly used. Reuses the existing Morandi mauve so v1.0 assets stay coherent.
    static let accent = Color(red: 181/255, green: 160/255, blue: 181/255)
    static let accentSoft = Color(red: 181/255, green: 160/255, blue: 181/255).opacity(0.55)

    // MARK: Typography roles
    //
    // Phase 1 uses SF Pro with carefully chosen design/weight/tracking to approximate the
    // Unbounded/Fraunces/Archivo pairing. Phase 5 will swap in the real OFL fonts.

    /// Display — cold, modern grotesque. Approximates Unbounded Light.
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Serif italic — warmth counter-weight. Approximates Fraunces Italic.
    static func serifItalic(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }

    /// Body — neutral, readable. Approximates Archivo.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Mono — metadata, timestamps, values. Approximates Archivo Mono.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Tracking (letter-spacing) presets

    /// Tight negative tracking for display headings.
    static let trackDisplay: CGFloat = -0.3
    /// Uppercase label tracking — 0.25em at small sizes.
    static let trackLabel: CGFloat = 2.2
    /// Mono meta tracking — slightly opened up.
    static let trackMeta: CGFloat = 1.0

    // MARK: Spacing (4pt scale)

    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 12
    static let spaceLG: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let space2XL: CGFloat = 32
    static let space3XL: CGFloat = 48
}

// MARK: - Convenience modifiers

extension View {
    /// Uppercase section label: Mono 9pt, letter-spacing trackLabel, tertiary ink.
    func fogSectionLabel() -> some View {
        self
            .font(FogTheme.mono(9, weight: .regular))
            .tracking(FogTheme.trackLabel)
            .textCase(.uppercase)
            .foregroundStyle(FogTheme.inkTertiary)
    }
}

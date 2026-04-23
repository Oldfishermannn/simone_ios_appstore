import SwiftUI

/// v1.2.1 — Fog City Nocturne cool-axis palette (OKLCH-locked).
///
/// Design rationale (see `docs/v1.2.1-ui-tokens.md`):
/// v1.2 shipped the Fog cool backdrop but UI chrome still leaked Morandi warm
/// greys (sage / sand / rose) in several places — the two palettes clashed at
/// night ("late dusk" rather than "deep night"). v1.2.1 locks all neutrals to
/// a single cool axis (hue ∈ [230, 280], chroma ≤ 0.06 on bg/text), with exactly
/// one warm accent — brass — reserved for ember / evolve status dots (≤ 10% of
/// pixels at any time).
///
/// Values are OKLCH → sRGB using the standard Björn Ottosson transform
/// (oklab.com reference). sRGB values are rounded to 3 decimals — the human
/// eye cannot tell 4th-decimal differences on a phone display. Original OKLCH
/// coordinates are kept in comments so we can re-derive if the transform
/// library changes, or port to another platform.
///
/// Use `FogTokens` for **all new UI chrome** work. The older `FogTheme` enum
/// (Models/FogTheme.swift) stays alongside for v1.2 visualizer callsites that
/// already integrated — both compile, but `FogTokens` is the forward palette.
enum FogTokens {

    // MARK: - Backgrounds (cool, desaturated)

    /// Deepest base — oklch(0.13 0.018 252). Immersive page fill.
    static let bgDeep = Color(
        .sRGB, red: 0.014, green: 0.030, blue: 0.056, opacity: 1.0
    )

    /// Card / panel fill — oklch(0.18 0.022 250). One level up from bgDeep.
    static let bgSurface = Color(
        .sRGB, red: 0.039, green: 0.072, blue: 0.106, opacity: 1.0
    )

    /// Raised element (now-playing bar, floating cards) — oklch(0.22 0.025 248).
    static let bgRaised = Color(
        .sRGB, red: 0.067, green: 0.108, blue: 0.148, opacity: 1.0
    )

    // MARK: - Lines

    /// 1px divider — oklch(0.30 0.015 250 / 0.4). Cool, barely visible.
    static let lineHairline = Color(
        .sRGB, red: 0.158, green: 0.182, blue: 0.209, opacity: 0.4
    )

    // MARK: - Text (three tiers, all cool-tinted, never pure white / pure grey)

    /// Primary text — oklch(0.94 0.012 250). Softer than pure white, less fatigue.
    static let textPrimary = Color(
        .sRGB, red: 0.899, green: 0.925, blue: 0.953, opacity: 1.0
    )

    /// Secondary text — oklch(0.72 0.020 250). For subtitles, meta.
    static let textSecondary = Color(
        .sRGB, red: 0.610, green: 0.650, blue: 0.694, opacity: 1.0
    )

    /// Tertiary / hint — oklch(0.52 0.025 250). Placeholder, disabled.
    static let textTertiary = Color(
        .sRGB, red: 0.370, green: 0.417, blue: 0.467, opacity: 1.0
    )

    // MARK: - Accents (one cool primary + one warm sparingly)

    /// Channel / brand accent — oklch(0.62 0.14 265). Indigo, the active tint.
    static let accentIndigo = Color(
        .sRGB, red: 0.361, green: 0.510, blue: 0.855, opacity: 1.0
    )

    /// The **only** warm accent — oklch(0.72 0.08 72). Brass.
    /// Reserved for ember / evolve / lock status lights. Keep ≤ 10% of pixels.
    static let accentBrass = Color(
        .sRGB, red: 0.769, green: 0.615, blue: 0.423, opacity: 1.0
    )

    /// Error / over-limit — oklch(0.62 0.16 28). Brass tilted red.
    static let dangerEmber = Color(
        .sRGB, red: 0.836, green: 0.347, blue: 0.300, opacity: 1.0
    )
}

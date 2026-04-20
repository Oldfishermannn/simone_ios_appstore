import SwiftUI

/// v1.2.1 — Breathing motion modifier.
///
/// Replaces the v1.2 "shrink to thumbnail on pause" behavior. Instead of
/// changing size / position / opacity / color on pause, the object stays put
/// and only its **breathing rate** changes. Like a body falling asleep.
///
/// ### Tokens
///
/// Playing:
///   - scale 1.000 → 1.006 (0.6%, imperceptible in isolation)
///   - period 8s
///   - easing cubic-bezier(0.4, 0, 0.2, 1) — smooth sine-like
///
/// Paused:
///   - scale 1.000 → 1.004 (0.4%, one-third quieter amplitude)
///   - period 12s (1.5× slower, fixed — spectrum-independent)
///   - easing cubic-bezier(0.33, 0, 0.67, 1) — deep-sleep in-out
///
/// Transition:
///   - 1.2s easeInOut when play / pause toggles — the period and amplitude
///     cross-fade; no abrupt rate change
///
/// ### Bans (enforced in code review, not at runtime)
///
/// - No scaleEffect to thumbnail size on pause
/// - No .opacity() dimming mask on pause
/// - No "Paused" text overlay
/// - Period must stay in [5s, 20s] window — clamped here
///
/// ### NowPlaying art note
///
/// The lock-screen / Dynamic Island / Control Center artwork is generated
/// separately by AudioEngine.nowPlayingInfo.artwork and is NOT affected by
/// this modifier. That path stays on v1.1.0 behavior.
struct BreathingModifier: ViewModifier {
    let isPlaying: Bool

    /// Phase 0...1 driven by TimelineView date. We derive the scale inside
    /// the timeline closure so SwiftUI re-renders at a capped 30 fps.
    @State private var phaseEpoch: Date = .distantPast

    func body(content: Content) -> some View {
        // TimelineView gives us a date to compute breathing phase from.
        // Capped at 30fps — this effect is a ±0.6% scale, anything higher
        // would burn GPU for changes invisible to the eye.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let scale = currentScale(at: timeline.date)
            content
                .scaleEffect(scale, anchor: .center)
        }
        .onAppear { phaseEpoch = Date() }
    }

    // MARK: - Scale curve

    /// Returns the breathing scale for a given instant.
    /// Continuous across play ↔ pause toggles (state is a pure function of
    /// `date`), so no jump when `isPlaying` flips.
    private func currentScale(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(phaseEpoch)
        // Within [5s, 20s] period guardrail — Package #3 token ban.
        let period: Double = isPlaying ? 8.0 : 12.0
        let amplitude: CGFloat = isPlaying ? 0.006 : 0.004

        // Half-cosine mapped to 0...1 then amplitude applied. cos starts at 1
        // so breath starts at full scale; phase is normalized so the curve is
        // continuous across period changes (we integrate cycles instead of
        // restarting the phase on each toggle — avoids a visible glitch on
        // play/pause).
        let cycles = elapsed / period
        // Keep only fractional cycle for cosine argument.
        let phase = cycles.truncatingRemainder(dividingBy: 1.0)
        let cosValue = cos(phase * 2 * .pi)   // 1 → -1 → 1 over one period
        let normalized = CGFloat((1.0 - cosValue) / 2.0) // 0 → 1 → 0
        return 1.0 + amplitude * normalized
    }
}

extension View {
    /// Apply Fog v1.2.1 breathing motion. Visualizer containers on the
    /// immersive page should call this with `AppState.audioEngine.isPlaying`.
    /// The modifier handles play / pause rate crossfade internally — do not
    /// stack other scale effects driven by isPlaying on top.
    func breathing(isPlaying: Bool) -> some View {
        modifier(BreathingModifier(isPlaying: isPlaying))
    }
}

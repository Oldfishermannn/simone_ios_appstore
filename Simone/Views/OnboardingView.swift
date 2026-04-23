import SwiftUI

/// First-launch onboarding — "Radio Manual" page.
///
/// Pure typography. No gesture animations, no ghost rings, no pulsating
/// halos (CEO: "太难看"). Single static page teaching 4 gestures + 2
/// corner buttons. Tap anywhere to dismiss.
///
/// Controlled externally by `@AppStorage("hasSeenOnboarding_v1_3")` in
/// ContentView. Version suffix lets us bump the key to force a re-show
/// after content changes without orphaning old UserDefaults values.
struct OnboardingView: View {
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Nested over the main view — darken enough for text legibility
            // while keeping visualizer + bottom buttons faintly visible, so
            // the manual reads as an annotation of the live screen, not a
            // separate "tutorial page."
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 8)

                    hairline
                        .padding(.top, 28)
                        .padding(.bottom, 28)

                    item(
                        glyph: "←  →",
                        title: "switch channels",
                        meta: "Lo-fi · Ambient · R&B · Jazz · Rock · Electronic"
                    )

                    item(
                        glyph: "↑  ↓",
                        title: "flip through styles",
                        meta: "ten per channel"
                    )

                    item(
                        glyph: "tap",
                        title: "play · pause"
                    )

                    item(
                        glyph: "⚙",
                        title: "settings",
                        meta: "bottom left"
                    )

                    item(
                        glyph: "☰",
                        title: "now playing",
                        meta: "bottom right"
                    )

                    hairline
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    Text("tap anywhere to begin")
                        .font(.custom("Fraunces-Italic", size: 15))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                .padding(.horizontal, 32)
                .padding(.top, 96)
                .padding(.bottom, 64)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: appeared)
        .onAppear { appeared = true }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SIMONE")
                .fog(.displaySm)
                .foregroundStyle(Color.white)

            Text("how to tune in")
                .font(.custom("Fraunces-Italic", size: 17))
                .foregroundStyle(Color.white.opacity(0.62))
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(height: 1)
            .frame(maxWidth: 64, alignment: .leading)
    }

    private func item(glyph: String, title: String, meta: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(glyph)
                .font(.custom("Unbounded", size: 26).weight(.medium))
                .tracking(4)
                .foregroundStyle(Color.white)

            Text(title)
                .fog(.body)
                .foregroundStyle(Color.white)

            if let meta {
                Text(meta)
                    .fog(.meta)
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Dismissal

    private func dismiss() {
        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            onDismiss()
        }
    }
}

#Preview {
    OnboardingView(onDismiss: {})
        .preferredColorScheme(.dark)
}

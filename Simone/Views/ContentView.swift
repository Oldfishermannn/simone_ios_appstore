import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    /// v1.1.1: 3-page structure — Immersive / Details (new home) / Settings.
    /// Main page was folded in: small spectrum lives on Immersive (tap toggle),
    /// transport controls moved to Details bottom.
    @State private var currentPage: Int = 0  // 0=Immersive (default), 1=Details, 2=Settings

    var body: some View {
        ZStack {
            // v1.2.1: cool-axis base (was 0.165/0.165/0.18 warm grey).
            // FogTokens.bgDeep = oklch(0.13 0.018 252).
            FogTokens.bgDeep
                .ignoresSafeArea()

            // v1.2.1: soft indigo halo from top (was Morandi rose — the last
            // warm leak on the root chrome). Amount unchanged (0.06) so the
            // feel stays a whisper, not a vignette.
            RadialGradient(
                colors: [FogTokens.accentIndigo.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VerticalPageView(pageCount: 3, currentPage: $currentPage) { index in
                Group {
                    switch index {
                    case 0:
                        ImmersiveView(state: state)
                    case 2:
                        SettingsView(state: state)
                    default:
                        DetailsView(state: state)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

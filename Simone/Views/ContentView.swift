import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    /// v1.1.1: 3-page structure — Immersive / Details (new home) / Settings.
    /// Main page was folded in: small spectrum lives on Immersive (tap toggle),
    /// transport controls moved to Details bottom.
    @State private var currentPage: Int = 0  // 0=Immersive (default), 1=Details, 2=Settings

    var body: some View {
        ZStack {
            Color(red: 0.165, green: 0.165, blue: 0.18)
                .ignoresSafeArea()

            RadialGradient(
                colors: [MorandiPalette.rose.opacity(0.06), .clear],
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

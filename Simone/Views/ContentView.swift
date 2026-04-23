import SwiftUI

struct ContentView: View {
    @State var state = AppState()

    // v1.3 · root 架构重设计：从 3 页纵滑 (VerticalPageView) 改为
    // 单页 ImmersiveView + 两个原生 .sheet。角落按钮召唤 modal。
    @State private var showDetails: Bool = false
    @State private var showSettings: Bool = false

    // v1.3.0 · first-launch onboarding (Radio Manual). Version suffix lets us
    // bump the key to force re-show on content change without orphaning old
    // UserDefaults values from prior versions.
    @AppStorage("hasSeenOnboarding_v1_3") private var hasSeenOnboarding: Bool = false

    var body: some View {
        ZStack {
            // v1.2.1: cool-axis base.
            FogTokens.bgDeep
                .ignoresSafeArea()

            RadialGradient(
                colors: [FogTokens.accentIndigo.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            ImmersiveView(
                state: state,
                onTapDetails: { showDetails = true },
                onTapSettings: { showSettings = true }
            )
            .ignoresSafeArea()

            if !hasSeenOnboarding {
                OnboardingView(onDismiss: { hasSeenOnboarding = true })
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $showDetails) {
            DetailsView(state: state)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

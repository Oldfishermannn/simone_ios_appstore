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
        // v2.1 iPad adapt · 用 GeometryReader 拿屏幕宽度，直接算 sidePadding 实现居中。
        // 试过 .frame(maxWidth: 560) 在 ScrollView/HStack/VStack 多种组合 4 次都没生效，
        // 推测 ScrollView 在 .vertical 模式下 child layout 行为被某些 modifier 干扰。
        // 直接算 padding 是最确定的方案。
        GeometryReader { geo in
            // 卡片自然内容宽 ~285pt（"Lo-fi · Ambient · R&B · Jazz · Rock · Electronic"
            // 是最长一行）；锁 380pt 给 list items 留 breathing，iPad 大屏居中显示。
            // iPhone < 380pt 屏宽时降级 fill。
            let contentWidth = min(380, geo.size.width - 64)
            ZStack(alignment: .topLeading) {
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
                    .frame(width: contentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 96)
                    .padding(.bottom, 64)
                }
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

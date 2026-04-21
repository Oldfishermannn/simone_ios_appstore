import SwiftUI

/// v1.3 · 首次 affordance — visualizer 边缘 indigo ghost ring 呼吸 2.5s 后淡出。
/// 2 层 ring（delay 0.15s 错峰）扩散到 size * 1.3，透明度 0.9 → 0。
/// 每频道独立一次：AppState.hasSeenGhostRing / markGhostRingSeen 由调用方管理。
struct GhostRingView: View {
    /// 基准尺寸（visualizer 本体宽高），ring 最终扩散到 size * 1.3。
    let size: CGFloat
    /// 完成（淡出结束）回调 — 调用方持久化 `markGhostRingSeen`。
    var onFinished: () -> Void = {}

    @State private var phase1Scale: CGFloat = 0.85
    @State private var phase1Opacity: Double = 0.9
    @State private var phase2Scale: CGFloat = 0.85
    @State private var phase2Opacity: Double = 0.9

    private let duration: Double = 2.5
    private let targetScale: CGFloat = 1.3
    private let delayPhase2: Double = 0.15

    var body: some View {
        ZStack {
            Circle()
                .stroke(FogTokens.accentIndigo, lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(phase1Scale)
                .opacity(phase1Opacity)

            Circle()
                .stroke(FogTokens.accentIndigo, lineWidth: 1.0)
                .frame(width: size, height: size)
                .scaleEffect(phase2Scale)
                .opacity(phase2Opacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: duration)) {
                phase1Scale = targetScale
                phase1Opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delayPhase2) {
                withAnimation(.easeOut(duration: duration)) {
                    phase2Scale = targetScale
                    phase2Opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + delayPhase2 + 0.05) {
                onFinished()
            }
        }
    }
}

#Preview {
    ZStack {
        FogTokens.bgDeep.ignoresSafeArea()
        GhostRingView(size: 260)
    }
    .preferredColorScheme(.dark)
}

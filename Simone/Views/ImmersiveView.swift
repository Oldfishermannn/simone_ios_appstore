import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState


    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let specSize = min(w, h)

            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                let spectrum = state.audioEngine.spectrumData
                let bass = spectrum.prefix(4).reduce(Float(0), +) / max(Float(spectrum.prefix(4).count), 1)
                let avg = spectrum.reduce(Float(0), +) / max(Float(spectrum.count), 1)

                ZStack {
                    // Layer 0: Dark base
                    Color(red: 0.165, green: 0.165, blue: 0.18)
                        .ignoresSafeArea()

                    // Layer 1: Breathing radial glow behind spectrum
                    RadialGradient(
                        colors: [
                            MorandiPalette.rose.opacity(0.06 + Double(bass) * 0.08),
                            MorandiPalette.mauve.opacity(0.03 + Double(bass) * 0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: specSize * 0.7
                    )
                    .scaleEffect(1.0 + CGFloat(bass) * 0.08)
                    .ignoresSafeArea()

                    // Layer 2: Edge glow (four sides)
                    edgeGlow(w: w, h: h, energy: avg)

                    // Layer 3: Spectrum (core content, unchanged)
                    SpectrumCarouselView(state: state, showDots: false)
                        .frame(width: specSize, height: specSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBarHidden(true)
    }

    // MARK: - Edge Glow

    @ViewBuilder
    private func edgeGlow(w: CGFloat, h: CGFloat, energy: Float) -> some View {
        let intensity = 0.04 + Double(energy) * 0.06
        let glowH: CGFloat = 80

        // Top
        LinearGradient(
            colors: [MorandiPalette.rose.opacity(intensity), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: glowH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()

        // Bottom
        LinearGradient(
            colors: [MorandiPalette.mauve.opacity(intensity), .clear],
            startPoint: .bottom, endPoint: .top
        )
        .frame(height: glowH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()

        // Left
        LinearGradient(
            colors: [MorandiPalette.blue.opacity(intensity * 0.5), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(width: glowH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .ignoresSafeArea()

        // Right
        LinearGradient(
            colors: [MorandiPalette.sage.opacity(intensity * 0.5), .clear],
            startPoint: .trailing, endPoint: .leading
        )
        .frame(width: glowH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .ignoresSafeArea()
    }

}

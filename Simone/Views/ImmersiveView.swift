import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState

    // Ambient particles
    @State private var particles: [ImmersiveParticle] = []

    // Breathing
    @State private var breathScale: CGFloat = 1.0

    struct ImmersiveParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var color: Color
    }

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

                    // Layer 3: Ambient floating particles
                    Canvas { context, size in
                        for particle in particles {
                            let jitter = CGFloat(avg) * 1.5
                            let pSize = particle.size + jitter * 0.3
                            let pOpacity = particle.opacity + Double(avg) * 0.1
                            let rect = CGRect(
                                x: particle.x - pSize / 2,
                                y: particle.y - pSize / 2,
                                width: pSize,
                                height: pSize
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(particle.color.opacity(min(pOpacity, 0.35)))
                            )
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    // Layer 4: Spectrum (core content, unchanged)
                    SpectrumCarouselView(state: state, showDots: false)
                        .frame(width: specSize, height: specSize)
                }
                .onChange(of: timeline.date) { _, _ in
                    tickParticles(w: w, h: h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { seedParticles() }
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

    // MARK: - Particles

    private func seedParticles() {
        guard particles.isEmpty else { return }
        let colors = MorandiPalette.all
        particles = (0..<30).map { _ in
            ImmersiveParticle(
                x: CGFloat.random(in: 0...500),
                y: CGFloat.random(in: 0...900),
                size: CGFloat.random(in: 1.5...3.0),
                opacity: Double.random(in: 0.08...0.2),
                color: colors.randomElement() ?? .white
            )
        }
    }

    private func tickParticles(w: CGFloat, h: CGFloat) {
        for i in particles.indices {
            particles[i].x += CGFloat.random(in: -0.3...0.3)
            particles[i].y += CGFloat.random(in: -0.25...0.25)
            // Wrap around
            if particles[i].x < 0 { particles[i].x += w }
            if particles[i].x > w { particles[i].x -= w }
            if particles[i].y < 0 { particles[i].y += h }
            if particles[i].y > h { particles[i].y -= h }
        }
    }
}

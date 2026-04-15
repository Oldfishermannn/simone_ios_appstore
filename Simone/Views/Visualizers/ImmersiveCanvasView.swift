import SwiftUI

struct ImmersiveCanvasView: View {
    let spectrumData: [Float]

    // Mode switching: 0=Galaxy, 1=Aurora, 2=Pulse
    @State private var currentMode: Int = 0
    @State private var modeOpacity: [Double] = [1, 0, 0]
    @State private var timer: Timer?

    // Smoothed bass for breathing
    @State private var smoothBass: CGFloat = 0

    // Ambient particles positions (seeded once)
    @State private var particles: [AmbientParticle] = []

    // Pulse ripples
    @State private var ripples: [Ripple] = []
    @State private var lastBassHit: Date = .distantPast

    // Galaxy rotation
    @State private var galaxyAngle: Double = 0

    struct AmbientParticle {
        var x: CGFloat
        var y: CGFloat
        var dx: CGFloat
        var dy: CGFloat
        var size: CGFloat
        var baseOpacity: Double
    }

    struct Ripple: Identifiable {
        let id = UUID()
        var radius: CGFloat
        var opacity: Double
        var lineWidth: CGFloat
        var colorIndex: Int
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // --- Bass energy (smoothed) ---
                let rawBass = spectrumData.prefix(4).reduce(Float(0), +) / 4
                let targetBass = CGFloat(rawBass)

                // --- Layer 1: Breathing background ---
                drawBreathingBackground(context: context, w: w, h: h, bass: targetBass)

                // --- Layer 2: Main visualization modes ---
                if modeOpacity[0] > 0.01 {
                    context.opacity = modeOpacity[0]
                    drawGalaxy(context: context, w: w, h: h)
                    context.opacity = 1
                }
                if modeOpacity[1] > 0.01 {
                    context.opacity = modeOpacity[1]
                    drawAurora(context: context, w: w, h: h)
                    context.opacity = 1
                }
                if modeOpacity[2] > 0.01 {
                    context.opacity = modeOpacity[2]
                    drawPulseRipples(context: context, w: w, h: h)
                    context.opacity = 1
                }

                // --- Layer 3: Ambient particles ---
                drawAmbientParticles(context: context, w: w, h: h)

                // --- Layer 4: Edge glow ---
                drawEdgeGlow(context: context, w: w, h: h)
            }
            .onChange(of: timeline.date) { _, _ in
                updateState()
            }
        }
        .onAppear {
            initParticles()
            startModeTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - State Updates

    private func updateState() {
        // Smooth bass
        let rawBass = spectrumData.prefix(4).reduce(Float(0), +) / 4
        let target = CGFloat(rawBass)
        smoothBass = smoothBass * 0.92 + target * 0.08

        // Galaxy rotation
        galaxyAngle += 0.12

        // Update ambient particles
        var updatedParticles = particles
        for i in updatedParticles.indices {
            updatedParticles[i].x += updatedParticles[i].dx
            updatedParticles[i].y += updatedParticles[i].dy
        }
        particles = updatedParticles

        // Trigger ripple on bass hit
        if rawBass > 0.4 && Date().timeIntervalSince(lastBassHit) > 0.5 {
            lastBassHit = Date()
            if ripples.count < 6 {
                ripples.append(Ripple(
                    radius: 10,
                    opacity: 0.5,
                    lineWidth: 3,
                    colorIndex: Int.random(in: 0..<5)
                ))
            }
        }

        // Expand and fade ripples
        var updatedRipples = ripples
        for i in updatedRipples.indices {
            updatedRipples[i].radius += 3
            updatedRipples[i].opacity -= 0.008
            updatedRipples[i].lineWidth = max(0.5, updatedRipples[i].lineWidth - 0.03)
        }
        updatedRipples.removeAll { $0.opacity <= 0 }
        ripples = updatedRipples
    }

    // MARK: - Layer 1: Breathing Background

    private func drawBreathingBackground(context: GraphicsContext, w: CGFloat, h: CGFloat, bass: CGFloat) {
        let intensity = smoothBass * 0.08
        let roseRect = CGRect(x: 0, y: 0, width: w, height: h)
        context.fill(
            Path(roseRect),
            with: .color(MorandiPalette.rose.opacity(Double(intensity)))
        )
        let mauveRect = CGRect(x: 0, y: 0, width: w, height: h * 0.6)
        context.fill(
            Path(mauveRect),
            with: .color(MorandiPalette.mauve.opacity(Double(intensity) * 0.5))
        )
    }

    // MARK: - Layer 2A: Galaxy

    private func drawGalaxy(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        let cx = w / 2
        let cy = h / 2
        let count = 120
        let binCount = spectrumData.count
        guard binCount > 0 else { return }

        for i in 0..<count {
            let t = Double(i) / Double(count)
            let angle = t * 2 * .pi + galaxyAngle * .pi / 180

            let bin = min(Int(t * Double(binCount)), binCount - 1)
            let value = CGFloat(spectrumData[bin])

            let rx = w * 0.38 * (0.3 + t * 0.7)
            let ry = h * 0.25 * (0.3 + t * 0.7)
            let x = cx + rx * cos(angle)
            let y = cy + ry * sin(angle)

            let color = MorandiPalette.color(at: i % 5)
            let size = 1.5 + value * 4
            let opacity = 0.15 + Double(value) * 0.6

            // Trail
            let trailLen = value * 12
            let tx = x - trailLen * cos(angle)
            let ty = y - trailLen * sin(angle)
            var trail = Path()
            trail.move(to: CGPoint(x: tx, y: ty))
            trail.addLine(to: CGPoint(x: x, y: y))
            context.stroke(
                trail,
                with: .color(color.opacity(opacity * 0.3)),
                style: StrokeStyle(lineWidth: size * 0.6, lineCap: .round)
            )

            // Particle
            let rect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))

            // Glow on bright particles
            if value > 0.35 {
                let glowR = size * 3
                let glowRect = CGRect(x: x - glowR / 2, y: y - glowR / 2, width: glowR, height: glowR)
                context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(Double(value) * 0.1)))
            }
        }
    }

    // MARK: - Layer 2B: Aurora

    private func drawAurora(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        let layers: [(color: Color, baseRatio: CGFloat, ampScale: CGFloat)] = [
            (MorandiPalette.rose, 0.55, 0.35),
            (MorandiPalette.mauve, 0.50, 0.30),
            (MorandiPalette.sage, 0.45, 0.25),
        ]

        let points = 96

        for (layerIdx, layer) in layers.enumerated() {
            var yValues = [CGFloat]()
            for i in 0...points {
                let t = Float(i) / Float(points)
                let binF = t * Float(spectrumData.count - 1)
                let offset = Float(layerIdx) * 4.0
                let bin = Int(min(max(binF + offset, 0), Float(spectrumData.count - 1)))
                let value = CGFloat(spectrumData[min(bin, spectrumData.count - 1)])
                let baseY = h * layer.baseRatio
                let amplitude = h * layer.ampScale * value
                yValues.append(baseY - amplitude)
            }

            var stroke = Path()
            stroke.move(to: CGPoint(x: 0, y: yValues[0]))
            for i in 1...points {
                let x0 = w * CGFloat(i - 1) / CGFloat(points)
                let x1 = w * CGFloat(i) / CGFloat(points)
                let cx = (x0 + x1) / 2
                stroke.addCurve(
                    to: CGPoint(x: x1, y: yValues[i]),
                    control1: CGPoint(x: cx, y: yValues[i - 1]),
                    control2: CGPoint(x: cx, y: yValues[i])
                )
            }

            // Fill beneath
            var fill = stroke
            fill.addLine(to: CGPoint(x: w, y: h))
            fill.addLine(to: CGPoint(x: 0, y: h))
            fill.closeSubpath()

            context.fill(fill, with: .color(layer.color.opacity(0.04 + Double(layerIdx) * 0.02)))

            let lineWidth = 3.5 - CGFloat(layerIdx) * 0.5
            context.stroke(
                stroke,
                with: .color(layer.color.opacity(0.5 - Double(layerIdx) * 0.1)),
                lineWidth: lineWidth
            )
        }
    }

    // MARK: - Layer 2C: Pulse Ripples

    private func drawPulseRipples(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        let cx = w / 2
        let cy = h / 2

        for ripple in ripples {
            let color = MorandiPalette.color(at: ripple.colorIndex)
            var ring = Path()
            ring.addEllipse(in: CGRect(
                x: cx - ripple.radius,
                y: cy - ripple.radius,
                width: ripple.radius * 2,
                height: ripple.radius * 2
            ))
            context.stroke(
                ring,
                with: .color(color.opacity(ripple.opacity)),
                lineWidth: ripple.lineWidth
            )

            // Inner glow
            context.fill(ring, with: .color(color.opacity(ripple.opacity * 0.05)))
        }

        // Center pulse dot
        let pulse = smoothBass
        let dotR = 4 + pulse * 10
        let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
        context.fill(
            Path(ellipseIn: dotRect),
            with: .color(MorandiPalette.rose.opacity(0.3 + Double(pulse) * 0.4))
        )
    }

    // MARK: - Layer 3: Ambient Particles

    private func drawAmbientParticles(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        let midEnergy = spectrumData.count > 32
            ? spectrumData[16..<32].reduce(Float(0), +) / 16
            : Float(0)

        for particle in particles {
            let px = particle.x.truncatingRemainder(dividingBy: w)
            let py = particle.y.truncatingRemainder(dividingBy: h)
            let x = px < 0 ? px + w : px
            let y = py < 0 ? py + h : py

            let jitter = CGFloat(midEnergy) * 2
            let size = particle.size + jitter * 0.5
            let opacity = particle.baseOpacity + Double(midEnergy) * 0.15

            let rect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(min(opacity, 0.4)))
            )
        }
    }

    // MARK: - Layer 4: Edge Glow

    private func drawEdgeGlow(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        let avgEnergy = spectrumData.reduce(Float(0), +) / max(Float(spectrumData.count), 1)
        let intensity = 0.05 + Double(avgEnergy) * 0.08
        let glowWidth: CGFloat = 60

        let colors: [Color] = [MorandiPalette.rose, MorandiPalette.mauve, MorandiPalette.blue, MorandiPalette.sage]

        // Top
        let topRect = CGRect(x: 0, y: 0, width: w, height: glowWidth)
        context.fill(Path(topRect), with: .color(colors[0].opacity(intensity)))

        // Bottom
        let bottomRect = CGRect(x: 0, y: h - glowWidth, width: w, height: glowWidth)
        context.fill(Path(bottomRect), with: .color(colors[1].opacity(intensity)))

        // Left
        let leftRect = CGRect(x: 0, y: 0, width: glowWidth, height: h)
        context.fill(Path(leftRect), with: .color(colors[2].opacity(intensity * 0.6)))

        // Right
        let rightRect = CGRect(x: w - glowWidth, y: 0, width: glowWidth, height: h)
        context.fill(Path(rightRect), with: .color(colors[3].opacity(intensity * 0.6)))
    }

    // MARK: - Init & Timer

    private func initParticles() {
        guard particles.isEmpty else { return }
        var p = [AmbientParticle]()
        for _ in 0..<40 {
            p.append(AmbientParticle(
                x: CGFloat.random(in: 0...500),
                y: CGFloat.random(in: 0...900),
                dx: CGFloat.random(in: -0.2...0.2),
                dy: CGFloat.random(in: -0.15...0.15),
                size: CGFloat.random(in: 1.5...3),
                baseOpacity: Double.random(in: 0.1...0.25)
            ))
        }
        particles = p
    }

    private func startModeTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            let next = (currentMode + 1) % 3
            withAnimation(.easeInOut(duration: 1.5)) {
                modeOpacity[currentMode] = 0
                modeOpacity[next] = 1
            }
            currentMode = next
        }
    }
}

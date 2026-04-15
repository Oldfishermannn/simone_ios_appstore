import SwiftUI

struct ParticleFlowView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let particleCount = 60
            let binCount = spectrumData.count

            guard binCount > 0 else { return }

            let margin = w * 0.1
            let innerW = w - margin * 2
            let innerH = h - margin * 2

            for i in 0..<particleCount {
                let t = Float(i) / Float(particleCount)

                // Map particle to a spectrum bin
                let bin = min(Int(t * Float(binCount)), binCount - 1)
                let value = CGFloat(spectrumData[bin])

                // Position: spread horizontally within margin, vertical driven by energy
                let x = margin + CGFloat(i) / CGFloat(particleCount) * innerW
                let baseY = h * 0.5
                let yOffset = (value - 0.3) * innerH * 0.5
                let y = baseY - yOffset

                // Size driven by energy — smaller
                let radius = 1.2 + value * 3.5
                let color = MorandiPalette.color(at: i % 5)

                // Trail (stretched ellipse going downward)
                let trailLength = value * 20
                let trailRect = CGRect(
                    x: x - radius * 0.4,
                    y: y,
                    width: radius * 0.8,
                    height: trailLength
                )
                context.fill(
                    Path(ellipseIn: trailRect),
                    with: .color(color.opacity(Double(value) * 0.15))
                )

                // Particle body
                let rect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(color.opacity(0.3 + Double(value) * 0.5))
                )

                // Glow
                let glowR = radius * 2.5
                let glowRect = CGRect(
                    x: x - glowR,
                    y: y - glowR,
                    width: glowR * 2,
                    height: glowR * 2
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(color.opacity(Double(value) * 0.1))
                )
            }
        }
    }
}

import SwiftUI

struct OrbitalView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let binCount = spectrumData.count

            guard binCount > 0 else { return }

            let orbits = 4
            let dotsPerOrbit = 12
            let colors: [Color] = [
                MorandiPalette.rose,
                MorandiPalette.mauve,
                MorandiPalette.sage,
                MorandiPalette.blue,
            ]

            for orbit in 0..<orbits {
                let baseRadius = min(w, h) * (0.12 + 0.08 * CGFloat(orbit))
                let color = colors[orbit]

                // Draw orbit path (ellipse)
                let orbitRect = CGRect(
                    x: cx - baseRadius,
                    y: cy - baseRadius * 0.65,
                    width: baseRadius * 2,
                    height: baseRadius * 1.3
                )
                context.stroke(
                    Path(ellipseIn: orbitRect),
                    with: .color(color.opacity(0.08)),
                    lineWidth: 0.5
                )

                // Place dots along orbit
                for dot in 0..<dotsPerOrbit {
                    let angle = (Double(dot) / Double(dotsPerOrbit)) * 2 * .pi

                    let globalIdx = orbit * dotsPerOrbit + dot
                    let bin = min(globalIdx * binCount / (orbits * dotsPerOrbit), binCount - 1)
                    let value = CGFloat(spectrumData[bin])

                    let rx = baseRadius + value * baseRadius * 0.3
                    let ry = baseRadius * 0.65 + value * baseRadius * 0.2

                    let x = cx + rx * cos(angle)
                    let y = cy + ry * sin(angle)

                    let dotSize = 2 + value * 4
                    let dotRect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(color.opacity(0.3 + Double(value) * 0.6))
                    )

                    // Glow
                    if value > 0.2 {
                        let glowSize = dotSize * 3
                        let glowRect = CGRect(
                            x: x - glowSize / 2,
                            y: y - glowSize / 2,
                            width: glowSize,
                            height: glowSize
                        )
                        context.fill(
                            Path(ellipseIn: glowRect),
                            with: .color(color.opacity(Double(value) * 0.1))
                        )
                    }
                }
            }

            // Center dot
            let avgBass = spectrumData.prefix(4).reduce(Float(0), +) / 4
            let pulse = CGFloat(avgBass)
            let centerR = 3 + pulse * 5
            let centerRect = CGRect(x: cx - centerR, y: cy - centerR, width: centerR * 2, height: centerR * 2)
            context.fill(
                Path(ellipseIn: centerRect),
                with: .color(MorandiPalette.rose.opacity(0.4 + Double(pulse) * 0.4))
            )
        }
    }
}

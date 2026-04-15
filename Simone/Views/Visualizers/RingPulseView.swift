import SwiftUI

struct RingPulseView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let segments = density > 1 ? 64 : 36
            let ringCount = density > 1 ? 7 : 4
            let binCount = spectrumData.count

            guard binCount > 0 else { return }

            let colors: [Color] = [
                MorandiPalette.rose,
                MorandiPalette.mauve,
                MorandiPalette.sage,
                MorandiPalette.blue,
            ]

            for ring in 0..<ringCount {
                let baseRadius = min(w, h) * (0.08 + 0.08 * CGFloat(ring))
                let color = colors[ring % colors.count]

                var path = Path()
                for s in 0...segments {
                    let angle = CGFloat(s) / CGFloat(segments) * 2 * .pi - .pi / 2

                    // Map segment angle to spectrum bin
                    let binF = Float(s) / Float(segments) * Float(binCount - 1)
                    let binOffset = Float(ring) * 4
                    let bin = Int(min(max(binF + binOffset, 0), Float(binCount - 1)))
                    let value = CGFloat(spectrumData[bin])

                    let amplitude = baseRadius * 0.6 * value
                    let r = baseRadius + amplitude

                    let x = cx + r * cos(angle)
                    let y = cy + r * sin(angle)

                    if s == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()

                // Fill with low opacity
                context.fill(
                    path,
                    with: .color(color.opacity(0.06 + Double(ring) * 0.02))
                )

                // Stroke
                context.stroke(
                    path,
                    with: .color(color.opacity(0.25 + Double(ring) * 0.05)),
                    lineWidth: 1.5
                )
            }

            // Center pulse dot
            let avgBass = spectrumData.prefix(4).reduce(Float(0), +) / 4
            let pulse = CGFloat(avgBass)
            let dotR = 4 + pulse * 8
            let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(
                Path(ellipseIn: dotRect),
                with: .color(MorandiPalette.rose.opacity(0.3 + Double(pulse) * 0.5))
            )

            // Outer glow
            let glowR = dotR * 3
            let glowRect = CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(MorandiPalette.rose.opacity(Double(pulse) * 0.1))
            )
        }
    }
}

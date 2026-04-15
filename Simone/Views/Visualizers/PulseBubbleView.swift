import SwiftUI

struct PulseBubbleView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let binCount = spectrumData.count

            guard binCount > 0 else { return }

            let bubbleCount = 16
            let colors: [Color] = [
                MorandiPalette.rose,
                MorandiPalette.mauve,
                MorandiPalette.sage,
                MorandiPalette.blue,
                MorandiPalette.sand,
            ]

            for i in 0..<bubbleCount {
                let bin = min(i * binCount / bubbleCount, binCount - 1)
                let value = CGFloat(spectrumData[bin])

                // Distribute in a circular pattern
                let angle = Double(i) / Double(bubbleCount) * 2 * .pi
                let spreadRadius = min(w, h) * 0.28
                let x = cx + spreadRadius * cos(angle) * (0.7 + Double(value) * 0.3)
                let y = cy + spreadRadius * sin(angle) * (0.7 + Double(value) * 0.3)

                let color = colors[i % colors.count]

                // Outer glow circle
                let glowRadius = 12 + value * 25
                let glowRect = CGRect(
                    x: x - Double(glowRadius),
                    y: y - Double(glowRadius),
                    width: Double(glowRadius * 2),
                    height: Double(glowRadius * 2)
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(color.opacity(Double(value) * 0.08))
                )

                // Bubble ring
                let ringRadius = 6 + value * 14
                var ring = Path()
                ring.addEllipse(in: CGRect(
                    x: x - Double(ringRadius),
                    y: y - Double(ringRadius),
                    width: Double(ringRadius * 2),
                    height: Double(ringRadius * 2)
                ))
                context.stroke(
                    ring,
                    with: .color(color.opacity(0.2 + Double(value) * 0.4)),
                    lineWidth: 1.2 + value * 1.5
                )

                // Inner dot
                let dotR = 2 + value * 3
                let dotRect = CGRect(
                    x: x - Double(dotR),
                    y: y - Double(dotR),
                    width: Double(dotR * 2),
                    height: Double(dotR * 2)
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(color.opacity(0.4 + Double(value) * 0.5))
                )
            }
        }
    }
}

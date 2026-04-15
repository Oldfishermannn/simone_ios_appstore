import SwiftUI

struct ConstellationView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let starCount = 28

            var positions: [CGPoint] = []
            var brightnesses: [CGFloat] = []
            var colors: [Color] = []

            for i in 0..<starCount {
                let bin = min(i * spectrumData.count / starCount, spectrumData.count - 1)
                let value = CGFloat(spectrumData[max(0, bin)])

                let angle = Double(i) / Double(starCount) * 2 * .pi
                let baseRadius = w * 0.32
                let breathe = value * 0.4 + 0.5
                let radius = baseRadius * breathe
                let x = w / 2 + radius * cos(angle)
                let y = h / 2 + radius * sin(angle) * 0.6

                positions.append(CGPoint(x: x, y: y))
                brightnesses.append(value)
                colors.append(MorandiPalette.color(at: i))
            }

            // Draw connections — brightness drives line opacity
            for i in 0..<positions.count {
                for j in (i + 1)..<positions.count {
                    let dist = hypot(
                        positions[i].x - positions[j].x,
                        positions[i].y - positions[j].y
                    )
                    let threshold = w * 0.22
                    if dist < threshold {
                        var line = Path()
                        line.move(to: positions[i])
                        line.addLine(to: positions[j])
                        let proximity = 1 - dist / threshold
                        let avgBright = (brightnesses[i] + brightnesses[j]) / 2
                        let opacity = proximity * 0.2 * (0.3 + Double(avgBright) * 0.7)
                        context.stroke(
                            line,
                            with: .color(.white.opacity(opacity)),
                            lineWidth: 0.5
                        )
                    }
                }
            }

            // Draw stars with breathing glow
            for i in 0..<positions.count {
                let b = brightnesses[i]
                let starSize = 2 + b * 5

                // Outer glow (breathing)
                let glowSize = starSize * (3 + b * 2)
                let glowRect = CGRect(
                    x: positions[i].x - glowSize / 2,
                    y: positions[i].y - glowSize / 2,
                    width: glowSize, height: glowSize
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(colors[i].opacity(Double(b) * 0.12))
                )

                // Star body
                let rect = CGRect(
                    x: positions[i].x - starSize / 2,
                    y: positions[i].y - starSize / 2,
                    width: starSize, height: starSize
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(colors[i].opacity(0.4 + Double(b) * 0.6))
                )
            }
        }
    }
}

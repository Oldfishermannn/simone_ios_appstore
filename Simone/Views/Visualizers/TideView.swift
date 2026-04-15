import SwiftUI

struct TideView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let waveCount = density > 1 ? 10 : 6
            let points = density > 1 ? 80 : 48
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            for wave in 0..<waveCount {
                let wt = CGFloat(wave) / CGFloat(waveCount - 1)
                let baseY = h * (0.25 + wt * 0.55)
                let freq = 2.0 + Double(wave) * 0.5

                var yValues = [CGFloat]()
                for i in 0...points {
                    let t = CGFloat(i) / CGFloat(points)
                    let bin = min(Int(Float(t) * Float(binCount - 1)), binCount - 1)
                    let value = CGFloat(spectrumData[bin])
                    let sineOffset = sin(Double(t) * freq * .pi) * Double(value) * 0.08 * Double(h)
                    yValues.append(baseY - CGFloat(sineOffset))
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

                let color = MorandiPalette.color(at: wave)
                let opacity = 0.15 + Double(1 - wt) * 0.25
                context.stroke(stroke, with: .color(color.opacity(opacity)), lineWidth: 1.5)

                // Subtle fill
                var fill = stroke
                fill.addLine(to: CGPoint(x: w, y: h))
                fill.addLine(to: CGPoint(x: 0, y: h))
                fill.closeSubpath()
                context.fill(fill, with: .color(color.opacity(0.02 + Double(1 - wt) * 0.03)))
            }
        }
    }
}

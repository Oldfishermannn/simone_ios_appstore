import SwiftUI

struct RainfallView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let barCount = density > 1 ? 48 : 28
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let barWidth = w / CGFloat(barCount)

            for i in 0..<barCount {
                let bin = min(i * binCount / barCount, binCount - 1)
                let value = CGFloat(spectrumData[bin])

                let x = CGFloat(i) * barWidth + barWidth / 2
                let barH = h * 0.8 * value
                let topY = h - barH

                // Rain drop line
                var line = Path()
                line.move(to: CGPoint(x: x, y: topY))
                line.addLine(to: CGPoint(x: x, y: h))

                let color = MorandiPalette.color(at: i % 5)
                let opacity = 0.1 + Double(value) * 0.4
                context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: barWidth * 0.4)

                // Drop head glow
                if value > 0.15 {
                    let dotSize = barWidth * 0.6 + value * 4
                    let dotRect = CGRect(x: x - dotSize / 2, y: topY - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.3 + Double(value) * 0.4)))
                }
            }
        }
    }
}

import SwiftUI

struct RainfallView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Always use normal density, center content if wider than tall
            let barCount = 28
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let drawSize = min(w, h)
            let offsetX = (w - drawSize) / 2
            let offsetY = (h - drawSize) / 2

            let barWidth = drawSize / CGFloat(barCount)

            for i in 0..<barCount {
                let bin = min(i * binCount / barCount, binCount - 1)
                let value = CGFloat(spectrumData[bin])

                let x = offsetX + CGFloat(i) * barWidth + barWidth / 2
                let barH = drawSize * 0.8 * value
                let topY = offsetY + drawSize - barH
                let bottomY = offsetY + drawSize

                var line = Path()
                line.move(to: CGPoint(x: x, y: topY))
                line.addLine(to: CGPoint(x: x, y: bottomY))

                let color = MorandiPalette.color(at: i % 5)
                let opacity = 0.1 + Double(value) * 0.4
                context.stroke(line, with: .color(color.opacity(opacity)), lineWidth: barWidth * 0.4)
            }
        }
    }
}

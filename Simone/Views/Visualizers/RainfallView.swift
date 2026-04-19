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

            // Idle baseline — 全零时画成柔和的钟形瀑布，保持雨滴阵列的画面感
            let maxValue = spectrumData.max() ?? 0
            let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

            for i in 0..<barCount {
                let bin = min(i * binCount / barCount, binCount - 1)
                let raw = CGFloat(spectrumData[bin])
                let t = CGFloat(i) / CGFloat(barCount - 1)
                // 中间高两边低的钟形 + 轻微起伏
                let bell = sin(t * .pi)
                let ripple = 0.5 + 0.5 * sin(t * .pi * 4)
                let idleVal: CGFloat = 0.18 + 0.32 * bell * (0.75 + 0.25 * ripple)
                let value = raw * (1 - idleBlend) + idleVal * idleBlend

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

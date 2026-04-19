import SwiftUI

struct GlitchView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let scanLines = density > 1 ? 40 : 24

            // Idle baseline — 没音频时让 CRT 扫描带仍有柔和起伏和色偏
            let maxValue = spectrumData.max() ?? 0
            let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

            // Horizontal scan lines with frequency-driven displacement
            for line in 0..<scanLines {
                let t = Float(line) / Float(scanLines)
                let bin = min(Int(t * Float(binCount - 1)), binCount - 1)
                let raw = CGFloat(spectrumData[bin])
                // 波段切片：三层柔和波形叠加，让扫描带有 "死机" 感但不空
                let idleVal: CGFloat = 0.20 + 0.18 * CGFloat(sinf(t * .pi * 3)) * CGFloat(sinf(t * .pi * 1.3))
                let value = raw * (1 - idleBlend) + max(0, idleVal) * idleBlend

                let y = h * CGFloat(t)
                let lineHeight = h / CGFloat(scanLines) - 1

                // Horizontal displacement (glitch offset)
                let displacement = value * 30 * (line % 2 == 0 ? 1 : -1)

                // Color channel separation
                let colors: [(Color, CGFloat)] = [
                    (MorandiPalette.rose, displacement * 1.2),
                    (MorandiPalette.blue, -displacement * 0.8),
                    (MorandiPalette.sage, displacement * 0.3),
                ]

                for (color, offset) in colors {
                    // Bar width based on spectrum value
                    let barWidth = w * (0.3 + CGFloat(value) * 0.7)
                    let barX = (w - barWidth) / 2 + offset

                    let rect = CGRect(x: barX, y: y, width: barWidth, height: lineHeight)
                    context.fill(Path(rect), with: .color(color.opacity(0.04 + Double(value) * 0.15)))
                }

                // Bright glitch blocks on high values
                if value > 0.5 {
                    let blockW = w * CGFloat.random(in: 0.1...0.4)
                    let blockX = CGFloat.random(in: 0...w - blockW) + displacement
                    let glitchRect = CGRect(x: blockX, y: y, width: blockW, height: lineHeight * 2)
                    let glitchColor = MorandiPalette.color(at: line % 5)
                    context.fill(Path(glitchRect), with: .color(glitchColor.opacity(Double(value - 0.5) * 0.4)))
                }
            }

            // Vertical noise bars
            let bassHit = CGFloat(spectrumData.prefix(4).max() ?? 0)
            if bassHit > 0.4 {
                for _ in 0..<3 {
                    let x = CGFloat.random(in: 0...w)
                    let barW: CGFloat = 2 + CGFloat.random(in: 0...4)
                    let rect = CGRect(x: x, y: 0, width: barW, height: h)
                    context.fill(Path(rect), with: .color(.white.opacity(Double(bassHit - 0.4) * 0.15)))
                }
            }
        }
    }
}

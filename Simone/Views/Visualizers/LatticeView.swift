import SwiftUI

struct LatticeView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cols = density > 1 ? 12 : 8
            let rows = density > 1 ? 16 : 10
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let cellW = w / CGFloat(cols)
            let cellH = h / CGFloat(rows)

            // Idle baseline — 没音频时每个点有柔和大小变化，形成类似织物的静态图案
            let maxValue = spectrumData.max() ?? 0
            let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

            for row in 0..<rows {
                for col in 0..<cols {
                    let idx = row * cols + col
                    let bin = min(idx * binCount / (rows * cols), binCount - 1)
                    let raw = CGFloat(spectrumData[bin])
                    // 静态图案：对角交错 + 双波，形成织纹
                    let rowT = CGFloat(row) / CGFloat(max(rows - 1, 1))
                    let colT = CGFloat(col) / CGFloat(max(cols - 1, 1))
                    let weave = (0.5 + 0.5 * sin(rowT * .pi * 3)) * (0.5 + 0.5 * sin(colT * .pi * 3 + rowT * .pi))
                    let idleVal: CGFloat = 0.12 + 0.32 * weave
                    let value = raw * (1 - idleBlend) + idleVal * idleBlend

                    let cx = CGFloat(col) * cellW + cellW / 2
                    let cy = CGFloat(row) * cellH + cellH / 2

                    let dotSize = 2 + value * 8
                    let color = MorandiPalette.color(at: (row + col) % 5)
                    let opacity = 0.08 + Double(value) * 0.5

                    let rect = CGRect(x: cx - dotSize / 2, y: cy - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))

                    // Glow on bright dots
                    if value > 0.3 {
                        let glowSize = dotSize * 3
                        let glowRect = CGRect(x: cx - glowSize / 2, y: cy - glowSize / 2, width: glowSize, height: glowSize)
                        context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(Double(value) * 0.08)))
                    }
                }
            }
        }
    }
}

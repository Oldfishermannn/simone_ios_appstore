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

            for row in 0..<rows {
                for col in 0..<cols {
                    let idx = row * cols + col
                    let bin = min(idx * binCount / (rows * cols), binCount - 1)
                    let value = CGFloat(spectrumData[bin])

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

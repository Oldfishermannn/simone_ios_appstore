import SwiftUI

struct MatrixView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let cols = density > 1 ? 32 : 20
            let rows = density > 1 ? 24 : 16
            let cellW = w / CGFloat(cols)
            let cellH = h / CGFloat(rows)

            for col in 0..<cols {
                let t = Float(col) / Float(cols)
                let bin = min(Int(t * Float(binCount - 1)), binCount - 1)

                // Average nearby bins for smoother response
                let lo = max(0, bin - 1)
                let hi = min(binCount - 1, bin + 1)
                let avg = (spectrumData[lo] + spectrumData[bin] * 2 + spectrumData[hi]) / 4
                let value = CGFloat(avg)

                // Quantize to reduce jitter — snap to nearest 2 rows
                let rawActive = Int(value * CGFloat(rows))
                let activeRows = (rawActive / 2) * 2

                for row in 0..<rows {
                    let rowFromBottom = rows - 1 - row
                    let isActive = rowFromBottom < activeRows
                    guard isActive else { continue }

                    let brightness = CGFloat(activeRows - rowFromBottom) / CGFloat(max(activeRows, 1))
                    let x = CGFloat(col) * cellW
                    let y = CGFloat(row) * cellH

                    let inset: CGFloat = 1
                    let blockRect = CGRect(x: x + inset, y: y + inset, width: cellW - inset * 2, height: cellH - inset * 2)

                    let color: Color
                    if rowFromBottom == activeRows - 1 {
                        color = MorandiPalette.sage.opacity(0.6 + Double(value) * 0.3)
                    } else {
                        color = MorandiPalette.sage.opacity(Double(brightness) * 0.35 * Double(value) + 0.02)
                    }

                    context.fill(Path(blockRect), with: .color(color))
                }
            }
        }
    }
}

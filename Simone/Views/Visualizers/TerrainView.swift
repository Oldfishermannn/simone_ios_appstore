import SwiftUI

struct TerrainView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let rowCount = density > 1 ? 16 : 10
            let cols = density > 1 ? 48 : 32
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            for row in 0..<rowCount {
                let rowT = CGFloat(row) / CGFloat(rowCount - 1)
                let baseY = h * (0.2 + rowT * 0.65)
                let perspective = 0.3 + rowT * 0.7

                var path = Path()
                for col in 0...cols {
                    let colT = Float(col) / Float(cols)
                    let binOffset = Float(row) * 3
                    let bin = Int(min(max(colT * Float(binCount - 1) + binOffset, 0), Float(binCount - 1)))
                    let value = CGFloat(spectrumData[bin])

                    let x = w * CGFloat(col) / CGFloat(cols)
                    let amplitude = h * 0.08 * value * perspective
                    let y = baseY - amplitude

                    if col == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let prevX = w * CGFloat(col - 1) / CGFloat(cols)
                        path.addQuadCurve(
                            to: CGPoint(x: x, y: y),
                            control: CGPoint(x: (prevX + x) / 2, y: y + 1)
                        )
                    }
                }

                let color = MorandiPalette.color(at: row % 5)
                let opacity = 0.12 + Double(rowT) * 0.25
                let lineWidth = 0.8 + rowT * 1.0
                context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: lineWidth)
            }
        }
    }
}

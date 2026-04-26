import SwiftUI

struct CascadeView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineCount = density > 1 ? 24 : 12
            let segments = density > 1 ? 90 : 60

            guard spectrumData.count > 0 else { return }

            for line in 0..<lineCount {
                let t = CGFloat(line) / CGFloat(lineCount - 1)
                let baseY = h * (0.15 + t * 0.7)
                let color = MorandiPalette.color(at: line)

                var path = Path()
                for i in 0...segments {
                    let x = w * CGFloat(i) / CGFloat(segments)
                    let bin = min(i * spectrumData.count / max(segments, 1), spectrumData.count - 1)
                    let binOffset = line * 2
                    let actualBin = min(max(bin + binOffset, 0), spectrumData.count - 1)
                    let value = CGFloat(spectrumData[actualBin])

                    let amplitude = h * 0.06 * value
                    let y = baseY - amplitude

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let prevX = w * CGFloat(i - 1) / CGFloat(segments)
                        path.addQuadCurve(
                            to: CGPoint(x: x, y: y),
                            control: CGPoint(x: (prevX + x) / 2, y: y + 2)
                        )
                    }
                }

                let opacity = 0.15 + Double(1 - t) * 0.35
                let lineWidth = 1.0 + (1 - t) * 1.2
                context.stroke(
                    path,
                    with: .color(color.opacity(opacity)),
                    lineWidth: lineWidth
                )
            }
        }
    }
}

import SwiftUI

struct PrismView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let shapeCount = density > 1 ? 10 : 6
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            // Idle baseline — 没音频时多边形有更显眼的填充/描边
            let maxValue = spectrumData.max() ?? 0
            let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

            for i in 0..<shapeCount {
                let t = CGFloat(i) / CGFloat(shapeCount)
                let bin = min(Int(Float(t) * Float(binCount - 1)), binCount - 1)
                let raw = CGFloat(spectrumData[bin])
                let idleVal: CGFloat = 0.28 + 0.22 * (0.5 + 0.5 * sin(t * .pi * 3 + CGFloat(i) * 0.5))
                let value = raw * (1 - idleBlend) + idleVal * idleBlend

                let sides = 3 + (i % 4) // 3~6 sided polygons
                let baseR = min(w, h) * (0.08 + t * 0.3)
                let r = baseR + value * 20
                let rotation = Double(t) * .pi / 3

                var path = Path()
                for s in 0...sides {
                    let angle = Double(s) / Double(sides) * 2 * .pi + rotation
                    let px = cx + r * cos(angle)
                    let py = cy + r * sin(angle) * 0.75

                    if s == 0 {
                        path.move(to: CGPoint(x: px, y: py))
                    } else {
                        path.addLine(to: CGPoint(x: px, y: py))
                    }
                }
                path.closeSubpath()

                let color = MorandiPalette.color(at: i)
                context.fill(path, with: .color(color.opacity(0.03 + Double(value) * 0.06)))
                context.stroke(path, with: .color(color.opacity(0.15 + Double(value) * 0.35)), lineWidth: 1.2)
            }
        }
    }
}

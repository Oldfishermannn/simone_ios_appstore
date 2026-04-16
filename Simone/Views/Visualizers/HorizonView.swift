import SwiftUI

struct HorizonView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let layers: [(color: Color, baseY: CGFloat, amp: CGFloat)] = density > 1
                ? [
                    (MorandiPalette.sand,  0.88, 0.16),
                    (MorandiPalette.blue,  0.82, 0.22),
                    (MorandiPalette.sage,  0.75, 0.20),
                    (MorandiPalette.mauve, 0.68, 0.18),
                    (MorandiPalette.rose,  0.60, 0.16),
                    (MorandiPalette.blue,  0.52, 0.14),
                    (MorandiPalette.sage,  0.44, 0.12),
                    (MorandiPalette.mauve, 0.36, 0.10),
                ]
                : [
                    (MorandiPalette.blue,  0.75, 0.20),
                    (MorandiPalette.sage,  0.68, 0.18),
                    (MorandiPalette.mauve, 0.60, 0.16),
                    (MorandiPalette.rose,  0.52, 0.14),
                ]

            let points = density > 1 ? 96 : 64

            for (layerIdx, layer) in layers.enumerated() {
                var yValues = [CGFloat]()
                for i in 0...points {
                    let t = Float(i) / Float(points)
                    let binF = t * Float(spectrumData.count - 1)
                    let offset = Float(layerIdx) * 3.0
                    let bin = Int(min(max(binF + offset, 0), Float(spectrumData.count - 1)))
                    let value = CGFloat(spectrumData[min(bin, spectrumData.count - 1)])
                    let baseY = h * layer.baseY
                    let amplitude = h * layer.amp * value
                    yValues.append(baseY - amplitude)
                }

                // Mountain silhouette path
                var stroke = Path()
                stroke.move(to: CGPoint(x: 0, y: yValues[0]))
                for i in 1...points {
                    let x0 = w * CGFloat(i - 1) / CGFloat(points)
                    let x1 = w * CGFloat(i) / CGFloat(points)
                    let cx = (x0 + x1) / 2
                    stroke.addCurve(
                        to: CGPoint(x: x1, y: yValues[i]),
                        control1: CGPoint(x: cx, y: yValues[i - 1]),
                        control2: CGPoint(x: cx, y: yValues[i])
                    )
                }

                // Fill beneath
                var fill = stroke
                fill.addLine(to: CGPoint(x: w, y: h))
                fill.addLine(to: CGPoint(x: 0, y: h))
                fill.closeSubpath()

                context.fill(
                    fill,
                    with: .color(layer.color.opacity(0.06 + Double(layerIdx) * 0.02))
                )

                context.stroke(
                    stroke,
                    with: .color(layer.color.opacity(0.3 + Double(layerIdx) * 0.08)),
                    lineWidth: 1.5
                )
            }
        }
    }
}

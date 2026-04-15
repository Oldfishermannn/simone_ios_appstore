import SwiftUI

struct AuroraView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let layers: [(color: Color, baseRatio: CGFloat, ampScale: CGFloat, strokeOpacity: Double, fillOpacity: Double)] = [
                (MorandiPalette.rose,  0.65, 0.25, 0.45, 0.0),
                (MorandiPalette.mauve, 0.72, 0.20, 0.40, 0.0),
                (MorandiPalette.sage,  0.79, 0.16, 0.35, 0.0),
                (MorandiPalette.blue,  0.86, 0.12, 0.30, 0.0),
            ]

            let points = 48

            for (layerIdx, layer) in layers.enumerated() {
                var yValues = [CGFloat]()
                for i in 0...points {
                    let t = Float(i) / Float(points)
                    let binF = t * Float(spectrumData.count - 1)
                    let binOffset = Float(layerIdx) * 3.0
                    let bin = Int(min(max(binF + binOffset, 0), Float(spectrumData.count - 1)))
                    let value = CGFloat(spectrumData[min(bin, spectrumData.count - 1)])

                    let baseY = h * layer.baseRatio
                    let amplitude = h * layer.ampScale * value
                    yValues.append(baseY - amplitude)
                }

                // Stroke path (cubic bezier)
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

                // Fill area beneath curve
                var fill = stroke
                fill.addLine(to: CGPoint(x: w, y: h))
                fill.addLine(to: CGPoint(x: 0, y: h))
                fill.closeSubpath()

                context.fill(
                    fill,
                    with: .color(layer.color.opacity(layer.fillOpacity))
                )

                let lineWidth = 2.0 - CGFloat(layerIdx) * 0.2
                context.stroke(
                    stroke,
                    with: .color(layer.color.opacity(layer.strokeOpacity)),
                    lineWidth: lineWidth
                )
            }
        }
    }
}

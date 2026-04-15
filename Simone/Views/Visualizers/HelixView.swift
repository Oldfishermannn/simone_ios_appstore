import SwiftUI

struct HelixView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cy = h / 2
            let nodeCount = density > 1 ? 48 : 30
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            // Two intertwined strands
            for strand in 0..<2 {
                let phaseOffset = Double(strand) * .pi
                let color = strand == 0 ? MorandiPalette.rose : MorandiPalette.blue

                var points = [CGPoint]()
                for i in 0..<nodeCount {
                    let t = CGFloat(i) / CGFloat(nodeCount - 1)
                    let bin = min(Int(Float(t) * Float(binCount - 1)), binCount - 1)
                    let value = CGFloat(spectrumData[bin])

                    let x = w * 0.05 + t * w * 0.9
                    let amplitude = h * 0.2 * (0.3 + value * 0.7)
                    let wave = sin(Double(t) * 4 * .pi + phaseOffset)
                    let y = cy + amplitude * CGFloat(wave)

                    points.append(CGPoint(x: x, y: y))
                }

                // Draw strand line
                var path = Path()
                path.move(to: points[0])
                for i in 1..<points.count {
                    let prev = points[i - 1]
                    let curr = points[i]
                    let cx = (prev.x + curr.x) / 2
                    path.addQuadCurve(to: curr, control: CGPoint(x: cx, y: prev.y))
                }
                context.stroke(path, with: .color(color.opacity(0.3)), lineWidth: 1.5)

                // Draw nodes
                for (i, pt) in points.enumerated() {
                    let bin = min(Int(Float(i) / Float(nodeCount - 1) * Float(binCount - 1)), binCount - 1)
                    let value = CGFloat(spectrumData[bin])
                    let dotSize = 2 + value * 5
                    let rect = CGRect(x: pt.x - dotSize / 2, y: pt.y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.2 + Double(value) * 0.5)))
                }
            }

            // Cross-links between strands
            let linkCount = density > 1 ? 16 : 10
            for i in 0..<linkCount {
                let t = CGFloat(i) / CGFloat(linkCount - 1)
                let bin = min(Int(Float(t) * Float(binCount - 1)), binCount - 1)
                let value = CGFloat(spectrumData[bin])

                let x = w * 0.05 + t * w * 0.9
                let amp = h * 0.2 * (0.3 + value * 0.7)
                let wave = sin(Double(t) * 4 * .pi)
                let y1 = cy + amp * CGFloat(wave)
                let y2 = cy - amp * CGFloat(wave)

                var link = Path()
                link.move(to: CGPoint(x: x, y: y1))
                link.addLine(to: CGPoint(x: x, y: y2))
                context.stroke(link, with: .color(MorandiPalette.mauve.opacity(0.08 + Double(value) * 0.12)), lineWidth: 0.8)
            }
        }
    }
}

import SwiftUI

struct FloraView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let flowerCount = density > 1 ? 7 : 5

            for f in 0..<flowerCount {
                let t = Float(f) / Float(flowerCount)
                let bin = min(Int(t * Float(binCount - 1)), binCount - 1)
                let value = CGFloat(spectrumData[bin])

                // Position flowers across the bottom
                let fx = w * (0.1 + CGFloat(t) * 0.8)
                let fy = h * 0.85

                // Stem
                let stemHeight = h * 0.15 + value * h * 0.35
                var stem = Path()
                stem.move(to: CGPoint(x: fx, y: fy))
                // Curved stem
                let sway = sin(Double(f) * 1.5) * 15 * Double(value)
                stem.addQuadCurve(
                    to: CGPoint(x: fx + sway, y: fy - stemHeight),
                    control: CGPoint(x: fx + sway * 0.7, y: fy - stemHeight * 0.5)
                )
                context.stroke(stem, with: .color(MorandiPalette.sage.opacity(0.2 + Double(value) * 0.3)), lineWidth: 1.5)

                // Flower head — petals radiating from top of stem
                let headX = fx + sway
                let headY = fy - stemHeight
                let petalCount = 5 + (f % 3)
                let petalLength = 6 + value * 18
                let color = MorandiPalette.color(at: f)

                for p in 0..<petalCount {
                    let angle = Double(p) / Double(petalCount) * 2 * .pi
                    let px = headX + petalLength * cos(angle)
                    let py = headY + petalLength * sin(angle) * 0.8

                    var petal = Path()
                    petal.move(to: CGPoint(x: headX, y: headY))
                    let cpDist = petalLength * 0.6
                    let cp1x = headX + cpDist * cos(angle + 0.3)
                    let cp1y = headY + cpDist * sin(angle + 0.3) * 0.8
                    let cp2x = headX + cpDist * cos(angle - 0.3)
                    let cp2y = headY + cpDist * sin(angle - 0.3) * 0.8
                    petal.addCurve(to: CGPoint(x: px, y: py),
                                   control1: CGPoint(x: cp1x, y: cp1y),
                                   control2: CGPoint(x: px, y: py))
                    petal.addCurve(to: CGPoint(x: headX, y: headY),
                                   control1: CGPoint(x: cp2x, y: cp2y),
                                   control2: CGPoint(x: headX, y: headY))

                    context.fill(petal, with: .color(color.opacity(0.08 + Double(value) * 0.2)))
                    context.stroke(petal, with: .color(color.opacity(0.2 + Double(value) * 0.4)), lineWidth: 1)
                }

                // Center dot
                let dotR = 3 + value * 4
                let dotRect = CGRect(x: headX - dotR, y: headY - dotR, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: dotRect), with: .color(MorandiPalette.sand.opacity(0.3 + Double(value) * 0.5)))
            }
        }
    }
}

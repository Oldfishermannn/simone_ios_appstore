import SwiftUI

struct VortexView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let armCount = density > 1 ? 5 : 3
            let dotsPerArm = density > 1 ? 40 : 24
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            for arm in 0..<armCount {
                let armOffset = Double(arm) / Double(armCount) * 2 * .pi

                for i in 0..<dotsPerArm {
                    let t = CGFloat(i) / CGFloat(dotsPerArm)
                    let bin = min(Int(Float(t) * Float(binCount - 1)), binCount - 1)
                    let value = CGFloat(spectrumData[bin])

                    let spiralAngle = armOffset + Double(t) * 3.0 * .pi
                    let baseR = t * min(w, h) * 0.42
                    let r = baseR + value * 15

                    let x = cx + r * cos(spiralAngle)
                    let y = cy + r * sin(spiralAngle) * 0.7

                    let dotSize = 1.5 + value * 4 + t * 2
                    let color = MorandiPalette.color(at: arm)
                    let opacity = 0.1 + Double(value) * 0.5 + Double(1 - t) * 0.1

                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                }
            }
        }
    }
}

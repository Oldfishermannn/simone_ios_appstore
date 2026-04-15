import SwiftUI

struct WaveRippleView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let ringCount = density > 1 ? 14 : 8
            let segments = density > 1 ? 80 : 48
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            for ring in 0..<ringCount {
                let t = CGFloat(ring) / CGFloat(ringCount)
                let baseR = min(w, h) * 0.05 * (1 + t * 4)
                let color = MorandiPalette.color(at: ring)

                var path = Path()
                for s in 0...segments {
                    let angle = CGFloat(s) / CGFloat(segments) * 2 * .pi
                    let binF = Float(s) / Float(segments) * Float(binCount - 1)
                    let bin = Int(min(binF, Float(binCount - 1)))
                    let value = CGFloat(spectrumData[bin])

                    let wave = sin(angle * 3 + t * .pi) * value * 12
                    let r = baseR + wave

                    let x = cx + r * cos(angle)
                    let y = cy + r * sin(angle)

                    if s == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()

                let opacity = 0.12 + Double(1 - t) * 0.2
                context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1.2)
            }
        }
    }
}

import SwiftUI

struct SilkWaveView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let colors: [Color] = [
                MorandiPalette.rose, MorandiPalette.mauve, MorandiPalette.sage,
                MorandiPalette.blue, MorandiPalette.sand,
            ]

            for wave in 0..<5 {
                var path = Path()
                let baseY = h * (0.3 + CGFloat(wave) * 0.12)
                let phaseOffset = Float(wave) * 0.2

                let segments = 48
                for i in 0...segments {
                    let x = w * CGFloat(i) / CGFloat(segments)
                    let bin = min(i * spectrumData.count / max(segments, 1), spectrumData.count - 1)
                    let value = spectrumData[max(0, bin)] + phaseOffset * 0.3
                    let amplitude = h * 0.15 * CGFloat(value)
                    let y = baseY - amplitude

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let prevX = w * CGFloat(i - 1) / CGFloat(segments)
                        path.addQuadCurve(
                            to: CGPoint(x: x, y: y),
                            control: CGPoint(x: (prevX + x) / 2, y: y + 5)
                        )
                    }
                }

                context.stroke(
                    path,
                    with: .color(colors[wave].opacity(0.5)),
                    lineWidth: 2
                )
            }
        }
    }
}

import SwiftUI

struct WaveformView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let centerY = h * 0.5

            let colors: [Color] = [
                MorandiPalette.rose,
                MorandiPalette.mauve,
                MorandiPalette.sage,
            ]

            let segments = 80

            for (lineIdx, color) in colors.enumerated() {
                var path = Path()
                let phaseOffset = Float(lineIdx) * 0.15
                let verticalShift = CGFloat(lineIdx - 1) * h * 0.08

                for i in 0...segments {
                    let t = Float(i) / Float(segments)
                    let bin = min(Int(t * Float(spectrumData.count - 1)), spectrumData.count - 1)
                    let value = spectrumData[max(0, bin)] + phaseOffset * 0.2

                    // Oscilloscope-style: mirror above and below center
                    let amplitude = h * 0.22 * CGFloat(value)
                    let sign: CGFloat = (i % 2 == 0) ? -1 : 1
                    let x = w * CGFloat(i) / CGFloat(segments)
                    let y = centerY + verticalShift + sign * amplitude

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let prevX = w * CGFloat(i - 1) / CGFloat(segments)
                        path.addQuadCurve(
                            to: CGPoint(x: x, y: y),
                            control: CGPoint(x: (prevX + x) / 2, y: centerY + verticalShift)
                        )
                    }
                }

                context.stroke(
                    path,
                    with: .color(color.opacity(0.4 - Double(lineIdx) * 0.05)),
                    lineWidth: 1.8
                )
            }

            // Center axis line
            var axis = Path()
            axis.move(to: CGPoint(x: w * 0.1, y: centerY))
            axis.addLine(to: CGPoint(x: w * 0.9, y: centerY))
            context.stroke(
                axis,
                with: .color(.white.opacity(0.06)),
                lineWidth: 0.5
            )
        }
    }
}

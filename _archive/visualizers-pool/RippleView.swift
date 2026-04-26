import SwiftUI

struct RippleView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let ringCount = 8
            let binCount = spectrumData.count

            guard binCount > 0 else { return }

            let maxRadius = min(w, h) * 0.45

            for i in 0..<ringCount {
                let bin = min(i * binCount / ringCount, binCount - 1)
                let value = CGFloat(spectrumData[bin])

                // Each ring expands from center, inner rings = low freq, outer = high freq
                let baseRadius = maxRadius * CGFloat(i + 1) / CGFloat(ringCount)
                let amplitude = value * 12
                let radius = baseRadius + amplitude

                let color = MorandiPalette.color(at: i)
                let opacity = 0.08 + Double(value) * 0.25

                // Draw ring
                var ring = Path()
                ring.addEllipse(in: CGRect(
                    x: cx - radius,
                    y: cy - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(
                    ring,
                    with: .color(color.opacity(opacity)),
                    lineWidth: 1.5 + value * 2
                )

                // Inner glow fill
                context.fill(
                    ring,
                    with: .color(color.opacity(Double(value) * 0.03))
                )
            }

            // Center dot
            let centerValue = CGFloat(spectrumData[0])
            let dotSize = 3 + centerValue * 6
            let dotRect = CGRect(
                x: cx - dotSize,
                y: cy - dotSize,
                width: dotSize * 2,
                height: dotSize * 2
            )
            context.fill(
                Path(ellipseIn: dotRect),
                with: .color(MorandiPalette.rose.opacity(0.4 + Double(centerValue) * 0.4))
            )
        }
    }
}

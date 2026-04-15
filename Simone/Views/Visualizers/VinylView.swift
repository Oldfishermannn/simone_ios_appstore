import SwiftUI

struct VinylView: View {
    let spectrumData: [Float]
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Vinyl disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.white.opacity(0.04)],
                        center: .center, startRadius: 15, endRadius: 70
                    )
                )
                .frame(width: 130, height: 130)
                .overlay(
                    // Groove rings
                    ZStack {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                                .frame(width: CGFloat(40 + i * 18), height: CGFloat(40 + i * 18))
                        }
                    }
                )
                .rotationEffect(.degrees(rotation))

            // Center label
            Circle()
                .fill(
                    LinearGradient(
                        colors: [MorandiPalette.rose.opacity(0.4), MorandiPalette.mauve.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )

            // Spectrum bars radiating outward
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let barCount = 36
                let innerRadius: CGFloat = 68
                let maxBarLength: CGFloat = 45

                for i in 0..<barCount {
                    let angle = (Double(i) / Double(barCount)) * 2 * .pi - .pi / 2
                    let bin = min(i * spectrumData.count / barCount, spectrumData.count - 1)
                    let value = CGFloat(spectrumData[max(0, bin)])
                    let barLength = max(3, value * maxBarLength)

                    let x1 = center.x + innerRadius * cos(angle)
                    let y1 = center.y + innerRadius * sin(angle)
                    let x2 = center.x + (innerRadius + barLength) * cos(angle)
                    let y2 = center.y + (innerRadius + barLength) * sin(angle)

                    var barPath = Path()
                    barPath.move(to: CGPoint(x: x1, y: y1))
                    barPath.addLine(to: CGPoint(x: x2, y: y2))

                    let color = MorandiPalette.color(at: i)
                    context.stroke(
                        barPath,
                        with: .color(color.opacity(0.4 + Double(value) * 0.5)),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )

                    // Glow dot at tip
                    if value > 0.3 {
                        let dotR = 1.5 + value * 2
                        let dotRect = CGRect(
                            x: x2 - dotR, y: y2 - dotR,
                            width: dotR * 2, height: dotR * 2
                        )
                        context.fill(
                            Path(ellipseIn: dotRect),
                            with: .color(color.opacity(Double(value) * 0.6))
                        )
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

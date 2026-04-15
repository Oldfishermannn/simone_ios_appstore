import SwiftUI

struct FountainView: View {
    let spectrumData: [Float]
    private let barCount = 28

    var body: some View {
        VStack(spacing: 0) {
            // Bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { i in
                    let bin = min(i * (spectrumData.count / barCount), spectrumData.count - 1)
                    let value = CGFloat(spectrumData[bin])
                    let height = max(6, value * 120)
                    let color = MorandiPalette.color(at: i)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.85), color.opacity(0.25)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 5, height: height)
                        .shadow(color: color.opacity(0.3), radius: 3, y: -2)
                }
            }
            .frame(height: 130, alignment: .bottom)

            // Pool line
            LinearGradient(
                colors: [.clear, MorandiPalette.rose.opacity(0.25), MorandiPalette.mauve.opacity(0.25), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)

            // Reflection — softer and faded
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { i in
                    let bin = min(i * (spectrumData.count / barCount), spectrumData.count - 1)
                    let value = CGFloat(spectrumData[bin])
                    let height = max(3, value * 40)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(MorandiPalette.color(at: i).opacity(0.6))
                        .frame(width: 5, height: height)
                }
            }
            .frame(height: 24, alignment: .top)
            .scaleEffect(y: -1)
            .opacity(0.08)
            .mask(
                LinearGradient(colors: [.clear, .white], startPoint: .bottom, endPoint: .top)
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 40)
    }
}

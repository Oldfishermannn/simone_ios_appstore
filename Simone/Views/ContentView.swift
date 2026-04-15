import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var currentPage: Int = 1  // 0=Immersive, 1=Main, 2=Details

    var body: some View {
        GeometryReader { geo in
            let specSize = min(geo.size.width, 400) - 40

            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [MorandiPalette.rose.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()

                VerticalPageView(pageCount: 3, currentPage: $currentPage) { index in
                    Group {
                        switch index {
                        case 0:
                            ImmersiveView(state: state)
                        case 2:
                            DetailsView(state: state)
                        default:
                            self.mainPage(specSize: specSize)
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func mainPage(specSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)

            // Spectrum
            SpectrumCarouselView(state: state)
                .frame(width: specSize, height: specSize)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            Spacer().frame(height: 96)

            // Style name above controls
            Text(state.selectedStyle?.name ?? " ")
                .font(.system(size: 18, weight: .regular))
                .tracking(0.5)
                .foregroundStyle(Color(white: 0.65))
                .lineLimit(1)

            Spacer().frame(height: 24)

            // Transport controls
            PlayControlView(state: state)

            Spacer()
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

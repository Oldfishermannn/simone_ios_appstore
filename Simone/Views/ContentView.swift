import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var currentPage: Int = 1  // Start on Main

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

                TabView(selection: $currentPage) {
                    // Page 0: Immersive (swipe up from main)
                    ImmersiveView(state: state)
                        .rotationEffect(.degrees(-90))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .tag(0)

                    // Page 1: Main (default)
                    mainPage(specSize: specSize)
                        .rotationEffect(.degrees(-90))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .tag(1)

                    // Page 2: Details (swipe down from main)
                    DetailsView(state: state)
                        .rotationEffect(.degrees(-90))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .rotationEffect(.degrees(90))
                .frame(width: geo.size.height, height: geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height)
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func mainPage(specSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            // Spectrum — keep exactly as before
            SpectrumCarouselView(state: state)
                .frame(width: specSize, height: specSize)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            Spacer().frame(height: 14)

            // Style name
            Text(state.selectedStyle?.name ?? "Simone")
                .font(.system(size: 20, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color(white: 0.88))
                .lineLimit(1)

            Spacer()

            // Transport controls at bottom
            PlayControlView(state: state)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

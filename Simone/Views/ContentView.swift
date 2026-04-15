import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var currentPage: Int = 1  // 0=Immersive, 1=Main, 2=Details
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let specSize = min(geo.size.width, 400) - 40
            let pageHeight = geo.size.height

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

                VStack(spacing: 0) {
                    // Page 0: Immersive
                    ImmersiveView(state: state)
                        .frame(width: geo.size.width, height: pageHeight)

                    // Page 1: Main
                    mainPage(specSize: specSize, geo: geo)
                        .frame(width: geo.size.width, height: pageHeight)

                    // Page 2: Details
                    DetailsView(state: state)
                        .frame(width: geo.size.width, height: pageHeight)
                }
                .offset(y: -CGFloat(currentPage) * pageHeight + dragOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.86), value: currentPage)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let threshold: CGFloat = pageHeight * 0.15
                            let velocity = value.predictedEndTranslation.height - value.translation.height

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                                if value.translation.height < -threshold || velocity < -200 {
                                    // Swiped up → next page
                                    currentPage = min(currentPage + 1, 2)
                                } else if value.translation.height > threshold || velocity > 200 {
                                    // Swiped down → previous page
                                    currentPage = max(currentPage - 1, 0)
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func mainPage(specSize: CGFloat, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: geo.safeAreaInsets.top + 28)

            // Spectrum
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
                .padding(.bottom, geo.safeAreaInsets.bottom + 20)
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

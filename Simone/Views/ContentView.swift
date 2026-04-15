import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var expanded = true

    var body: some View {
        GeometryReader { geo in
            let specSize = expanded ? min(geo.size.width, 400) - 40 : min(geo.size.width, 400) - 80

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

                if expanded {
                    // Expanded: full player UI
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 28)

                            // Spectrum — tap to collapse
                            SpectrumCarouselView(state: state)
                                .frame(width: specSize, height: specSize)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        expanded = false
                                    }
                                }

                            Spacer().frame(height: 14)

                            // Style name
                            Text(state.selectedStyle?.name ?? "Simone")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(0.3)
                                .foregroundStyle(Color(white: 0.88))
                                .lineLimit(1)

                            Spacer().frame(height: 14)

                            // Transport controls
                            PlayControlView(state: state)

                            Spacer().frame(height: 12)

                            // Details
                            ExpandableCardView(state: state)

                            Spacer().frame(height: 8)
                        }
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Collapsed: spectrum centered, tap to expand
                    SpectrumCarouselView(state: state, showDots: false)
                        .frame(width: specSize, height: specSize)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expanded = true
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

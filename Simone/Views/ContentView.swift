import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var showSettings = true

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, 400)

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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 28)

                        // Cover art — spectrum visualizer
                        SpectrumCarouselView(state: state)
                            .frame(width: size - 40, height: size - 40)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

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

                        Spacer().frame(height: 8)

                        // Toggle arrow
                        Button {
                            showSettings.toggle()
                        } label: {
                            Image(systemName: showSettings ? "chevron.compact.down" : "chevron.compact.up")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(width: 44, height: 28)
                        }
                        .buttonStyle(.plain)

                        // Settings panel — only this part animates
                        if showSettings {
                            ExpandableCardView(state: state)
                                .transition(.opacity)
                        }

                        Spacer().frame(height: 8)
                    }
                    .frame(maxWidth: 400)
                    .frame(maxWidth: .infinity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showSettings)
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

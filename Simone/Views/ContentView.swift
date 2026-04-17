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

                VerticalPageView(pageCount: 4, currentPage: $currentPage) { index in
                    Group {
                        switch index {
                        case 0:
                            ImmersiveView(state: state)
                        case 2:
                            DetailsView(state: state)
                        case 3:
                            SettingsView(state: state)
                        default:
                            MainPageView(state: state, specSize: specSize)
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// Main page is its own View struct (not a @ViewBuilder on ContentView) so
/// @State survives VerticalPageView's AnyView-over-UIHostingController plumbing.
/// When the outer shell re-renders, the struct identity keeps @State + onChange
/// + withAnimation tied to a stable view subtree — matching how ImmersiveView
/// already behaves.
struct MainPageView: View {
    @Bindable var state: AppState
    let specSize: CGFloat

    @State private var nameSlideOffset: CGFloat = 0
    @State private var nameOpacity: Double = 1.0
    @State private var channelSlideOffset: CGFloat = 0
    @State private var channelOpacity: Double = 1.0
    // Buffered display values — slide the OLD name out before the NEW value
    // becomes visible (state.* updates the instant the swipe lands).
    @State private var displayChannel: Channel = .category(.lofi)
    @State private var displayStyleName: String = " "

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)

            // Spectrum
            SpectrumCarouselView(state: state)
                .frame(width: specSize, height: specSize)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            Spacer().frame(height: 60)

            // Channel badge — v1.1.1: binds to displayChannel so Favorites
            // shows "FAVORITES" and the slide-out phase renders the OLD name.
            Text(displayChannel.displayName.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(channelBadgeTint.opacity(0.5))
                .offset(x: channelSlideOffset)
                .opacity(channelOpacity)

            Spacer().frame(height: 8)

            // Style name with manual slide animation (◁▷ press AND channel swipe)
            Text(displayStyleName)
                .font(.system(size: 20, weight: .regular))
                .tracking(0.5)
                .foregroundStyle(Color(white: 0.65))
                .lineLimit(1)
                .offset(x: nameSlideOffset)
                .opacity(nameOpacity)

            Spacer().frame(height: 28)

            // Transport controls
            HStack(spacing: 40) {
                Button {
                    switchStyle(forward: false) { state.previousStyle() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button {
                    state.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )

                        Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.audioEngine.isPlaying)

                Button {
                    switchStyle(forward: true) { state.nextStyle() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .frame(width: specSize)

            Spacer()
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .onAppear {
            displayChannel = state.currentChannel
            displayStyleName = state.selectedStyle?.name ?? " "
        }
        .onChange(of: state.currentChannel) { old, new in
            slideOnChannelChange(from: old, to: new)
        }
        .onChange(of: state.selectedStyle?.id) { _, _ in
            // Direct preset tap (DetailsView) — sync buffered name when idle.
            if nameSlideOffset == 0 && nameOpacity == 1.0 {
                displayStyleName = state.selectedStyle?.name ?? " "
            }
        }
    }

    private var channelBadgeTint: Color {
        switch displayChannel {
        case .favorites:       return MorandiPalette.rose
        case .category(let c): return c.color
        }
    }

    private func switchStyle(forward: Bool, action: @escaping () -> Void) {
        let slideOut: CGFloat = forward ? -80 : 80
        let slideIn: CGFloat = forward ? 80 : -80

        withAnimation(.easeIn(duration: 0.12)) {
            nameSlideOffset = slideOut
            nameOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
            displayStyleName = state.selectedStyle?.name ?? " "
            nameSlideOffset = slideIn
            withAnimation(.easeOut(duration: 0.18)) {
                nameSlideOffset = 0
                nameOpacity = 1
            }
        }
    }

    private func slideOnChannelChange(from old: Channel, to new: Channel) {
        let channels = Channel.all
        let oldIdx = channels.firstIndex(of: old) ?? 0
        let newIdx = channels.firstIndex(of: new) ?? 0
        let forward = newIdx >= oldIdx

        let slideOut: CGFloat = forward ? -80 : 80
        let slideIn: CGFloat = forward ? 80 : -80

        withAnimation(.easeIn(duration: 0.12)) {
            channelSlideOffset = slideOut
            channelOpacity = 0
            nameSlideOffset = slideOut
            nameOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            displayChannel = new
            displayStyleName = state.selectedStyle?.name ?? " "
            channelSlideOffset = slideIn
            nameSlideOffset = slideIn
            withAnimation(.easeOut(duration: 0.18)) {
                channelSlideOffset = 0
                channelOpacity = 1
                nameSlideOffset = 0
                nameOpacity = 1
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

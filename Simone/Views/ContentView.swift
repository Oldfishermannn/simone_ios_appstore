import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var currentPage: Int = 1  // 0=Immersive, 1=Main, 2=Details
    @State private var nameSlideOffset: CGFloat = 0
    @State private var nameOpacity: Double = 1.0
    @State private var channelSlideOffset: CGFloat = 0
    @State private var channelOpacity: Double = 1.0
    // Buffered display values — let us slide the OLD name out before the NEW
    // value becomes visible. state.* updates the instant channel swipe lands,
    // so reading it directly would skip the slide-out phase.
    @State private var displayChannel: Channel = .category(.lofi)
    @State private var displayStyleName: String = " "

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

            Spacer().frame(height: 60)

            // Channel badge — v1.1.1: binds to displayChannel (buffered) so
            // Favorites shows "FAVORITES" and the slide-out phase renders the
            // OLD channel name before the swap commits.
            Text(displayChannel.displayName.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(channelBadgeTint.opacity(0.5))
                .offset(x: channelSlideOffset)
                .opacity(channelOpacity)

            Spacer().frame(height: 8)

            // Style name with manual slide animation (triggers on ◁▷ press
            // AND on channel swipe — both drive the same buffered value).
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
                // Previous
                Button {
                    switchStyle(forward: false) { state.previousStyle() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                // Play / Pause
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

                // Next
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
        // Reads displayChannel (not state.currentChannel) so the tint slides
        // out with the OLD badge instead of snapping to the new color on swipe.
        switch displayChannel {
        case .favorites:       return MorandiPalette.rose
        case .category(let c): return c.color
        }
    }

    // Two-phase slide animation: slide out → swap data → slide in
    private func switchStyle(forward: Bool, action: @escaping () -> Void) {
        let slideOut: CGFloat = forward ? -80 : 80
        let slideIn: CGFloat = forward ? 80 : -80

        // Phase 1: slide current name out
        withAnimation(.easeIn(duration: 0.12)) {
            nameSlideOffset = slideOut
            nameOpacity = 0
        }

        // Phase 2: swap data, then slide new name in
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

    /// Channel swipe slides badge + style name together, same direction as the
    /// carousel's horizontal scroll (forward = next channel, slides leftward out).
    private func slideOnChannelChange(from old: Channel, to new: Channel) {
        let channels = Channel.all
        let oldIdx = channels.firstIndex(of: old) ?? 0
        let newIdx = channels.firstIndex(of: new) ?? 0
        let forward = newIdx >= oldIdx

        let slideOut: CGFloat = forward ? -80 : 80
        let slideIn: CGFloat = forward ? 80 : -80

        // Phase 1: slide both texts out (old values still rendered via buffered display vars)
        withAnimation(.easeIn(duration: 0.12)) {
            channelSlideOffset = slideOut
            channelOpacity = 0
            nameSlideOffset = slideOut
            nameOpacity = 0
        }

        // Phase 2: commit new values, then slide in from the opposite edge
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

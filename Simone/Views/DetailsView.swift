import SwiftUI

struct DetailsView: View {
    @Bindable var state: AppState

    private let channels = Channel.all

    /// Browsing cursor — moves freely with horizontal swipe, NOT tied to playback.
    @State private var browseChannel: Channel = .category(.lofi)
    /// Dial scroll cursor. Separate from browseChannel so the dial can be
    /// free-scrubbed without forcing the bottom TabView to chase every pixel.
    @State private var dialIdx: Int? = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)

            MiniPlayerView(state: state)
                .padding(.horizontal, 16)

            Spacer().frame(height: 14)

            channelDial

            Spacer().frame(height: 6)

            pillIndicator

            Spacer().frame(height: 10)

            // Bottom: magnetic TabView — full-page pagination stays as before.
            TabView(selection: $browseChannel) {
                ForEach(channels, id: \.self) { channel in
                    ChannelPageView(
                        state: state,
                        channel: channel,
                        onSelect: { style in
                            state.switchToChannel(channel)
                            state.selectStyle(style)
                        }
                    )
                    .tag(channel)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .onAppear {
            let idx = channels.firstIndex(of: state.currentChannel) ?? 0
            browseChannel = state.currentChannel
            dialIdx = idx
        }
        .onChange(of: dialIdx) { _, newIdx in
            // Dial scrub settled on a new item — sync bottom TabView.
            if let idx = newIdx, idx >= 0, idx < channels.count,
               browseChannel != channels[idx] {
                browseChannel = channels[idx]
            }
        }
        .onChange(of: browseChannel) { _, new in
            // TabView swipe (or external change) — scroll dial to match.
            let idx = channels.firstIndex(of: new) ?? 0
            if dialIdx != idx {
                dialIdx = idx
            }
        }
        .onChange(of: state.currentChannel) { _, new in
            if browseChannel != new { browseChannel = new }
        }
    }

    // MARK: - Dial

    /// Top dial — free-scroll horizontal picker. No scrollTargetBehavior, so
    /// the user can flick and land wherever. scrollPosition(id:, anchor:.center)
    /// tracks whichever item is centered and pushes that into dialIdx.
    /// Cells are content-hugging (uniform font, variable width per name) so
    /// long names like "ELECTRONIC" / "DREAMSCAPE" never truncate.
    private var channelDial: some View {
        GeometryReader { geo in
            let sideInset = geo.size.width / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Leading inset so the first cell can be centered.
                    Color.clear.frame(width: sideInset)

                    ForEach(Array(channels.enumerated()), id: \.element) { index, channel in
                        dialCell(channel: channel, index: index)
                            .id(index)
                    }

                    // Trailing inset so the last cell can be centered.
                    Color.clear.frame(width: sideInset)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $dialIdx, anchor: .center)
        }
        .frame(height: 36)
    }

    @ViewBuilder
    private func dialCell(channel: Channel, index: Int) -> some View {
        let currentIdx = dialIdx ?? 0
        let distance = abs(index - currentIdx)
        let isCurrent = distance == 0

        // Uniform font size / weight — layout stays stable as dial scrolls.
        // Emphasis is done via color + opacity, not size jumps.
        let opacity: Double = isCurrent
            ? 0.90
            : (distance == 1 ? 0.38 : (distance == 2 ? 0.22 : 0.12))
        // v1.2.1: non-current dial cells use cool-axis primary text tone
        // (oklch 0.94/0.012/250) instead of pure white — cleaner on cold bg.
        let tint: Color = isCurrent ? headerTint : FogTokens.textPrimary

        Text(channel.displayName.uppercased())
            .font(FogTheme.mono(12, weight: .regular))
            .tracking(FogTheme.trackLabel)
            .foregroundStyle(tint.opacity(opacity))
            .lineLimit(1)
            .padding(.horizontal, 18)
    }

    private var pillIndicator: some View {
        let selectedIndex = channels.firstIndex(of: browseChannel) ?? 0
        return HStack(spacing: 5) {
            ForEach(Array(channels.enumerated()), id: \.element) { index, _ in
                Circle()
                    // v1.2.1: pill dots use cool hairline tone instead of
                    // warm-tinted .white.opacity(0.15) — subtle but audible.
                    .fill(index == selectedIndex
                          ? headerTint
                          : FogTokens.textTertiary.opacity(0.35))
                    .frame(width: index == selectedIndex ? 6 : 4,
                           height: index == selectedIndex ? 6 : 4)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
    }

    private var headerTint: Color {
        switch browseChannel {
        // v1.2.1: favorites previously tinted Morandi rose — too warm against
        // the cool Fog base. Brass is the one allowed warm accent; keeps the
        // "this is yours" heat without dropping into dusk territory.
        case .favorites:       return FogTokens.accentBrass
        case .category(let c): return c.color
        }
    }
}

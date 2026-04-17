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
    private var channelDial: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(channels.enumerated()), id: \.element) { index, channel in
                        dialCell(channel: channel, index: index, containerWidth: geo.size.width)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $dialIdx, anchor: .center)
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func dialCell(channel: Channel, index: Int, containerWidth: CGFloat) -> some View {
        let currentIdx = dialIdx ?? 0
        let distance = abs(index - currentIdx)
        let isCurrent = distance == 0

        let fontSize: CGFloat = isCurrent ? 13 : (distance == 1 ? 10 : 9)
        let tracking: CGFloat = isCurrent ? 1.8 : 1.2
        let opacity: Double = isCurrent ? 0.85 : (distance == 1 ? 0.30 : 0.15)
        let weight: Font.Weight = isCurrent ? .semibold : .regular
        let tint: Color = isCurrent ? headerTint : .white

        // Fixed cell width = containerWidth / 5 → 5 cells visible at once.
        let cellWidth = containerWidth / 5

        Text(channel.displayName.uppercased())
            .font(.system(size: fontSize, weight: weight))
            .tracking(tracking)
            .foregroundStyle(tint.opacity(opacity))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: cellWidth)
    }

    private var pillIndicator: some View {
        let selectedIndex = channels.firstIndex(of: browseChannel) ?? 0
        return HStack(spacing: 5) {
            ForEach(Array(channels.enumerated()), id: \.element) { index, _ in
                Circle()
                    .fill(index == selectedIndex
                          ? headerTint
                          : Color.white.opacity(0.15))
                    .frame(width: index == selectedIndex ? 6 : 4,
                           height: index == selectedIndex ? 6 : 4)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
    }

    private var headerTint: Color {
        switch browseChannel {
        case .favorites:       return MorandiPalette.rose
        case .category(let c): return c.color
        }
    }
}

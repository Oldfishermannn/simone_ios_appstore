import SwiftUI

struct DetailsView: View {
    @Bindable var state: AppState

    private let channels = Channel.all

    /// Browsing cursor — moves freely with horizontal swipe, NOT tied to playback.
    /// Initialized to the currently-playing channel so entering the details page
    /// lands on the right tab; subsequent main-page channel changes push this
    /// cursor forward too, but swiping details only mutates browseChannel — it
    /// never touches state.currentChannel, so audio keeps playing untouched.
    @State private var browseChannel: Channel = .category(.lofi)
    @State private var scrollIdx: Int? = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)

            MiniPlayerView(state: state)
                .padding(.horizontal, 16)

            Spacer().frame(height: 12)

            channelHeader
                .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            // Free-scroll ScrollView (no scrollTargetBehavior) — lands wherever
            // the user's finger releases, no magnetic page snap.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(channels.enumerated()), id: \.element) { index, channel in
                        ChannelPageView(
                            state: state,
                            channel: channel,
                            onSelect: { style in
                                // Tapping a preset is the explicit "change station"
                                // action: align channel, then play the style.
                                state.switchToChannel(channel)
                                state.selectStyle(style)
                            }
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollIdx, anchor: .center)
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .onAppear {
            let idx = channels.firstIndex(of: state.currentChannel) ?? 0
            browseChannel = state.currentChannel
            scrollIdx = idx
        }
        .onChange(of: scrollIdx) { _, newIdx in
            if let idx = newIdx, idx >= 0, idx < channels.count {
                browseChannel = channels[idx]
            }
        }
        .onChange(of: state.currentChannel) { _, new in
            // Main-page channel switch should pull the details cursor along.
            let idx = channels.firstIndex(of: new) ?? 0
            if scrollIdx != idx {
                scrollIdx = idx
            }
        }
    }

    // MARK: - Header

    private var channelHeader: some View {
        let selectedIndex = channels.firstIndex(of: browseChannel) ?? 0
        let prev2 = selectedIndex >= 2 ? channels[selectedIndex - 2] : nil
        let prev1 = selectedIndex >= 1 ? channels[selectedIndex - 1] : nil
        let next1 = selectedIndex < channels.count - 1 ? channels[selectedIndex + 1] : nil
        let next2 = selectedIndex < channels.count - 2 ? channels[selectedIndex + 2] : nil

        return VStack(spacing: 10) {
            // Five-up header: prev2 · prev · CURRENT · next · next2 — gives the
            // user two steps of peripheral context so they can orient faster.
            HStack(spacing: 0) {
                headerSideLabel(prev2, tier: .far)
                headerSideLabel(prev1, tier: .near)

                Text(browseChannel.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(headerTint.opacity(0.75))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                headerSideLabel(next1, tier: .near)
                headerSideLabel(next2, tier: .far)
            }

            HStack(spacing: 5) {
                ForEach(Array(channels.enumerated()), id: \.element) { index, _ in
                    Circle()
                        .fill(index == selectedIndex
                              ? headerTint
                              : Color.white.opacity(0.15))
                        .frame(width: index == selectedIndex ? 6 : 4,
                               height: index == selectedIndex ? 6 : 4)
                }
            }
        }
    }

    private enum SideTier { case near, far }

    @ViewBuilder
    private func headerSideLabel(_ channel: Channel?, tier: SideTier) -> some View {
        let text = channel?.displayName.uppercased() ?? ""
        let size: CGFloat = tier == .near ? 9 : 8
        let opacity: Double = tier == .near ? 0.22 : 0.10
        Text(text)
            .font(.system(size: size, weight: .regular))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(opacity))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
    }

    private var headerTint: Color {
        switch browseChannel {
        case .favorites:       return MorandiPalette.rose
        case .category(let c): return c.color
        }
    }
}

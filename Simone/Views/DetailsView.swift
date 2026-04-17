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

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)

            MiniPlayerView(state: state)
                .padding(.horizontal, 16)

            Spacer().frame(height: 12)

            channelHeader
                .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            TabView(selection: $browseChannel) {
                ForEach(channels, id: \.self) { channel in
                    ChannelPageView(
                        state: state,
                        channel: channel,
                        onSelect: { style in
                            // Tapping a preset is the explicit "change station" action:
                            // align channel, then play the style.
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
            browseChannel = state.currentChannel
        }
        .onChange(of: state.currentChannel) { _, new in
            // Main-page channel switch should pull the details cursor along.
            if browseChannel != new {
                browseChannel = new
            }
        }
    }

    // MARK: - Header

    private var channelHeader: some View {
        let selectedIndex = channels.firstIndex(of: browseChannel) ?? 0
        return VStack(spacing: 10) {
            Text(browseChannel.displayName.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(headerTint.opacity(0.6))

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
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
        }
    }

    private var headerTint: Color {
        switch browseChannel {
        case .favorites:       return MorandiPalette.rose
        case .category(let c): return c.color
        }
    }
}

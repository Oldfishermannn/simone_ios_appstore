import SwiftUI

struct DetailsView: View {
    @Bindable var state: AppState

    private let channels = Channel.all

    private var channelBinding: Binding<Channel> {
        Binding(
            get: { state.currentChannel },
            set: { state.switchToChannel($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)

            MiniPlayerView(state: state)
                .padding(.horizontal, 16)

            Spacer().frame(height: 12)

            // Channel label + pill indicator
            channelHeader
                .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            TabView(selection: channelBinding) {
                ForEach(channels, id: \.self) { channel in
                    ChannelPageView(state: state, channel: channel)
                        .tag(channel)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header

    private var channelHeader: some View {
        let selectedIndex = channels.firstIndex(of: state.currentChannel) ?? 0
        return VStack(spacing: 10) {
            Text(state.currentChannel.displayName.uppercased())
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
        switch state.currentChannel {
        case .favorites:       return MorandiPalette.rose
        case .category(let c): return c.color
        }
    }
}

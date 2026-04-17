import SwiftUI

/// Single page of DetailsView — renders the styles for one channel.
/// No vertical ScrollView: horizontal swipe is the only interaction axis.
/// Tapping a preset routes through onSelect, which wires the caller's
/// switchToChannel + selectStyle so the playing channel stays in sync.
struct ChannelPageView: View {
    @Bindable var state: AppState
    let channel: Channel
    let onSelect: (MoodStyle) -> Void

    var body: some View {
        VStack(spacing: 4) {
            switch channel {
            case .favorites:
                favoritesContent
            case .category(let category):
                categoryContent(category)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if state.pinnedStyles.isEmpty {
            VStack(spacing: 12) {
                Spacer().frame(height: 40)
                Image(systemName: "heart")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.15))
                Text("Tap ♡ on any style to save it here")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.2))
                Spacer()
            }
        } else {
            ForEach(state.pinnedStyles) { style in
                StyleRowView(
                    style: style,
                    isPlaying: state.selectedStyle?.id == style.id,
                    isFavorite: true,
                    showFavoriteButton: true,
                    onTap: { onSelect(style) },
                    onToggleFavorite: { state.unpinStyle(style) }
                )
            }
        }
    }

    @ViewBuilder
    private func categoryContent(_ category: StyleCategory) -> some View {
        let styles = MoodStyle.presets(for: category)
        ForEach(styles) { style in
            StyleRowView(
                style: style,
                isPlaying: state.selectedStyle?.id == style.id,
                isFavorite: state.isPinned(style),
                showFavoriteButton: true,
                onTap: { onSelect(style) },
                onToggleFavorite: {
                    if state.isPinned(style) {
                        state.unpinStyle(style)
                    } else {
                        state.pinStyle(style)
                    }
                }
            )
        }
    }
}

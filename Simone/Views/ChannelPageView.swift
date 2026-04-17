import SwiftUI

/// Single page of DetailsView — renders the styles for one channel.
/// Favorites page shows the pinned list with an empty-state hint;
/// category pages render the preset pool for that category.
struct ChannelPageView: View {
    @Bindable var state: AppState
    let channel: Channel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                switch channel {
                case .favorites:
                    favoritesContent
                case .category(let category):
                    categoryContent(category)
                }
            }
            .padding(.horizontal, 16)
        }
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
                    onTap: { state.selectStyle(style) },
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
                onTap: {
                    state.currentCategory = category
                    state.selectStyle(style)
                },
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

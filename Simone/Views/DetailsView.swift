import SwiftUI

struct DetailsView: View {
    @Bindable var state: AppState
    @State private var selectedTab: ChannelTab = .favorites

    enum ChannelTab: Hashable {
        case favorites
        case category(StyleCategory)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)

            // Mini Player
            MiniPlayerView(state: state)
                .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            // Tab Bar
            tabBar
                .padding(.horizontal, 16)

            Spacer().frame(height: 12)

            // Style List
            styleList
                .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Favorites tab
                tabButton(
                    label: "♡ Favorites",
                    isSelected: selectedTab == .favorites,
                    color: MorandiPalette.rose
                ) {
                    selectedTab = .favorites
                }

                // Category tabs
                ForEach(StyleCategory.allCases, id: \.rawValue) { category in
                    tabButton(
                        label: category.displayName,
                        isSelected: selectedTab == .category(category),
                        color: category.color
                    ) {
                        selectedTab = .category(category)
                    }
                }
            }
        }
    }

    private func tabButton(label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? color.opacity(0.2)
                        : Color.white.opacity(0.04)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(
                    isSelected
                        ? color
                        : .white.opacity(0.4)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style List

    private var styleList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                switch selectedTab {
                case .favorites:
                    favoritesContent
                case .category(let category):
                    categoryContent(category)
                }
            }
        }
    }

    // MARK: - Favorites Content

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

    // MARK: - Category Content

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

import SwiftUI

/// v1.3 · Details as bottom sheet content. 展示当前频道 style 列表，
/// 长按 ≡ 进入拖拽排序，点击一行立即切 style（modal 不关）。
/// Favorites 频道走跨 category 分支（Task 5），带原频道 chip。
struct DetailsView: View {
    @Bindable var state: AppState

    var body: some View {
        Group {
            if state.currentChannel == .favorites {
                FavoritesDetailsList(state: state)
            } else {
                CategoryDetailsList(state: state)
            }
        }
        .background(FogTokens.bgDeep.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Category 分支

private struct CategoryDetailsList: View {
    @Bindable var state: AppState

    /// 本地副本——List.onMove 需要可变数组。来自 AppState.orderedStyles，
    /// 用户松手时 reorderStyles 持久化，AppState 来源恒定。
    @State private var ordered: [MoodStyle] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(ordered, id: \.id) { style in
                    StyleRow(
                        style: style,
                        isPlaying: state.selectedStyle?.id == style.id,
                        isPinned: state.isPinned(style),
                        showCategoryChip: false
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.selectStyle(style)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove { from, to in
                    ordered.move(fromOffsets: from, toOffset: to)
                    state.reorderStyles(in: state.currentChannel, newOrder: ordered)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .onAppear {
            ordered = state.orderedStyles(for: state.currentChannel)
        }
        .onChange(of: state.currentChannel) { _, _ in
            ordered = state.orderedStyles(for: state.currentChannel)
        }
    }

    private var header: some View {
        HStack {
            Text(state.currentChannel.displayName)
                .fog(.title)
                .foregroundStyle(FogTokens.textPrimary)
            Text("· \(ordered.count) styles")
                .fog(.body)
                .foregroundStyle(FogTokens.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Favorites 分支

private struct FavoritesDetailsList: View {
    @Bindable var state: AppState

    @State private var ordered: [MoodStyle] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            if ordered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(ordered, id: \.id) { style in
                        StyleRow(
                            style: style,
                            isPlaying: state.selectedStyle?.id == style.id,
                            isPinned: true,
                            showCategoryChip: true
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectCrossChannel(style: style) }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { from, to in
                        ordered.move(fromOffsets: from, toOffset: to)
                        state.reorderStyles(in: .favorites, newOrder: ordered)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
        }
        .onAppear {
            ordered = state.orderedStyles(for: .favorites)
        }
        .onChange(of: state.pinnedStyles.map(\.id)) { _, _ in
            ordered = state.orderedStyles(for: .favorites)
        }
    }

    /// 点击跨频道 style：切到对应 category 再 select。
    /// Favorites 频道自身的 visualizer 由 Channel.favoritesVisualizerPreference 决定
    /// （spec §14 Q2 标注：不跟随 style 原 category，保持 Favorites 频道纯 nightWindow）。
    /// 这里用户点 Favorites Details 里的一行，等价「切到对应 category 再播该 style」。
    private func selectCrossChannel(style: MoodStyle) {
        let target = Channel.category(style.category)
        if state.currentChannel != target {
            state.switchToChannel(target)
        }
        state.selectStyle(style)
    }

    private var header: some View {
        HStack {
            Text("Favorites")
                .fog(.title)
                .foregroundStyle(FogTokens.textPrimary)
            Text("· \(ordered.count) styles")
                .fog(.body)
                .foregroundStyle(FogTokens.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "heart")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(FogTokens.textSecondary.opacity(0.5))
            Text("Long-press any style to pin it here.")
                .fog(.body)
                .foregroundStyle(FogTokens.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

private struct StyleRow: View {
    let style: MoodStyle
    let isPlaying: Bool
    let isPinned: Bool
    let showCategoryChip: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 左列标识：▶ / ♡ / 空
            Group {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundStyle(FogTokens.accentIndigo)
                } else if isPinned {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(FogTokens.textSecondary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 16, height: 16)
            .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(style.name)
                    .fog(.body)
                    .foregroundStyle(FogTokens.textPrimary)
                if showCategoryChip {
                    Text(style.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.0)
                        .foregroundStyle(FogTokens.textSecondary.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
    }
}

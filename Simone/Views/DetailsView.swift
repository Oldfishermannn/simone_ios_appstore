import SwiftUI

/// v1.3 · Details as bottom sheet content. 展示当前频道 style 列表，
/// 长按 ≡ 进入拖拽排序，点击一行立即切 style（modal 不关）。
/// v1.4a: Favorites 频道已移除，只保留 Category 分支。
struct DetailsView: View {
    @Bindable var state: AppState

    var body: some View {
        CategoryDetailsList(state: state)
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
                        isPlaying: state.selectedStyle?.id == style.id
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

// MARK: - Row

private struct StyleRow: View {
    let style: MoodStyle
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundStyle(FogTokens.accentIndigo)
                } else {
                    Color.clear
                }
            }
            .frame(width: 16, height: 16)
            .font(.system(size: 12))

            Text(style.name)
                .fog(.body)
                .foregroundStyle(FogTokens.textPrimary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
    }
}

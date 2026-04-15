import SwiftUI

struct ExpandableCardView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Pinned styles
            if !state.pinnedStyles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("固定")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.25))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(state.pinnedStyles) { style in
                                StylePill(
                                    style: style,
                                    isActive: state.selectedStyle?.id == style.id,
                                    onTap: { state.selectStyle(style) },
                                    onUnpin: { state.unpinStyle(style) }
                                )
                            }
                        }
                    }
                }
            }

            // Explore styles with arrows
            VStack(alignment: .leading, spacing: 6) {
                Text("推荐")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                ExploreRow(state: state)
            }

            // Evolve mode
            HStack(spacing: 8) {
                ForEach(AppState.EvolveMode.allCases, id: \.rawValue) { mode in
                    Button {
                        state.evolveMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                state.evolveMode == mode
                                    ? MorandiPalette.mauve.opacity(0.2)
                                    : Color.white.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(
                                state.evolveMode == mode
                                    ? MorandiPalette.mauve
                                    : .white.opacity(0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    state.regenerate()
                } label: {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise")
                        .font(.system(size: 15))
                        .padding(10)
                        .background(MorandiPalette.sand.opacity(0.15))
                        .clipShape(Circle())
                        .foregroundStyle(MorandiPalette.sand)
                }
                .buttonStyle(.plain)
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Style Pill

private struct StylePill: View {
    let style: MoodStyle
    let isActive: Bool
    let onTap: () -> Void
    var onPin: (() -> Void)? = nil
    var onUnpin: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            Text(style.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isActive
                        ? MorandiPalette.rose.opacity(0.2)
                        : Color.white.opacity(0.06)
                )
                .foregroundStyle(
                    isActive
                        ? MorandiPalette.rose
                        : .white.opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onPin {
                Button {
                    onPin()
                } label: {
                    Label("固定", systemImage: "pin.fill")
                }
            }
            if let onUnpin {
                Button {
                    onUnpin()
                } label: {
                    Label("取消固定", systemImage: "pin.slash.fill")
                }
            }
        }
    }
}

// MARK: - Explore Row with arrows

private struct ExploreRow: View {
    @Bindable var state: AppState
    @State private var page: Int = 0

    private let pageSize = 2

    private var currentPage: [MoodStyle] {
        let start = page * pageSize
        let end = min(start + pageSize, state.exploredStyles.count)
        guard start < end else { return [] }
        return Array(state.exploredStyles[start..<end])
    }

    private var canGoBack: Bool { page > 0 }
    private var canGoForward: Bool { (page + 1) * pageSize < state.exploredStyles.count }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { page -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(canGoBack ? 0.5 : 0.15))
                    .frame(width: 20, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            ForEach(currentPage) { style in
                StylePill(
                    style: style,
                    isActive: state.selectedStyle?.id == style.id,
                    onTap: { state.selectStyle(style) },
                    onPin: { state.pinStyle(style) }
                )
                .frame(maxWidth: .infinity)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    page += 1
                    // Prefetch more styles if near the end
                    if (page + 1) * pageSize >= state.exploredStyles.count {
                        state.exploreMore()
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 20, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
}

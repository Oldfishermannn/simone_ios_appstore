import SwiftUI

struct ExpandableCardView: View {
    @Bindable var state: AppState
    @State private var pinnedDropTargeted = false
    @State private var exploreDropTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            // Pinned styles — drop here to pin
            VStack(alignment: .leading, spacing: 6) {
                Text("固定")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if state.pinnedStyles.isEmpty {
                            Text("拖入风格到此处固定")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.15))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        ForEach(state.pinnedStyles) { style in
                            StylePill(
                                style: style,
                                isActive: state.selectedStyle?.id == style.id,
                                onTap: { state.selectStyle(style) }
                            )
                            .draggable(style)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pinnedDropTargeted ? MorandiPalette.rose.opacity(0.1) : .clear)
                        .animation(.easeInOut(duration: 0.15), value: pinnedDropTargeted)
                )
                .dropDestination(for: MoodStyle.self) { items, _ in
                    for item in items {
                        state.pinStyle(item)
                    }
                    return true
                } isTargeted: { targeted in
                    pinnedDropTargeted = targeted
                }
            }

            // Explore styles — drop here to unpin
            VStack(alignment: .leading, spacing: 6) {
                Text("推荐")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                ExploreRow(state: state)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(exploreDropTargeted ? MorandiPalette.mauve.opacity(0.1) : .clear)
                            .animation(.easeInOut(duration: 0.15), value: exploreDropTargeted)
                    )
                    .dropDestination(for: MoodStyle.self) { items, _ in
                        for item in items {
                            state.unpinStyle(item)
                        }
                        return true
                    } isTargeted: { targeted in
                        exploreDropTargeted = targeted
                    }
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

            // 参数监控
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    paramLabel("T", value: String(format: "%.1f", state.temperature))
                    paramLabel("G", value: String(format: "%.1f", state.guidance))
                    paramLabel("BPM", value: state.bpm > 0 ? "\(state.bpm)" : "auto")
                    paramLabel("D", value: state.density >= 0 ? String(format: "%.1f", state.density) : "auto")
                    paramLabel("B", value: state.brightness >= 0 ? String(format: "%.1f", state.brightness) : "auto")
                    paramLabel("K", value: "\(state.topK)")
                }
                HStack(spacing: 8) {
                    toggleLabel("🥁", on: state.muteDrums) { state.muteDrums.toggle(); state.applyConfig() }
                    toggleLabel("🎸", on: state.muteBass) { state.muteBass.toggle(); state.applyConfig() }
                    toggleLabel("B+D", on: state.onlyBassAndDrums) { state.onlyBassAndDrums.toggle(); state.applyConfig() }
                    Spacer()
                    ForEach(["QUALITY", "DIVERSITY", "VOCAL"], id: \.self) { mode in
                        Button {
                            state.musicMode = mode == "VOCAL" ? "VOCALIZATION" : mode
                            state.applyConfig()
                        } label: {
                            Text(mode)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    (state.musicMode == mode || (mode == "VOCAL" && state.musicMode == "VOCALIZATION"))
                                        ? MorandiPalette.mauve.opacity(0.2)
                                        : Color.white.opacity(0.04)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(
                                    (state.musicMode == mode || (mode == "VOCAL" && state.musicMode == "VOCALIZATION"))
                                        ? MorandiPalette.mauve
                                        : .white.opacity(0.35)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func toggleLabel(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(on ? MorandiPalette.rose.opacity(0.2) : Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(on ? MorandiPalette.rose : .white.opacity(0.35))
        }
        .buttonStyle(.plain)
    }

    private func paramLabel(_ name: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Style Pill

private struct StylePill: View {
    let style: MoodStyle
    let isActive: Bool
    let onTap: () -> Void

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
                    onTap: { state.selectStyle(style) }
                )
                .draggable(style)
                .frame(maxWidth: .infinity)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    page += 1
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

import SwiftUI

struct DetailsView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Mini Player
                MiniPlayerView(state: state)
                    .padding(.horizontal, 16)

                Spacer().frame(height: 20)

                // Favorites
                favoritesSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 20)

                // Recommendations
                recommendationsSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 24)

                // Evolve
                evolveSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // Sleep Timer
                sleepTimerSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 32)
            }
            .frame(maxWidth: 400)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("喜爱")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        state.playbackMode = .sequential
                    } label: {
                        Text("🔁")
                            .font(.system(size: 14))
                            .opacity(state.playbackMode == .sequential ? 1.0 : 0.35)
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.playbackMode = .shuffle
                    } label: {
                        Text("🔀")
                            .font(.system(size: 14))
                            .opacity(state.playbackMode == .shuffle ? 1.0 : 0.35)
                    }
                    .buttonStyle(.plain)
                }
            }

            if state.pinnedStyles.isEmpty {
                Text("点击 ♡ 将喜爱的风格添加到这里")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.15))
                    .padding(.vertical, 12)
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
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("推荐")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                Spacer()

                Button {
                    state.refreshRecommendations()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise")
                            .font(.system(size: 11))
                        Text("换一批")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(MorandiPalette.rose)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MorandiPalette.rose.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            ForEach(state.exploredStyles) { style in
                let isFav = state.pinnedStyles.contains(where: { $0.id == style.id })
                StyleRowView(
                    style: style,
                    isPlaying: state.selectedStyle?.id == style.id,
                    isFavorite: isFav,
                    showFavoriteButton: true,
                    onTap: { state.selectStyle(style) },
                    onToggleFavorite: {
                        if isFav {
                            state.unpinStyle(style)
                        } else {
                            state.pinStyle(style)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Evolve

    private var evolveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("演化 EVOLVE")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 6) {
                ForEach(AppState.EvolveMode.allCases, id: \.rawValue) { mode in
                    Button {
                        state.evolveMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                state.evolveMode == mode
                                    ? MorandiPalette.mauve.opacity(0.2)
                                    : Color.white.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(
                                state.evolveMode == mode
                                    ? MorandiPalette.mauve
                                    : .white.opacity(0.4)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }

    // MARK: - Sleep Timer

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("定时关闭")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 6) {
                ForEach(AppState.SleepDuration.allCases, id: \.rawValue) { duration in
                    Button {
                        if state.activeSleepDuration == duration {
                            state.cancelSleepTimer()
                        } else {
                            state.startSleepTimer(duration)
                        }
                    } label: {
                        Text(duration.label)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                state.activeSleepDuration == duration
                                    ? MorandiPalette.sand.opacity(0.2)
                                    : Color.white.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(
                                state.activeSleepDuration == duration
                                    ? MorandiPalette.sand
                                    : .white.opacity(0.4)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }
}

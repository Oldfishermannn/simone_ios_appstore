import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var showEvolveInfo = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            Text("Settings")
                .font(.system(size: 22, weight: .medium))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.8))

            Spacer().frame(height: 28)

            // Evolve
            evolveSection

            Spacer().frame(height: 20)

            // Sleep Timer
            sleepTimerSection

            Spacer().frame(height: 20)

            // Visualizer
            visualizerSection

            Spacer().frame(height: 20)

            // About
            aboutSection

            Spacer()
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Evolve

    private var evolveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EVOLVE")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.25))

                Button {
                    showEvolveInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if showEvolveInfo {
                Text("Music subtly shifts over time, like a DJ slowly changing the vibe. 10s = fast changes, 5m = slow drift, Lock = stay the same.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SLEEP TIMER")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.25))

                Spacer()

                if let end = state.sleepTimerEnd {
                    Text(end, style: .timer)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(MorandiPalette.sand.opacity(0.6))
                }
            }

            HStack(spacing: 6) {
                // Off button
                Button {
                    state.cancelSleepTimer()
                } label: {
                    Text("Off")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            state.activeSleepDuration == nil
                                ? MorandiPalette.sand.opacity(0.2)
                                : Color.white.opacity(0.04)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(
                            state.activeSleepDuration == nil
                                ? MorandiPalette.sand
                                : .white.opacity(0.4)
                        )
                }
                .buttonStyle(.plain)

                ForEach(AppState.SleepDuration.allCases, id: \.rawValue) { duration in
                    Button {
                        state.startSleepTimer(duration)
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

    // MARK: - Visualizer

    private var visualizerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VISUALIZERS")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 10) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))

                Text("11 built-in visualizers")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ABOUT")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.25))

            VStack(spacing: 0) {
                aboutRow(icon: "music.note", label: "Simone — AI Ambient Radio", detail: "v1.0.0")
                Divider().background(Color.white.opacity(0.05))
                aboutRow(icon: "cpu", label: "Powered by", detail: "Google Lyria AI")
                Divider().background(Color.white.opacity(0.05))
                aboutRow(icon: "shield", label: "Privacy Policy", detail: "→")
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func aboutRow(icon: String, label: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

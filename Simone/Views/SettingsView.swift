import SwiftUI

/// Fog City Nocturne — one-screen settings.
/// No ScrollView by design: every control fits in a single frame so it never
/// competes with the outer VerticalPageView gesture. Future expansions go to
/// secondary pages (tap version row in Colophon).
struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 72)

            Text("∙ Preferences ∙")
                .fogSectionLabel()

            Spacer().frame(height: FogTheme.space2XL)

            // Four setting rows
            settingRow(
                title: "Evolve",
                subtitle: "the slow mood shift",
                value: state.evolveMode.rawValue.uppercased(),
                tappable: true,
                action: cycleEvolve
            )
            fogDivider

            settingRow(
                title: "Auto Tune",
                subtitle: "fresh channel every 25 min",
                value: state.autoTuneEnabled ? "ON" : "OFF",
                tappable: true,
                action: { state.autoTuneEnabled.toggle() }
            )
            fogDivider

            settingRow(
                title: "Sleep",
                subtitle: sleepSubtitle,
                value: sleepDisplay,
                tappable: true,
                action: cycleSleep
            )
            fogDivider

            settingRow(
                title: "Spectrum",
                subtitle: "eleven shapes, bound to channel",
                value: state.currentChannel.visualizer.displayName.uppercased(),
                tappable: false,
                action: {}
            )
            fogDivider

            settingRow(
                title: "Favorites Style",
                subtitle: "ambient city window",
                value: state.favoritesVisualizer.displayName.uppercased(),
                tappable: false,
                action: {}
            )
            fogDivider

            settingRow(
                title: "Night Window",
                subtitle: "glass · room · street",
                value: state.nightWindowBigStyle.displayName.uppercased(),
                tappable: true,
                action: cycleNightWindowBigStyle
            )

            spectrumPreview
                .padding(.top, FogTheme.spaceMD)
                .padding(.bottom, FogTheme.spaceSM)

            Spacer()

            colophon

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }

    // MARK: - Row

    @ViewBuilder
    private func settingRow(
        title: String,
        subtitle: String,
        value: String,
        tappable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: tappable ? action : {}) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(FogTheme.display(15, weight: .light))
                        .tracking(FogTheme.trackDisplay)
                        .foregroundStyle(FogTheme.inkPrimary)
                    Text(subtitle)
                        .font(FogTheme.serifItalic(11, weight: .light))
                        .foregroundStyle(FogTheme.inkSecondary.opacity(0.7))
                }
                Spacer(minLength: FogTheme.spaceLG)
                Text(value)
                    .font(FogTheme.mono(11, weight: .regular))
                    .tracking(FogTheme.trackMeta)
                    .foregroundStyle(tappable ? FogTheme.accent : FogTheme.inkSecondary)
            }
            .padding(.vertical, FogTheme.spaceMD)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    private var fogDivider: some View {
        Rectangle()
            .fill(FogTheme.hairline)
            .frame(height: 0.5)
    }

    // MARK: - Spectrum mini preview

    private var spectrumPreview: some View {
        let current = state.currentChannel.visualizer
        let styles = VisualizerStyle.allCases
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(styles.enumerated()), id: \.element.id) { index, style in
                let isCurrent = style == current
                // Pseudo-random but stable heights so the strip reads as a spectrum.
                let h = CGFloat(6 + (index * 37) % 14)
                Rectangle()
                    .fill(isCurrent ? FogTheme.accent : FogTheme.inkQuiet)
                    .frame(width: 4, height: isCurrent ? 16 : h)
            }
        }
        .frame(height: 20)
    }

    // MARK: - Colophon (book-copyright-page style)

    private var colophon: some View {
        VStack(spacing: FogTheme.spaceMD) {
            Rectangle()
                .fill(FogTheme.hairline)
                .frame(height: 0.5)
                .overlay(
                    Text("Colophon")
                        .font(FogTheme.mono(9, weight: .regular))
                        .tracking(FogTheme.trackLabel)
                        .foregroundStyle(FogTheme.inkTertiary)
                        .padding(.horizontal, FogTheme.spaceMD)
                        .background(FogTheme.surfaceBottom)
                )

            HStack(alignment: .top, spacing: FogTheme.spaceLG) {
                VStack(alignment: .leading, spacing: 4) {
                    colophonLabel("VERSION")
                    Text("Simone v\(appVersion)")
                        .font(FogTheme.mono(11, weight: .regular))
                        .foregroundStyle(FogTheme.inkPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    colophonLabel("ENGINE")
                    Text("Google Lyria RT")
                        .font(FogTheme.mono(11, weight: .regular))
                        .foregroundStyle(FogTheme.inkPrimary)
                }
            }
            .padding(.top, FogTheme.spaceSM)

            HStack(alignment: .top, spacing: FogTheme.spaceLG) {
                VStack(alignment: .leading, spacing: 4) {
                    colophonLabel("PRIVACY")
                    Button {
                        openPrivacy()
                    } label: {
                        Text("Read →")
                            .font(FogTheme.mono(11, weight: .regular))
                            .foregroundStyle(FogTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    colophonLabel("MADE")
                    Text("2026 · Night")
                        .font(FogTheme.mono(11, weight: .regular))
                        .foregroundStyle(FogTheme.inkPrimary)
                }
            }
        }
    }

    private func colophonLabel(_ text: String) -> some View {
        Text(text)
            .font(FogTheme.mono(8, weight: .regular))
            .tracking(FogTheme.trackLabel)
            .foregroundStyle(FogTheme.inkTertiary)
    }

    // MARK: - Actions & derived display

    private func cycleEvolve() {
        let modes = AppState.EvolveMode.allCases
        guard let idx = modes.firstIndex(of: state.evolveMode) else { return }
        state.evolveMode = modes[(idx + 1) % modes.count]
    }

    private func cycleNightWindowBigStyle() {
        let options = NightWindowBigStyle.allCases
        guard let idx = options.firstIndex(of: state.nightWindowBigStyle) else {
            state.nightWindowBigStyle = options.first ?? .glass
            return
        }
        state.nightWindowBigStyle = options[(idx + 1) % options.count]
    }

    private func cycleFavoritesStyle() {
        let options = Channel.favoritesVisualizerOptions
        guard let idx = options.firstIndex(of: state.favoritesVisualizer) else {
            state.favoritesVisualizer = options.first ?? .firefly
            return
        }
        state.favoritesVisualizer = options[(idx + 1) % options.count]
    }

    private func cycleSleep() {
        let durations = AppState.SleepDuration.allCases
        if let active = state.activeSleepDuration,
           let idx = durations.firstIndex(of: active) {
            if idx + 1 < durations.count {
                state.startSleepTimer(durations[idx + 1])
            } else {
                state.cancelSleepTimer()
            }
        } else {
            state.startSleepTimer(durations.first!)
        }
    }

    private var sleepDisplay: String {
        state.activeSleepDuration?.label.uppercased() ?? "OFF"
    }

    private var sleepSubtitle: String {
        if let end = state.sleepTimerEnd {
            let remaining = Int(max(0, end.timeIntervalSinceNow / 60))
            return "\(remaining) min to silence"
        }
        return "fade to silence"
    }

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let short = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        return short
    }

    private func openPrivacy() {
        guard let url = URL(string: "https://oldfishermannn.github.io/simone_ios_appstore/privacy.html") else { return }
        UIApplication.shared.open(url)
    }
}

import SwiftUI

/// v1.4a · Settings — 学 DetailsView 极简风：FogTokens.bgDeep 黑底，
/// 一组 hairline-divider 行，一个 footer 显示版本号和 Privacy。
///
/// 删掉了 v1.2 的 editorial 装饰（gutter legend / library-card codex /
/// colophon 4 列）以及 v1.4a 一度存在的 Signature/Classic toggle。
/// CEO 反馈：信息太多 ui 太杂，details 页就很好——向 details 学习。
struct SettingsView: View {
    @Bindable var state: AppState

    #if DEBUG
    @AppStorage("feature_proactive_rotation") private var proactiveRotation: Bool = false
    #endif

    var body: some View {
        ZStack {
            FogTokens.bgDeep.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                rows
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .fog(.title)
                .foregroundStyle(FogTokens.textPrimary)
            Text("notes from the listening room")
                .font(FogTheme.serifItalic(13, weight: .light))
                .foregroundStyle(FogTokens.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Rows

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingRow(
                title: "Auto Tune",
                subtitle: "fresh channel every 25 min",
                value: state.autoTuneEnabled ? "ON" : "OFF",
                isLive: state.autoTuneEnabled,
                action: { state.autoTuneEnabled.toggle() }
            )

            hairline

            settingRow(
                title: "Evolve",
                subtitle: "the slow mood shift",
                value: state.evolveMode.rawValue.uppercased(),
                isLive: state.evolveMode != .locked,
                action: cycleEvolve
            )

            hairline

            settingRow(
                title: "Sleep",
                subtitle: "fade to silence",
                value: state.activeSleepDuration?.label.uppercased() ?? "OFF",
                isLive: state.activeSleepDuration != nil,
                action: cycleSleep
            )

            #if DEBUG
            hairline

            settingRow(
                title: "Proactive Rotation",
                subtitle: "v1.4 dual-ws · DEBUG only",
                value: proactiveRotation ? "ON" : "OFF",
                isLive: proactiveRotation,
                action: {
                    proactiveRotation.toggle()
                    // v1.4 fix Bug 3: toggle 立即生效,不需等 9 min 重新 arm
                    if proactiveRotation && state.audioEngine.isPlaying {
                        state.sessionRotator.armRotationTimer()
                    } else if !proactiveRotation {
                        state.sessionRotator.cancelRotation()
                    }
                }
            )
            #endif
        }
    }

    @ViewBuilder
    private func settingRow(
        title: String,
        subtitle: String,
        value: String,
        isLive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(FogTheme.display(17, weight: .light))
                        .tracking(FogTheme.trackDisplay)
                        .foregroundStyle(FogTokens.textPrimary)
                    Text(subtitle)
                        .font(FogTheme.serifItalic(12, weight: .light))
                        .foregroundStyle(FogTokens.textSecondary.opacity(0.65))
                }

                Spacer(minLength: 16)

                Text(value)
                    .font(FogTheme.mono(11, weight: .regular))
                    .tracking(FogTheme.trackMeta)
                    .foregroundStyle(
                        isLive
                            ? FogTokens.textPrimary
                            : FogTokens.textSecondary.opacity(0.6)
                    )
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hairline: some View {
        Rectangle()
            .fill(FogTokens.lineHairline)
            .frame(height: 0.5)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            hairline

            HStack(alignment: .firstTextBaseline) {
                Button(action: openPrivacy) {
                    HStack(spacing: 6) {
                        Text("Privacy policy")
                            .font(FogTheme.mono(11, weight: .regular))
                            .foregroundStyle(FogTokens.textPrimary)
                        Text("↗")
                            .font(FogTheme.mono(11, weight: .regular))
                            .foregroundStyle(FogTheme.accent)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("v\(appVersion)")
                    .font(FogTheme.mono(11, weight: .regular))
                    .tracking(FogTheme.trackMeta)
                    .foregroundStyle(FogTokens.textSecondary.opacity(0.6))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func cycleEvolve() {
        let modes = AppState.EvolveMode.allCases
        guard let idx = modes.firstIndex(of: state.evolveMode) else { return }
        state.evolveMode = modes[(idx + 1) % modes.count]
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

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let short = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = dict?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private func openPrivacy() {
        guard let url = URL(string: "https://oldfishermannn.github.io/simone_ios_appstore/privacy.html") else { return }
        UIApplication.shared.open(url)
    }
}

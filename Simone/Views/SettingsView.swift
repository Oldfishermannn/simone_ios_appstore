import SwiftUI

/// Fog City Nocturne — Settings as a Night Log page.
///
/// The metaphor: this page is not a form, it's a page torn from a nocturne
/// workbook. A typeset sheet with an editorial header (version as volume
/// number + title),
/// an uneven weighted set of entries (Auto Tune is the primary act; the other
/// three are secondary attendants), and a colophon block at the foot.
///
/// Structural devices (all intentional, all restraint):
///   • Left margin marker — vertical SF-Mono legend "SIMONE · SETTINGS · NOCTURNE"
///     running up the left gutter. Acts as a book-spine / column rule; not an
///     accent stripe (that is specifically banned in impeccable).
///   • Asymmetric, left-aligned header — no centered decorative label. App
///     version number (the volume number of a magazine issue) sits in a big
///     Unbounded cut, then the title, then a Fraunces-italic subtitle.
///   • Weight hierarchy — Auto Tune is the fulcrum (people toggle it most);
///     Evolve / Sleep / Spectrum are smaller satellites. OPEN / CLOSED reads
///     more like a radio-room log than ON / OFF.
///   • Visualizer glyph column — each row carries a 2-letter codex label on
///     the right (TP / OS / LQ / EM / MX …) like a library catalog card; the
///     current channel's codex glows with accent, everyone else is quiet ink.
///   • Accent is scarce — mauve is reserved for (a) Auto Tune's live state
///     label and (b) the Privacy link arrow. Everything else is ink grades.
struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack(alignment: .leading) {
            // Left gutter marker — vertical printed legend, not a stripe.
            gutterLegend

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 64)

                header

                Spacer().frame(height: FogTheme.space3XL)

                // Primary entry — the one people actually touch.
                primaryRow

                Spacer().frame(height: FogTheme.spaceXL)

                // Satellites — same topic, lower visual weight.
                VStack(alignment: .leading, spacing: 0) {
                    satelliteRow(
                        title: "Evolve",
                        subtitle: "the slow mood shift",
                        value: state.evolveMode.rawValue.uppercased(),
                        codex: nil,
                        tappable: true,
                        isLive: state.evolveMode != .locked,
                        action: cycleEvolve
                    )

                    hairlineDivider

                    satelliteRow(
                        title: "Sleep",
                        subtitle: "fade to silence",
                        value: state.activeSleepDuration?.label.uppercased() ?? "OFF",
                        codex: nil,
                        tappable: true,
                        isLive: state.activeSleepDuration != nil,
                        action: cycleSleep
                    )

                    hairlineDivider

                    satelliteRow(
                        title: "Art",
                        subtitle: "signature totem or classic set",
                        value: state.visualizationMode.rawValue.uppercased(),
                        codex: nil,
                        tappable: true,
                        isLive: state.visualizationMode == .signature,
                        action: toggleVisualizationMode
                    )

                    hairlineDivider

                    satelliteRow(
                        title: "Spectrum",
                        subtitle: "one shape per channel",
                        value: state.currentChannel.visualizer.displayName.uppercased(),
                        codex: visualizerCodex(state.currentChannel.visualizer),
                        tappable: false,
                        isLive: false,
                        action: {}
                    )
                }

                Spacer(minLength: FogTheme.spaceXL)

                #if DEBUG
                debugSpliceRow
                    .padding(.top, FogTheme.spaceXL)
                #endif

                colophon
                    .padding(.top, FogTheme.space2XL)

                Spacer().frame(height: 40)
            }
            .padding(.leading, 44)   // leave room for the gutter legend
            .padding(.trailing, 28)
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gutter legend

    /// Thin vertical legend running up the left margin. SF-Mono, wide tracking,
    /// rotated -90°. Reads like the spine lettering on a slim paperback. NOT a
    /// colored accent bar — that pattern is forbidden; this is a piece of type.
    private var gutterLegend: some View {
        VStack {
            Spacer()
            Text("SIMONE · SETTINGS · NOCTURNE · v\(appVersion)")
                .font(FogTheme.mono(9, weight: .regular))
                .tracking(3.6)
                .foregroundStyle(FogTheme.inkTertiary.opacity(0.55))
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 12)
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.leading, 14)
    }

    // MARK: - Editorial header

    /// Page-number editorial header. Asymmetric, left-aligned. The version
    /// number sits where a magazine would print its volume/issue — a typeset
    /// heavyweight that doubles as meta-information. 42pt instead of 56pt
    /// because "1.2.1" has two dots; at 56pt the dots float and the overall
    /// mass looks wider than "04" did. 42pt keeps the visual weight comparable.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: FogTheme.spaceLG) {
            Text(appVersion)
                .font(FogTheme.display(42, weight: .light))
                .tracking(-0.8)
                .foregroundStyle(FogTheme.inkPrimary)
                .baselineOffset(-2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(FogTheme.display(22, weight: .light))
                    .tracking(FogTheme.trackDisplay)
                    .foregroundStyle(FogTheme.inkPrimary)
                Text("notes from the listening room")
                    .font(FogTheme.serifItalic(13, weight: .light))
                    .foregroundStyle(FogTheme.inkSecondary.opacity(0.75))
            }

            Spacer()
        }
    }

    // MARK: - Primary row (Auto Tune)

    /// v1.3: 主屏无激活态 UI (spec §6.2 D)。OPEN/CLOSED 状态文字已删，
    /// 只留 live-state dot 做极轻提示。
    private var primaryRow: some View {
        Button {
            state.autoTuneEnabled.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Auto Tune")
                        .font(FogTheme.display(26, weight: .light))
                        .tracking(FogTheme.trackDisplay)
                        .foregroundStyle(FogTheme.inkPrimary)

                    Spacer(minLength: FogTheme.spaceLG)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("fresh channel every 25 min")
                        .font(FogTheme.serifItalic(13, weight: .light))
                        .foregroundStyle(FogTheme.inkSecondary.opacity(0.7))

                    Spacer()

                    // Live-state dot — tiny, only visible when active.
                    Circle()
                        .fill(FogTheme.accent)
                        .frame(width: 5, height: 5)
                        .opacity(state.autoTuneEnabled ? 1.0 : 0.0)
                }
            }
            .padding(.vertical, FogTheme.spaceMD)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Satellite rows

    /// Secondary entries. Smaller type, visually subordinate. The codex
    /// parameter renders a two-letter visualizer code on the right for the
    /// Spectrum row; other rows leave it nil and show a plain mono value.
    @ViewBuilder
    private func satelliteRow(
        title: String,
        subtitle: String,
        value: String,
        codex: String?,
        tappable: Bool,
        isLive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: tappable ? action : {}) {
            HStack(alignment: .firstTextBaseline, spacing: FogTheme.spaceLG) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(FogTheme.display(16, weight: .light))
                        .tracking(FogTheme.trackDisplay)
                        .foregroundStyle(FogTheme.inkPrimary)
                    Text(subtitle)
                        .font(FogTheme.serifItalic(11, weight: .light))
                        .foregroundStyle(FogTheme.inkSecondary.opacity(0.65))
                }

                Spacer(minLength: FogTheme.spaceLG)

                // Right-hand column: either the library-card codex glyph
                // (Spectrum) or a plain mono value (Evolve / Sleep).
                if let codex {
                    codexBlock(value: value, codex: codex)
                } else {
                    Text(value)
                        .font(FogTheme.mono(11, weight: .regular))
                        .tracking(FogTheme.trackMeta)
                        .foregroundStyle(
                            isLive
                                ? FogTheme.inkPrimary
                                : FogTheme.inkSecondary.opacity(0.7)
                        )
                }
            }
            .padding(.vertical, FogTheme.spaceMD + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    /// Library-catalog glyph: tiny 2-letter codex stacked over the full
    /// spelled-out value. The codex is the eye-catch; the full word is the
    /// confirmation beneath it. Only Spectrum uses this.
    private func codexBlock(value: String, codex: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(codex)
                .font(FogTheme.display(18, weight: .light))
                .tracking(1.2)
                .foregroundStyle(FogTheme.inkPrimary)
            Text(value)
                .font(FogTheme.mono(9, weight: .regular))
                .tracking(FogTheme.trackLabel)
                .foregroundStyle(FogTheme.inkTertiary)
        }
    }

    private var hairlineDivider: some View {
        Rectangle()
            .fill(FogTheme.hairline)
            .frame(height: 0.5)
    }

    // MARK: - Colophon

    /// Foot of the page — colophon block in the style of a book's copyright
    /// page. Two data rows (version/engine, privacy/year). The hairline-rule
    /// with an inset "Colophon" label sits between body and colophon like a
    /// typeset ornament.
    private var colophon: some View {
        VStack(alignment: .leading, spacing: FogTheme.spaceLG) {
            // Rule with label inset — reads like a frontispiece caption.
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(FogTheme.hairline)
                    .frame(height: 0.5)
                Text("COLOPHON")
                    .font(FogTheme.mono(9, weight: .regular))
                    .tracking(FogTheme.trackLabel)
                    .foregroundStyle(FogTheme.inkTertiary)
                    .padding(.horizontal, FogTheme.spaceSM)
                    .background(FogTheme.surfaceBottom)
                    .padding(.leading, FogTheme.spaceMD)
            }

            HStack(alignment: .top, spacing: FogTheme.space2XL) {
                colophonEntry(
                    label: "ENGINE",
                    value: "Google Lyria RT"
                )
                Spacer()
                colophonEntry(
                    label: "PRESSED",
                    value: "2026 · Night",
                    alignment: .trailing
                )
            }

            HStack(alignment: .top, spacing: FogTheme.space2XL) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRIVACY")
                        .font(FogTheme.mono(8, weight: .regular))
                        .tracking(FogTheme.trackLabel)
                        .foregroundStyle(FogTheme.inkTertiary)
                    Button {
                        openPrivacy()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Read the policy")
                                .font(FogTheme.mono(11, weight: .regular))
                                .foregroundStyle(FogTheme.inkPrimary)
                            Text("↗")
                                .font(FogTheme.mono(11, weight: .regular))
                                .foregroundStyle(FogTheme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                colophonEntry(
                    label: "CHANNEL",
                    value: state.currentChannel.displayName.uppercased(),
                    alignment: .trailing
                )
            }
        }
    }

    private func colophonEntry(
        label: String,
        value: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(FogTheme.mono(8, weight: .regular))
                .tracking(FogTheme.trackLabel)
                .foregroundStyle(FogTheme.inkTertiary)
            Text(value)
                .font(FogTheme.mono(11, weight: .regular))
                .foregroundStyle(FogTheme.inkPrimary)
        }
    }

    // MARK: - Actions & derived display

    private func cycleEvolve() {
        let modes = AppState.EvolveMode.allCases
        guard let idx = modes.firstIndex(of: state.evolveMode) else { return }
        state.evolveMode = modes[(idx + 1) % modes.count]
    }

    /// v1.4a Signature: flip between Signature totem and Classic visualizer set.
    private func toggleVisualizationMode() {
        state.visualizationMode =
            (state.visualizationMode == .signature) ? .classic : .signature
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
        return short
    }

    /// Library catalog-card code for each visualizer style. Two letters so the
    /// right column stays column-aligned regardless of which channel is live.
    private func visualizerCodex(_ style: VisualizerStyle) -> String {
        switch style {
        case .horizon:       return "HZ"
        case .ringPulse:     return "RP"
        case .terrain:       return "TR"
        case .rainfall:      return "RF"
        case .helix:         return "HX"
        case .lattice:       return "LT"
        case .prism:         return "PR"
        case .matrix:        return "MX"
        case .flora:         return "FL"
        case .glitch:        return "GL"
        case .oscilloscope:  return "OS"
        case .ember:         return "EM"
        case .liquor:        return "LQ"
        case .lofiTape:      return "TP"
        case .lofiPad:       return "PD"
        case .lofiBlinds:    return "BL"
        case .firefly:       return "FF"
        case .letters:       return "LE"
        case .drawer:        return "DR"
        case .nightWindow:   return "NW"
        case .vinylBooth:    return "VB"
        }
    }

    // MARK: - Debug · Splice Playback Test

    #if DEBUG
    /// v1.3 · Debug：强制触发 Lyria reconnectAndRestore 验 splice fallback。
    /// 仅 Debug 编译，Release build 不包含这段。
    private var debugSpliceRow: some View {
        VStack(alignment: .leading, spacing: FogTheme.spaceSM) {
            Text("DEBUG · SPLICE PLAYBACK TEST")
                .font(FogTheme.mono(9, weight: .regular))
                .tracking(FogTheme.trackLabel)
                .foregroundStyle(FogTheme.inkTertiary)

            Button {
                state.lyriaClient.reconnectAndRestore()
            } label: {
                HStack(spacing: 8) {
                    Text("⚡")
                        .font(FogTheme.mono(12, weight: .regular))
                        .foregroundStyle(FogTheme.accent)
                    Text("Simulate Lyria Disconnect")
                        .font(FogTheme.mono(11, weight: .regular))
                        .foregroundStyle(FogTheme.inkPrimary)
                }
            }
            .buttonStyle(.plain)

            Text("Triggers reconnectAndRestore. Listen for: old audio fades 1.5s → ring buffer loop → new chunk fades in 1.5s. No hard cut, no 1s gap.")
                .font(FogTheme.serifItalic(10, weight: .light))
                .foregroundStyle(FogTheme.inkSecondary.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    #endif

    private func openPrivacy() {
        guard let url = URL(string: "https://oldfishermannn.github.io/simone_ios_appstore/privacy.html") else { return }
        UIApplication.shared.open(url)
    }
}

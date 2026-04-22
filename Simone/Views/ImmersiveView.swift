import SwiftUI

/// v1.4a UI cleanup — 主视图：6 频道 horizontal page swipe（TabView .page），
/// 跟手丝滑替代 v1.3 的 onEnded DragGesture。每页一个 channel：渲染该
/// 频道默认 visualizer（全部走 morph 管线，expansion 0 = 小图 / 1 = 大图）+
/// bottomOverlay (style name + DNA)。Transport row（settings · play · details）
/// 浮在 TabView 之上，左右滑不动。
///
/// 关键联动：isSmall ↔ isPlaying。
///   播放 → 大图（expansion = 1）。
///   暂停 → 小图（expansion = 0）。
///   visualizer tap = togglePlayPause；transport play 按钮也 togglePlayPause。
///   两侧入口都通过 state.audioEngine.isPlaying 的 onChange 驱动 morph，统一一处。
///
/// 纵滑切 style 用 page 内部的 vertical-only DragGesture 接住（不与 TabView
/// 的 horizontal page swipe 冲突）。
struct ImmersiveView: View {
    @Bindable var state: AppState
    var onTapDetails: () -> Void = {}
    var onTapSettings: () -> Void = {}

    // TabView selection — 双向同步 state.currentChannel
    @State private var tabIndex: Int = 0

    // Morph state (expansion 0..1)。isSmall ↔ isPlaying 驱动这条 timeline。
    @State private var morphStart: Date = .distantPast
    @State private var morphFrom: CGFloat = 0
    @State private var morphTo: CGFloat = 0
    private let morphDuration: Double = 0.55

    private func currentExpansion(now: Date) -> CGFloat {
        let elapsed = now.timeIntervalSince(morphStart)
        if elapsed <= 0 { return morphFrom }
        if elapsed >= morphDuration { return morphTo }
        let t = elapsed / morphDuration
        let eased = 1.0 - pow(2.0, -10.0 * t)  // ease-out expo
        return morphFrom + (morphTo - morphFrom) * CGFloat(eased)
    }

    private func setMode(toBig: Bool) {
        let target: CGFloat = toBig ? 1.0 : 0.0
        let now = Date()
        let current = currentExpansion(now: now)
        guard abs(current - target) > 0.001 else { return }
        morphFrom = current
        morphTo = target
        morphStart = now
    }

    /// 用于派生大小图当前姿态——TabView 切页时 transport row 的微调位置。
    private var isPlayingNow: Bool { state.audioEngine.isPlaying }

    var body: some View {
        ZStack {
            // 底色 + big-mode dawn 渐变
            FogTokens.bgDeep.ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: FogTokens.accentIndigo.opacity(0.07), location: 0.0),
                    .init(color: FogTokens.bgDeep, location: 0.35),
                    .init(color: FogTokens.bgDeep, location: 0.72),
                    .init(color: FogTokens.bgSurface.opacity(0.85), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(isPlayingNow ? 1 : 0)
            .animation(.easeInOut(duration: morphDuration), value: isPlayingNow)
            .allowsHitTesting(false)

            // Horizontal pager — TabView .page 提供 native 跟手切换
            TabView(selection: $tabIndex) {
                ForEach(0..<Channel.all.count, id: \.self) { idx in
                    ChannelPage(
                        channel: Channel.all[idx],
                        state: state,
                        expansion: currentExpansion,
                        onTapVisualizer: { state.togglePlayPause() },
                        onSwipeStyle: { delta in switchStyle(by: delta) }
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Transport row — 浮在 TabView 上，左右滑不动。位置固定（不跟
            // isPlaying 上下移），点 play 按钮三个圈不再跳。
            VStack(spacing: 0) {
                Spacer()
                transportRow
                Spacer().frame(height: 80)
            }
            .allowsHitTesting(true)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            // 初始化 tabIndex 对齐当前 channel；morph 起点对齐当前播放状态
            tabIndex = Channel.all.firstIndex(of: state.currentChannel) ?? 0
            let initial: CGFloat = state.audioEngine.isPlaying ? 1.0 : 0.0
            morphFrom = initial
            morphTo = initial
            morphStart = .distantPast
        }
        .onChange(of: tabIndex) { _, new in
            let target = Channel.all[new]
            guard target != state.currentChannel else { return }
            state.switchToChannel(target)
        }
        .onChange(of: state.currentChannel) { _, new in
            // 外部改变 currentChannel（比如 AutoTune 不会切 channel，只是冗余防御）
            if let idx = Channel.all.firstIndex(of: new), idx != tabIndex {
                tabIndex = idx
            }
        }
        .onChange(of: state.audioEngine.isPlaying) { _, playing in
            setMode(toBig: playing)
        }
    }

    // MARK: - Vertical style swipe

    private func switchStyle(by delta: Int) {
        let list = state.orderedStyles(for: state.currentChannel)
        guard !list.isEmpty else { return }
        let currentId = state.selectedStyle?.id
        let idx = list.firstIndex(where: { $0.id == currentId }) ?? 0
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < list.count else { return }
        state.selectStyle(list[newIdx])
    }

    // MARK: - Transport (settings · play · details on the same baseline)

    private var transportRow: some View {
        HStack(spacing: 32) {
            settingsButton
            playButton
            detailsButton
        }
    }

    private var settingsButton: some View {
        Button(action: onTapSettings) {
            ZStack {
                Circle()
                    .fill(FogTokens.bgSurface.opacity(0.5))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(FogTokens.lineHairline, lineWidth: 1))
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(FogTokens.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    private var detailsButton: some View {
        Button(action: onTapDetails) {
            ZStack {
                Circle()
                    .fill(FogTokens.bgSurface.opacity(0.5))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(FogTokens.lineHairline, lineWidth: 1))
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(FogTokens.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Details")
    }

    /// Play 按钮 = togglePlayPause；播放状态变化由 onChange(isPlaying) 自动 morph
    /// 小图↔大图——所以"按播放键也会切换大小图"由 isPlaying 联动一处实现，
    /// 不需要这里再写 setMode。
    private var playButton: some View {
        Button {
            state.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(FogTokens.bgSurface.opacity(0.5))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(FogTokens.lineHairline, lineWidth: 1))
                Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(FogTokens.textPrimary.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.audioEngine.isPlaying)
    }
}

// MARK: - ChannelPage —— TabView 的单个 page

/// 单个频道页：全屏 morph visualizer + 底部 style name/DNA。
/// visualizer tap = togglePlayPause（让 ImmersiveView 的 onChange 驱动 morph）。
/// 上下纵滑切 style（不与 TabView 的横滑冲突，threshold 大于 horizontal）。
private struct ChannelPage: View {
    let channel: Channel
    @Bindable var state: AppState
    let expansion: (Date) -> CGFloat
    let onTapVisualizer: () -> Void
    let onSwipeStyle: (Int) -> Void

    /// 这个 page 当前应该显示哪个 style：是当前频道→显示 selectedStyle；
    /// 不是当前频道（TabView 邻居 page）→显示该频道首位 style 占位。
    private var displayStyle: MoodStyle? {
        if channel == state.currentChannel {
            return state.selectedStyle
        }
        return state.orderedStyles(for: channel).first
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 每个 channel 自己的底色 — Rock 暖煤 / Electronic 深夜 /
                // R&B 黑 / 其他冷 Fog。撑满 safe area，避免 visualizer 透出 bgDeep。
                channelBaseTint
                    .ignoresSafeArea()

                // visualizer — 仅当前 channel 跑 TimelineView 30fps，邻居 page
                // 用 expansion=0 静态帧（防 6 个 visualizer 同时高频 redraw 抢 CPU
                // 把音频饿瘦）。TabView 横滑时邻居先静态显示，落定后切活。
                if isActive {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                        visualizer(expansion: expansion(ctx.date))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    visualizer(expansion: 0)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                Color.clear
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapVisualizer() }
                    .gesture(verticalSwipe)

                VStack(spacing: 0) {
                    Spacer()
                    bottomOverlay
                    Spacer().frame(height: 145)  // 给 transport row 让位（titlea 往下挪一点）
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var isActive: Bool { channel == state.currentChannel }

    /// 每个频道自带 base 色 — RnB 小图也用纯黑（CEO 要求），其他频道用 mood-tinted。
    private var channelBaseTint: Color {
        switch channel {
        case .category(.rock):
            return Color(red: 28/255, green: 22/255, blue: 18/255)
        case .category(.electronic):
            return Color(red: 10/255, green: 10/255, blue: 14/255)
        case .category(.rnb):
            return Color.black
        case .category(.jazz):
            return Color(red: 14/255, green: 14/255, blue: 18/255)
        default:
            return FogTokens.bgDeep
        }
    }

    // MARK: - Visualizer dispatch

    @ViewBuilder
    private func visualizer(expansion: CGFloat) -> some View {
        let spectrum = state.audioEngine.spectrumData
        switch channel {
        case .category(.lofi):
            LofiTapeView(
                spectrumData: spectrum,
                density: 2,
                expansion: expansion,
                signatureVU: true,  // v1.4a Signature 永远 ON
                signatureDensityScale: state.signatureDensityScale,
                signatureOmegaScale: state.signatureOmegaScale
            )
        case .category(.jazz):
            OscilloscopeView(spectrumData: spectrum, density: 2, expansion: expansion)
        case .category(.rnb):
            RnBSignatureView(spectrumData: spectrum, density: 2, expansion: expansion)
        case .category(.electronic):
            ElectronicSignatureView(spectrumData: spectrum, density: 2, expansion: expansion)
        case .category(.rock):
            EmberView(spectrumData: spectrum, density: 2, expansion: expansion)
        case .category(.ambient):
            NightWindowView(spectrumData: spectrum, density: 2, expansion: expansion)
        default:
            EmberView(spectrumData: spectrum, density: 2, expansion: expansion)
        }
    }

    // MARK: - Bottom overlay

    private var bottomOverlay: some View {
        VStack(spacing: 10) {
            if let style = displayStyle {
                musicDNA(style: style)
            }
            Text(displayStyle?.name ?? channel.displayName)
                .fog(.displaySm)
                .foregroundStyle(FogTokens.textPrimary)
        }
    }

    private func musicDNA(style: MoodStyle) -> some View {
        let tags = extractDNA(from: style)
        return HStack(spacing: 0) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text(" · ")
                        .font(FogTheme.mono(11, weight: .regular))
                        .foregroundStyle(FogTheme.inkQuiet)
                }
                Text(tag)
                    .font(FogTheme.mono(11, weight: .regular))
                    .tracking(FogTheme.trackMeta)
                    .foregroundStyle(FogTheme.inkSecondary.opacity(0.65))
            }
        }
    }

    private func extractDNA(from style: MoodStyle) -> [String] {
        var tags: [String] = []
        tags.append(style.category.displayName.lowercased())

        let moodWords = ["warm", "melancholic", "dreamy", "dark", "ethereal", "intimate",
                         "gentle", "smooth", "slow", "deep", "bright", "soft", "cozy",
                         "raw", "cosmic", "hypnotic", "flowing", "lazy", "driving"]
        let promptLower = style.prompt.lowercased()
        for word in moodWords {
            if promptLower.contains(word) { tags.append(word); break }
        }

        let instruments = ["piano", "guitar", "saxophone", "bass", "drums", "synth",
                          "flute", "cello", "violin", "Rhodes", "harmonica", "harp",
                          "organ", "trumpet", "vibraphone"]
        for inst in instruments {
            if promptLower.contains(inst.lowercased()) { tags.append(inst.lowercased()); break }
        }

        if state.bpm > 0 { tags.append("\(state.bpm)bpm") }
        return tags
    }

    // MARK: - Vertical-only swipe

    /// 上下滑切 style。threshold 较大且要求竖直分量 > 横向，避免误吃 TabView 的横滑。
    private var verticalSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(v) > abs(h), abs(v) > 60 else { return }
                onSwipeStyle(v < 0 ? +1 : -1)  // 上滑 = 下一个 style
            }
    }
}

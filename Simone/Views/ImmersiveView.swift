import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState
    var onTapDetails: () -> Void = {}
    var onTapSettings: () -> Void = {}

    // Slide-on-channel-swipe plumbing — mirrors ContentView's pattern so the
    // immersive page overlay tracks the same horizontal gesture the carousel
    // already animates.
    @State private var nameSlideOffset: CGFloat = 0
    @State private var nameSlideOffsetY: CGFloat = 0
    @State private var nameOpacity: Double = 1.0
    @State private var displayStyleName: String = ""
    @State private var displayStyle: MoodStyle? = nil

    // v1.3 · 手势 state
    @State private var bounceOffsetY: CGFloat = 0
    @State private var bounceOffsetX: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    // v1.3 · Channel crossfade 400ms (legacy visualizer snapshot 淡出)
    @State private var crossfadeLegacy: (VisualizerStyle, MoodStyle?, Channel)? = nil
    @State private var crossfadeOpacity: Double = 0.0
    private let crossfadeDuration: Double = 0.4

    /// v1.1.1: tap the spectrum to toggle big (full-screen) ↔ small (rounded card).
    /// Default is big; small mode shows a card-sized spectrum at top.
    @State private var isSmall: Bool = true

    // MARK: - Lofi morph tween state
    //
    // Visualizers that expose an `expansion` parameter (currently only LofiTape)
    // render as a single full-screen canvas — geometry morphs continuously from
    // the bare-object pose (expansion=0) to the scene pose (expansion=1).
    // SwiftUI's withAnimation does not interpolate plain @State Doubles into a
    // Canvas draw closure, so we drive expansion ourselves off a timestamp and
    // sample it every TimelineView frame.
    @State private var morphStart: Date = .distantPast
    @State private var morphFrom: CGFloat = 0
    @State private var morphTo: CGFloat = 0
    private let morphDuration: Double = 0.55

    /// Exponential ease-out curve — strong deceleration, physical-feeling settle.
    /// Used for the dual-layer crossfade on non-lofi channels; the lofi path
    /// uses a matching pow-based ease so both feel identical.
    private var toggleAnim: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.52)
    }

    private func currentExpansion(now: Date) -> CGFloat {
        let elapsed = now.timeIntervalSince(morphStart)
        if elapsed <= 0 { return morphFrom }
        if elapsed >= morphDuration { return morphTo }
        let t = elapsed / morphDuration
        // ease-out expo — matches the timingCurve used for non-lofi modifiers.
        let eased = 1.0 - pow(2.0, -10.0 * t)
        return morphFrom + (morphTo - morphFrom) * CGFloat(eased)
    }

    /// Drive mode transition to an absolute target. No-op if already there so
    /// we can safely call this from audio-state change observers without
    /// fighting the user's in-flight tap. Preserves mid-flight expansion so
    /// rapid play/pause stays smooth.
    private func setMode(toSmall: Bool) {
        guard isSmall != toSmall else { return }
        let now = Date()
        let current = currentExpansion(now: now)
        morphFrom = current
        morphTo = toSmall ? 0.0 : 1.0
        morphStart = now
        withAnimation(toggleAnim) { isSmall = toSmall }
    }

    var body: some View {
        GeometryReader { geo in
            let specSize: CGFloat = min(geo.size.width - 60, 300)

            ZStack {
                // v1.2.1: cool-axis base; matches ContentView root.
                FogTokens.bgDeep
                    .ignoresSafeArea()

                // v1.2.1 big-mode stage: Fog City Nocturne 夜色渐变。
                // 顶部 accentIndigo 微光（远处夜空的城市光晕）→ 中段 bgDeep →
                // 底部 bgSurface 浅一档（地平线 / 地板反光）。幅度克制到
                // lightness 差 < 0.05，色调仍在 bgDeep 同族——不和 visualizer
                // 前景抢戏，消解大图一整片死色的闷感。小图模式时 opacity=0
                // 回到纯 bgDeep 的"一片黑夜"基底。
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
                .opacity(isSmall ? 0 : 1)
                .allowsHitTesting(false)

                if supportsMorph(state.selectedVisualizer) {
                    morphContent(geo: geo)
                } else {
                    crossfadeContent(geo: geo, specSize: specSize)
                }

                // v1.3 · 横滑 Crossfade legacy 层（切换瞬间覆盖 400ms 淡出）
                if let legacy = crossfadeLegacy {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                        legacyVisualizer(
                            style: legacy.0,
                            spectrumData: state.audioEngine.spectrumData,
                            geoSize: geo.size
                        )
                    }
                    .opacity(crossfadeOpacity)
                    .allowsHitTesting(false)
                    .transition(.identity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .offset(x: bounceOffsetX, y: bounceOffsetY)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    if abs(h) > abs(v) {
                        if h > swipeThreshold { switchChannelSwipe(by: -1) }
                        else if h < -swipeThreshold { switchChannelSwipe(by: +1) }
                    } else {
                        if v > swipeThreshold { switchStyle(by: -1) }
                        else if v < -swipeThreshold { switchStyle(by: +1) }
                    }
                }
        )
        .overlay(alignment: .bottomLeading) { detailsButton }
        .overlay(alignment: .bottomTrailing) { settingsButton }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            displayStyleName = state.selectedStyle?.name ?? ""
            displayStyle = state.selectedStyle
        }
        .onChange(of: state.currentChannel) { old, new in
            // v1.3 · Crossfade：state 已 update 到 new，legacy 用 old.visualizer 构造。
            crossfadeLegacy = (old.visualizer, displayStyle, old)
            crossfadeOpacity = 1.0
            withAnimation(.easeInOut(duration: crossfadeDuration)) {
                crossfadeOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeDuration + 0.05) {
                crossfadeLegacy = nil
            }
            slideOnChannelChange(from: old, to: new)
        }
        .onChange(of: state.selectedStyle?.id) { _, _ in
            // Direct preset tap (DetailsView) — sync when not animating.
            if nameSlideOffset == 0 && nameOpacity == 1.0 {
                displayStyleName = state.selectedStyle?.name ?? ""
                displayStyle = state.selectedStyle
            }
        }
        .onChange(of: state.audioEngine.isPlaying) { _, playing in
            // Auto: play → big pose, pause → small pose.
            // Reuses the morph tween so transition is continuous even if the
            // user toggled mid-flight via tap.
            setMode(toSmall: !playing)
        }
    }

    private func slideOnChannelChange(from old: Channel, to new: Channel) {
        let channels = Channel.all
        let oldIdx = channels.firstIndex(of: old) ?? 0
        let newIdx = channels.firstIndex(of: new) ?? 0
        let forward = newIdx >= oldIdx

        let slideOut: CGFloat = forward ? -80 : 80
        let slideIn: CGFloat = forward ? 80 : -80

        withAnimation(.easeIn(duration: 0.12)) {
            nameSlideOffset = slideOut
            nameOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            displayStyleName = state.selectedStyle?.name ?? ""
            displayStyle = state.selectedStyle
            nameSlideOffset = slideIn
            withAnimation(.easeOut(duration: 0.18)) {
                nameSlideOffset = 0
                nameOpacity = 1
            }
        }
    }

    /// v1.3 · 纵滑切 style — 文字纵向滑出/滑入，visualizer 本体不动。
    /// direction: +1 = 向上滑（切下一个）, -1 = 向下滑（切上一个）。
    private func slideOnStyleChange(direction: Int) {
        let slideOut: CGFloat = direction > 0 ? -60 : 60
        let slideIn: CGFloat = direction > 0 ? 60 : -60

        withAnimation(.easeIn(duration: 0.12)) {
            nameSlideOffsetY = slideOut
            nameOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            displayStyleName = state.selectedStyle?.name ?? ""
            displayStyle = state.selectedStyle
            nameSlideOffsetY = slideIn
            withAnimation(.easeOut(duration: 0.18)) {
                nameSlideOffsetY = 0
                nameOpacity = 1
            }
        }
    }

    /// v1.3 · 纵滑：切到当前频道 orderedStyles 的上/下一个 style。
    /// 撞头/撞尾 rubber-band 弹回。
    private func switchStyle(by delta: Int) {
        let list = state.orderedStyles(for: state.currentChannel)
        guard !list.isEmpty else { return }
        let currentId = state.selectedStyle?.id
        let idx = list.firstIndex(where: { $0.id == currentId }) ?? 0
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < list.count else {
            rubberBand(vertical: true, delta: delta)
            return
        }
        state.selectStyle(list[newIdx])
        slideOnStyleChange(direction: delta)
    }

    /// v1.3 · 横滑：切到 Channel.all 的上/下一个 channel。
    /// Crossfade 动画由 slideOnChannelChange + Task 7 双层渲染承担。
    private func switchChannelSwipe(by delta: Int) {
        let channels = Channel.all
        let idx = channels.firstIndex(of: state.currentChannel) ?? 0
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < channels.count else {
            rubberBand(vertical: false, delta: delta)
            return
        }
        state.switchToChannel(channels[newIdx])
    }

    /// v1.3 · 撞墙 rubber-band — spring 弹回。
    private func rubberBand(vertical: Bool, delta: Int) {
        let bounce: CGFloat = delta > 0 ? -30 : 30
        if vertical {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                bounceOffsetY = bounce
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring()) { bounceOffsetY = 0 }
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                bounceOffsetX = bounce
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring()) { bounceOffsetX = 0 }
            }
        }
    }

    // MARK: - Crossfade content (non-lofi channels)

    @ViewBuilder
    private func crossfadeContent(geo: GeometryProxy, specSize: CGFloat) -> some View {
        if isSmall {
            VStack(spacing: 0) {
                Spacer()

                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                    smallVisualizer(
                        for: state.selectedVisualizer,
                        spectrumData: state.audioEngine.spectrumData
                    )
                }
                .frame(width: specSize, height: specSize)

                Spacer().frame(height: 44)

                bottomOverlay

                Spacer().frame(height: 0)

                transportControls

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        } else {
            ZStack {
                SpectrumCarouselView(state: state, showDots: false, density: 2)
                    .frame(width: geo.size.width, height: geo.size.height)

                VStack(spacing: 0) {
                    Spacer()

                    bottomOverlay

                    Spacer().frame(height: 32)

                    transportControls

                    Spacer().frame(height: 48)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Unified morph content (single full-screen canvas, body-to-body morph)
    //
    // 适用于支持 expansion 参数的 5 个 visualizer —— LofiTape/Oscilloscope/
    // Liquor/Ember/Matrix。每帧基于时间 tween 采样 expansion 驱动同一个画布，
    // 不做双层 crossfade。

    private func supportsMorph(_ style: VisualizerStyle) -> Bool {
        switch style {
        case .lofiTape, .oscilloscope, .liquor, .ember, .matrix,
             .firefly, .letters, .drawer, .nightWindow, .vinylBooth:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private func morphContent(geo: GeometryProxy) -> some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                morphVisualizer(
                    for: state.selectedVisualizer,
                    spectrumData: state.audioEngine.spectrumData,
                    expansion: currentExpansion(now: ctx.date)
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)

            VStack(spacing: 0) {
                Spacer()

                bottomOverlay

                Spacer().frame(height: isSmall ? 28 : 32)

                transportControls

                Spacer().frame(height: isSmall ? 80 : 48)
            }
            .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private func morphVisualizer(for style: VisualizerStyle, spectrumData: [Float], expansion: CGFloat) -> some View {
        switch style {
        case .lofiTape:
            LofiTapeView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .oscilloscope:
            OscilloscopeView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .liquor:
            LiquorView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .ember:
            EmberView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .matrix:
            MatrixView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .firefly:
            FireflyJarView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .letters:
            LetterRackView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .drawer:
            DrawerView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .nightWindow:
            NightWindowView(spectrumData: spectrumData, density: 2, expansion: expansion)
        case .vinylBooth:
            VinylBoothView(spectrumData: spectrumData, density: 2, expansion: expansion)
        default:
            // 不走 morph 路径的 visualizer 已在上层被 supportsMorph 过滤掉
            EmptyView()
        }
    }

    // MARK: - Shared bottom overlay (name + DNA)

    private var bottomOverlay: some View {
        VStack(spacing: 10) {
            if let style = displayStyle {
                musicDNA(style: style)
                    .offset(x: nameSlideOffset, y: nameSlideOffsetY)
                    .opacity(nameOpacity)
            }

            // v1.2.1: immersive channel/style title — now display-sm (28pt).
            // Previous v1.2 used FogTheme.display(24, .light); this lands the
            // CEO-requested +2pt bump (to 28pt) via FogType scale token, and
            // at the same time moves from light-weight Unbounded to medium to
            // keep readability at the new size on dark Fog bg.
            Text(displayStyleName)
                .fog(.displaySm)
                .foregroundStyle(FogTokens.textPrimary)
                .offset(x: nameSlideOffset, y: nameSlideOffsetY)
                .opacity(nameOpacity)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Corner Buttons (v1.3)

    private var detailsButton: some View {
        Button(action: onTapDetails) {
            Image(systemName: "list.bullet")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(FogTokens.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(FogTokens.bgSurface.opacity(0.55)))
                .overlay(Circle().stroke(FogTokens.lineHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .padding(.bottom, 12)
        .accessibilityLabel("Details")
    }

    private var settingsButton: some View {
        Button(action: onTapSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(FogTokens.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(FogTokens.bgSurface.opacity(0.55)))
                .overlay(Circle().stroke(FogTokens.lineHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 12)
        .padding(.bottom, 12)
        .accessibilityLabel("Settings")
    }

    // MARK: - Transport (ported from DetailsView)

    private var transportControls: some View {
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

    // MARK: - Legacy Crossfade visualizer (v1.3)

    /// v1.3 · Crossfade legacy 层 visualizer dispatch — 复用 morphVisualizer expansion=1.0
    /// 渲染旧 channel 的全屏大图；仅在 400ms 淡出期间存在。所有 Channel.visualizer 当前
    /// 实际返回值（lofiTape/oscilloscope/liquor/ember/matrix/nightWindow）都走 morph 路径。
    @ViewBuilder
    private func legacyVisualizer(style: VisualizerStyle, spectrumData: [Float], geoSize: CGSize) -> some View {
        morphVisualizer(for: style, spectrumData: spectrumData, expansion: 1.0)
            .frame(width: geoSize.width, height: geoSize.height)
    }

    // MARK: - Small-mode visualizer dispatch

    @ViewBuilder
    private func smallVisualizer(for style: VisualizerStyle, spectrumData: [Float]) -> some View {
        switch style {
        case .horizon:      HorizonView(spectrumData: spectrumData, density: 1)
        case .ringPulse:    RingPulseView(spectrumData: spectrumData, density: 1)
        case .terrain:      TerrainView(spectrumData: spectrumData, density: 1)
        case .rainfall:     RainfallView(spectrumData: spectrumData, density: 1)
        case .helix:        HelixView(spectrumData: spectrumData, density: 1)
        case .lattice:      LatticeView(spectrumData: spectrumData, density: 1)
        case .prism:        PrismView(spectrumData: spectrumData, density: 1)
        case .matrix:       MatrixView(spectrumData: spectrumData, density: 1)
        case .flora:        FloraView(spectrumData: spectrumData, density: 1)
        case .glitch:       GlitchView(spectrumData: spectrumData, density: 1)
        case .oscilloscope: OscilloscopeView(spectrumData: spectrumData, density: 1)
        case .ember:        EmberView(spectrumData: spectrumData, density: 1)
        case .liquor:       LiquorView(spectrumData: spectrumData, density: 1)
        case .lofiTape:     LofiTapeView(spectrumData: spectrumData, density: 1)
        case .lofiPad:      LofiPadView(spectrumData: spectrumData, density: 1)
        case .lofiBlinds:   LofiBlindsView(spectrumData: spectrumData, density: 1)
        case .firefly:      FireflyJarView(spectrumData: spectrumData, density: 1)
        case .letters:      LetterRackView(spectrumData: spectrumData, density: 1)
        case .drawer:       DrawerView(spectrumData: spectrumData, density: 1)
        case .nightWindow:  NightWindowView(spectrumData: spectrumData, density: 1)
        case .vinylBooth:   VinylBoothView(spectrumData: spectrumData, density: 1)
        }
    }

    // MARK: - Music DNA

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
            if promptLower.contains(word) {
                tags.append(word)
                break
            }
        }

        let instruments = ["piano", "guitar", "saxophone", "bass", "drums", "synth",
                          "flute", "cello", "violin", "Rhodes", "harmonica", "harp",
                          "organ", "trumpet", "vibraphone"]
        for inst in instruments {
            if promptLower.contains(inst.lowercased()) {
                tags.append(inst.lowercased())
                break
            }
        }

        if state.bpm > 0 {
            tags.append("\(state.bpm)bpm")
        }

        return tags
    }

}

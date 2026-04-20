import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState

    // Slide-on-channel-swipe plumbing — mirrors ContentView's pattern so the
    // immersive page overlay tracks the same horizontal gesture the carousel
    // already animates.
    @State private var nameSlideOffset: CGFloat = 0
    @State private var nameOpacity: Double = 1.0
    @State private var displayStyleName: String = ""
    @State private var displayStyle: MoodStyle? = nil

    // v1.2.1: the v1.1.1 big↔small tap toggle is gone. Visualizers stay in
    // their scene pose at full-screen at all times — the pause hint is now a
    // breathing-rate shift (see BreathingModifier) rather than a size change.
    // expansion is hard-pinned to 1.0 (scene pose) and all morphStart /
    // toggleMode / setMode plumbing has been retired.

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // v1.2.1: cool-axis base; matches ContentView root.
                FogTokens.bgDeep
                    .ignoresSafeArea()

                if supportsMorph(state.selectedVisualizer) {
                    morphContent(geo: geo)
                } else {
                    crossfadeContent(geo: geo)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            displayStyleName = state.selectedStyle?.name ?? ""
            displayStyle = state.selectedStyle
        }
        .onChange(of: state.currentChannel) { old, new in
            slideOnChannelChange(from: old, to: new)
        }
        .onChange(of: state.selectedStyle?.id) { _, _ in
            // Direct preset tap (DetailsView) — sync when not animating.
            if nameSlideOffset == 0 && nameOpacity == 1.0 {
                displayStyleName = state.selectedStyle?.name ?? ""
                displayStyle = state.selectedStyle
            }
        }
        // v1.2.1: onChange(of: isPlaying) used to trigger setMode(toSmall:!playing)
        // which pushed the visualizer down to a thumbnail. That behaviour broke
        // immersion on pause, so the observer is gone — BreathingModifier alone
        // carries the visual state.
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

    // MARK: - Crossfade content (non-lofi channels)
    //
    // v1.2.1: always full-screen. The v1.1.1 small-mode (300pt rounded card
    // at top of screen) was the thumbnail-on-pause behavior that v1.2.1
    // retired — it broke immersion. Tap-to-toggle is also gone: visualizers
    // are objects, not UI widgets you can shrink.

    @ViewBuilder
    private func crossfadeContent(geo: GeometryProxy) -> some View {
        ZStack {
            SpectrumCarouselView(state: state, showDots: false, density: 2)
                .frame(width: geo.size.width, height: geo.size.height)
                .breathing(isPlaying: state.audioEngine.isPlaying)
                .contentShape(Rectangle())
                .gesture(channelSwipe)

            VStack(spacing: 0) {
                Spacer()

                bottomOverlay

                Spacer().frame(height: 32)

                transportControls

                Spacer().frame(height: 48)
            }
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
            // v1.2.1: expansion is pinned to 1.0 (scene pose) at all times.
            // Before, it tweened 0↔1 driven by play/pause — the "bare object
            // on pause" was part of the thumbnail behavior that got retired.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
                morphVisualizer(
                    for: state.selectedVisualizer,
                    spectrumData: state.audioEngine.spectrumData,
                    expansion: 1.0
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .breathing(isPlaying: state.audioEngine.isPlaying)
            .contentShape(Rectangle())
            .gesture(channelSwipe)

            VStack(spacing: 0) {
                Spacer()

                bottomOverlay

                Spacer().frame(height: 32)

                transportControls

                Spacer().frame(height: 48)
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
                    .offset(x: nameSlideOffset)
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
                .offset(x: nameSlideOffset)
                .opacity(nameOpacity)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Transport (ported from DetailsView)

    private var transportControls: some View {
        HStack(spacing: 40) {
            Button {
                state.previousStyle()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(FogTokens.textSecondary)
            }
            .buttonStyle(.plain)

            Button {
                state.togglePlayPause()
            } label: {
                ZStack {
                    // v1.2.1: chrome on cool axis. Dimmer fill, same hairline.
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

            Button {
                state.nextStyle()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(FogTokens.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Channel swipe
    //
    // v1.2.1: small-mode dispatch (smallVisualizer) was retired along with
    // the thumbnail-on-pause behavior. Full-screen is the only mode, driven
    // by SpectrumCarouselView (crossfade path) or morphVisualizer at
    // expansion=1 (morph path).

    /// 横滑换频道：只在横向 dominant 且 > 30pt 时触发。
    /// minimumDistance: 20 是关键 —— 低于这个阈值 SwiftUI 不认领 touch，
    /// VerticalPageView 的纵向 pan 可以抢先。tap 用独立的 onTapGesture
    /// 承载，tap 和 drag 因阈值差（20pt）天然互斥，不会重复触发。
    private var channelSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height

                // 只响应横向 dominant 的滑动。
                guard abs(dx) > abs(dy) else { return }
                guard abs(dx) > 30 else { return }

                let channels = Channel.all
                let currentIdx = channels.firstIndex(of: state.currentChannel) ?? 0
                let newIdx: Int
                if dx < 0 {
                    newIdx = min(currentIdx + 1, channels.count - 1)
                } else {
                    newIdx = max(currentIdx - 1, 0)
                }
                guard newIdx != currentIdx else { return }
                state.switchToChannel(channels[newIdx])
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

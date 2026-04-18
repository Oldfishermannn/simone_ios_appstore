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

    /// v1.1.1: tap the spectrum to toggle big (full-screen) ↔ small (rounded card).
    /// Default is big; small mode shows a card-sized spectrum at top.
    @State private var isSmall: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                if isSmall {
                    // Small mode — 三元素垂直居中，spectrum 不播放时显示静态帧。
                    VStack(spacing: 0) {
                        Spacer()

                        let specSize: CGFloat = min(geo.size.width - 60, 300)

                        // 小图模式：每个频道画自己的 visualizer（和大图一致）。
                        // 模式：TimelineView 外层驱动帧，@ViewBuilder 函数内做 switch —
                        // 这个组合 SpectrumCarouselView 已验证可行；之前试过把 switch 直接
                        // 写在 TimelineView closure 里或套 AnyView，都会导致 Canvas 不渲染。
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                            smallVisualizer(
                                for: state.selectedVisualizer,
                                spectrumData: state.audioEngine.spectrumData
                            )
                        }
                        .frame(width: specSize, height: specSize)
                        .contentShape(Rectangle())
                        .gesture(spectrumTapOrSwipe)

                        Spacer().frame(height: 44)

                        VStack(spacing: 8) {
                            if let style = displayStyle {
                                musicDNA(style: style)
                                    .offset(x: nameSlideOffset)
                                    .opacity(nameOpacity)
                            }

                            Text(displayStyleName)
                                .font(FogTheme.display(24, weight: .light))
                                .tracking(FogTheme.trackDisplay)
                                .foregroundStyle(FogTheme.inkPrimary)
                                .offset(x: nameSlideOffset)
                                .opacity(nameOpacity)
                        }
                        .allowsHitTesting(false)

                        Spacer().frame(height: 28)

                        transportControls

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Big mode — full-screen spectrum + bottom overlay
                    SpectrumCarouselView(state: state, showDots: false, density: 2)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { isSmall = true }
                        }

                    VStack(spacing: 0) {
                        Spacer()

                        VStack(spacing: 10) {
                            if let style = displayStyle {
                                musicDNA(style: style)
                                    .offset(x: nameSlideOffset)
                                    .opacity(nameOpacity)
                            }

                            Text(displayStyleName)
                                .font(FogTheme.display(24, weight: .light))
                                .tracking(FogTheme.trackDisplay)
                                .foregroundStyle(FogTheme.inkPrimary)
                                .offset(x: nameSlideOffset)
                                .opacity(nameOpacity)
                        }
                        .allowsHitTesting(false)

                        Spacer().frame(height: 32)

                        transportControls

                        Spacer().frame(height: 48)
                    }
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

    // MARK: - Transport (ported from DetailsView)

    private var transportControls: some View {
        HStack(spacing: 40) {
            Button {
                state.previousStyle()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Button {
                state.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.audioEngine.isPlaying)

            Button {
                state.nextStyle()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
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
        }
    }

    // MARK: - Channel swipe (小图模式左右滑动换频道)

    /// 单一 DragGesture 统一处理 tap（位移 < 10pt, 切换 big/small）和
    /// 横滑（位移 > 30pt 且横向 dominant, 换频道）。避免 onTapGesture 与
    /// DragGesture 混用时两者同时识别导致"滑一下又换频道又切大图"的 bug。
    private var spectrumTapOrSwipe: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let dist = hypot(dx, dy)

                // Tap（几乎没位移）— 切换 big/small。
                if dist < 10 {
                    withAnimation(.easeInOut(duration: 0.25)) { isSmall = false }
                    return
                }

                // 只响应横向 dominant 的滑动，避免和纵向 VerticalPageView 冲突。
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

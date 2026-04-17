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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                // Full-screen spectrum (background)
                SpectrumCarouselView(state: state, showDots: false, density: 2)
                    .frame(width: geo.size.width, height: geo.size.height)

                // Overlay UI
                VStack(spacing: 0) {
                    Spacer()

                    // Music DNA — reads displayStyle so tags slide with the name
                    if let style = displayStyle {
                        musicDNA(style: style)
                            .offset(x: nameSlideOffset)
                            .opacity(nameOpacity)
                        Spacer().frame(height: 10)
                    }

                    // Style name (effectively the channel name on immersive — it
                    // flips to the new channel's first preset on swipe).
                    Text(displayStyleName)
                        .font(.system(size: 22, weight: .light))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.65))
                        .offset(x: nameSlideOffset)
                        .opacity(nameOpacity)

                    Spacer().frame(height: 100)
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

    // MARK: - Music DNA

    private func musicDNA(style: MoodStyle) -> some View {
        let tags = extractDNA(from: style)
        return HStack(spacing: 0) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text(" · ")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.12))
                }
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
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

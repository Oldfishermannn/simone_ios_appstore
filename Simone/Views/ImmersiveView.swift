import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState

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

                    // Music DNA
                    if let style = state.selectedStyle {
                        musicDNA(style: style)
                        Spacer().frame(height: 10)
                    }

                    // Style name
                    Text(state.selectedStyle?.name ?? "")
                        .font(.system(size: 22, weight: .light))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.65))

                    Spacer().frame(height: 100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
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

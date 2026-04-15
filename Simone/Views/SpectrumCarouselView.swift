import SwiftUI

struct SpectrumCarouselView: View {
    @Bindable var state: AppState
    var showDots: Bool = true

    @State private var scrollPosition: Int?
    @State private var dotsVisible: Bool = true
    @State private var hideTask: Task<Void, Never>?

    private let styles = VisualizerStyle.allCases

    private var currentIndex: Int {
        scrollPosition ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                let spectrumData = state.audioEngine.spectrumData

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(styles.enumerated()), id: \.element.id) { index, style in
                            visualizerView(for: style, spectrumData: spectrumData)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPosition)
                .onChange(of: scrollPosition) { _, newValue in
                    if let idx = newValue, idx >= 0, idx < styles.count {
                        state.selectedVisualizer = styles[idx]
                    }
                }
            }
            .clipped()

            if showDots {
                HStack(spacing: 4) {
                    ForEach(Array(styles.enumerated()), id: \.element.id) { index, _ in
                        Circle()
                            .fill(
                                index == currentIndex
                                    ? MorandiPalette.rose
                                    : Color.white.opacity(0.3)
                            )
                            .frame(width: index == currentIndex ? 6 : 5,
                                   height: index == currentIndex ? 6 : 5)
                    }
                }
                .padding(.top, 8)
                .opacity(dotsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.6), value: dotsVisible)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
            }
        }
        .onAppear {
            let idx = styles.firstIndex(of: state.selectedVisualizer) ?? 0
            scrollPosition = idx
            scheduleDotsFade()
        }
        .onChange(of: scrollPosition) { _, _ in
            dotsVisible = true
            scheduleDotsFade()
        }
    }

    private func scheduleDotsFade() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            dotsVisible = false
        }
    }

    @ViewBuilder
    private func visualizerView(for style: VisualizerStyle, spectrumData: [Float]) -> some View {
        switch style {
        case .aurora:
            AuroraView(spectrumData: spectrumData)
        case .horizon:
            HorizonView(spectrumData: spectrumData)
        case .waveform:
            WaveformView(spectrumData: spectrumData)
        case .cascade:
            CascadeView(spectrumData: spectrumData)
        case .constellation:
            ConstellationView(spectrumData: spectrumData)
        case .orbital:
            OrbitalView(spectrumData: spectrumData)
        case .pulseBubble:
            PulseBubbleView(spectrumData: spectrumData)
        case .ringPulse:
            RingPulseView(spectrumData: spectrumData)
        }
    }
}

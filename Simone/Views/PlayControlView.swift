import SwiftUI

struct PlayControlView: View {
    @Bindable var state: AppState

    private var isPinned: Bool {
        guard let style = state.selectedStyle else { return false }
        return state.pinnedStyles.contains(where: { $0.id == style.id })
    }

    var body: some View {
        HStack(spacing: 0) {
            // Pin / Unpin (heart)
            Button {
                guard let style = state.selectedStyle else { return }
                if isPinned {
                    state.unpinStyle(style)
                } else {
                    state.pinStyle(style)
                }
            } label: {
                Image(systemName: isPinned ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(isPinned ? MorandiPalette.rose : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .frame(width: 44)
            .disabled(state.selectedStyle == nil)

            Spacer()

            // Transport controls
            HStack(spacing: 40) {
                // Previous style
                Button {
                    state.previousStyle()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(state.styleHistory.isEmpty ? 0.2 : 0.6))
                }
                .buttonStyle(.plain)
                .disabled(state.styleHistory.isEmpty)

                // Play / Pause
                Button {
                    state.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )

                        Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.audioEngine.isPlaying)

                // Next style
                Button {
                    state.nextStyle()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Regenerate current style
            Button {
                state.regenerate()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(state.selectedStyle == nil ? 0.2 : 0.4))
            }
            .buttonStyle(.plain)
            .frame(width: 44)
            .disabled(state.selectedStyle == nil)
        }
        .padding(.horizontal, 20)
    }
}

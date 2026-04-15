import SwiftUI

struct PlayControlView: View {
    @Bindable var state: AppState

    var body: some View {
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
                        .fill(
                            LinearGradient(
                                colors: [MorandiPalette.rose, MorandiPalette.mauve],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: MorandiPalette.rose.opacity(0.3), radius: 8, y: 4)

                    Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.23, green: 0.22, blue: 0.21))
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
    }
}

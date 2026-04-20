import SwiftUI

struct PlayControlView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 40) {
            // Previous style (within category)
            Button {
                state.previousStyle()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(FogTokens.textSecondary)
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                state.togglePlayPause()
            } label: {
                ZStack {
                    // v1.2.1: cool-axis surface + hairline stroke.
                    Circle()
                        .fill(FogTokens.bgSurface.opacity(0.5))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .stroke(FogTokens.lineHairline, lineWidth: 1)
                        )

                    Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(FogTokens.textPrimary.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.audioEngine.isPlaying)

            // Next style (within category)
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
}

import SwiftUI

struct MiniPlayerView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            // v1.2.1: Mini spectrum thumbnail — was rose-on-warm-grey, now
            // indigo-glow on bgDeep. Same shape, different temperatu re.
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    RadialGradient(
                        colors: [FogTokens.accentIndigo.opacity(0.28), FogTokens.bgDeep],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 36, height: 36)
                .overlay {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            let height: CGFloat = state.audioEngine.isPlaying
                                ? CGFloat([8, 14, 10][i])
                                : CGFloat([4, 6, 4][i])
                            RoundedRectangle(cornerRadius: 1)
                                .fill(FogTokens.accentIndigo.opacity(0.7))
                                .frame(width: 2.5, height: height)
                                .animation(.easeInOut(duration: 0.3), value: state.audioEngine.isPlaying)
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.selectedStyle?.name ?? "Simone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FogTokens.textPrimary.opacity(0.88))
                    .lineLimit(1)

                Text(state.audioEngine.isPlaying ? "Now Playing" : "Paused")
                    .font(.system(size: 10))
                    .foregroundStyle(FogTokens.textTertiary)
            }

            Spacer()

            Button {
                state.togglePlayPause()
            } label: {
                Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(FogTokens.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FogTokens.bgSurface.opacity(0.5))
        )
    }
}

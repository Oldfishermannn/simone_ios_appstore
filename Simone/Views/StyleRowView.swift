import SwiftUI

struct StyleRowView: View {
    let style: MoodStyle
    let isPlaying: Bool
    let isFavorite: Bool
    let showFavoriteButton: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: FogTheme.spaceMD) {
                // Playing indicator — small dot, only visible when active.
                Circle()
                    .fill(isPlaying ? FogTheme.accent : Color.clear)
                    .frame(width: 5, height: 5)

                Text(style.name)
                    .font(FogTheme.display(15, weight: isPlaying ? .regular : .light))
                    .tracking(FogTheme.trackDisplay)
                    .foregroundStyle(isPlaying ? FogTheme.inkPrimary : FogTheme.inkSecondary)
                    .lineLimit(1)

                Spacer()

                if showFavoriteButton {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundStyle(isFavorite ? FogTheme.accent : FogTheme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FogTheme.spaceSM)
            .padding(.vertical, FogTheme.spaceMD)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(FogTheme.hairline)
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

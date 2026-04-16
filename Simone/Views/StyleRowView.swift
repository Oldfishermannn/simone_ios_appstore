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
            HStack(spacing: 10) {
                Text(style.name)
                    .font(.system(size: 15, weight: isPlaying ? .semibold : .regular))
                    .foregroundStyle(isPlaying ? MorandiPalette.rose : .white.opacity(0.65))
                    .lineLimit(1)

                Spacer()

                if showFavoriteButton {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(isFavorite ? MorandiPalette.rose : .white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? MorandiPalette.rose.opacity(0.08) : Color.white.opacity(0.025))
            )
        }
        .buttonStyle(.plain)
    }
}

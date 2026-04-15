import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                SpectrumCarouselView(state: state, showDots: false)
                    .frame(width: size, height: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBarHidden(true)
    }
}

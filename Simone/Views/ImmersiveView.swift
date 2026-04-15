import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                SpectrumCarouselView(state: state, showDots: false, density: 2)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

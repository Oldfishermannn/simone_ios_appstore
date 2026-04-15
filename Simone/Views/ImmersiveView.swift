import SwiftUI

struct ImmersiveView: View {
    var state: AppState

    var body: some View {
        ZStack {
            Color(red: 0.165, green: 0.165, blue: 0.18)
                .ignoresSafeArea()

            ImmersiveCanvasView(spectrumData: state.audioEngine.spectrumData)
                .ignoresSafeArea()
        }
        .statusBarHidden(true)
    }
}

import SwiftUI

struct NebulaView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let cloudCount = density > 1 ? 20 : 12
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            for i in 0..<cloudCount {
                let t = CGFloat(i) / CGFloat(cloudCount)
                let bin = min(Int(Float(t) * Float(binCount - 1)), binCount - 1)
                let value = CGFloat(spectrumData[bin])

                let angle = t * 2 * .pi
                let baseR = min(w, h) * 0.15 * (1 + t)
                let r = baseR + value * min(w, h) * 0.12

                let x = cx + r * cos(angle) * 0.8
                let y = cy + r * sin(angle) * 0.6

                let blobSize = 30 + value * 60
                let color = MorandiPalette.color(at: i)
                let rect = CGRect(x: x - blobSize / 2, y: y - blobSize / 2, width: blobSize, height: blobSize)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.06 + Double(value) * 0.12)))

                // Inner core
                let coreSize = blobSize * 0.3
                let coreRect = CGRect(x: x - coreSize / 2, y: y - coreSize / 2, width: coreSize, height: coreSize)
                context.fill(Path(ellipseIn: coreRect), with: .color(color.opacity(0.15 + Double(value) * 0.25)))
            }
        }
    }
}

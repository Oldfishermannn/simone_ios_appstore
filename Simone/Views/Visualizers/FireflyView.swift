import SwiftUI

struct FireflyView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let count = density > 1 ? 60 : 36
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            for i in 0..<count {
                let t = Float(i) / Float(count)
                let bin = min(Int(t * Float(binCount - 1)), binCount - 1)
                let value = CGFloat(spectrumData[bin])

                // Deterministic position from index (seeded pattern)
                let golden = 1.618033988749895
                let theta = Double(i) * golden * 2 * .pi
                let radius = sqrt(Double(i) / Double(count)) * Double(min(w, h)) * 0.45
                let x = w / 2 + CGFloat(radius * cos(theta))
                let y = h / 2 + CGFloat(radius * sin(theta)) * 0.7

                let color = MorandiPalette.color(at: i % 5)
                let brightness = 0.05 + Double(value) * 0.6

                // Glow
                let glowSize = 8 + value * 20
                let glowRect = CGRect(x: x - glowSize / 2, y: y - glowSize / 2, width: glowSize, height: glowSize)
                context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(brightness * 0.15)))

                // Core
                let coreSize = 2 + value * 4
                let coreRect = CGRect(x: x - coreSize / 2, y: y - coreSize / 2, width: coreSize, height: coreSize)
                context.fill(Path(ellipseIn: coreRect), with: .color(color.opacity(brightness)))
            }
        }
    }
}

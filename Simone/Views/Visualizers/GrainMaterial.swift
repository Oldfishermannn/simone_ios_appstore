import SwiftUI

/// Grain dust material — shared particle primitive for Signature Visualizers (v1.4a Part 3).
///
/// Draws a small number of tiny particles drifting slowly downward across the
/// canvas. Meant to composite behind a signature's main subject as *ambience*,
/// never as the focal point. Not audio-reactive on its own; the parent view
/// controls density multiplier.
///
/// Design intent (Lo-fi first, reused by future 4 channels):
/// - Restrained count (~10 particles) — ambience, not confetti
/// - Mixed sizes 0.8–1.6pt to read as physical dust
/// - Slow descent 5–9 px/sec — "air is still but time passes"
/// - No glow, no pulse, no halo — CEO has banned breathing UI across Simone
/// - Particle layout is *deterministic* from a seed so the visual is stable
///   across TimelineView redraws (only y advances with time)
struct GrainMaterial {
    let tint: Color
    let sizeRange: ClosedRange<CGFloat>
    let fallSpeedRange: ClosedRange<CGFloat>

    private let baseX: [CGFloat]
    private let baseY: [CGFloat]
    private let sizes: [CGFloat]
    private let speeds: [CGFloat]

    var count: Int { baseX.count }

    init(
        count: Int,
        tint: Color,
        sizeRange: ClosedRange<CGFloat>,
        fallSpeedRange: ClosedRange<CGFloat>,
        seed: UInt64
    ) {
        self.tint = tint
        self.sizeRange = sizeRange
        self.fallSpeedRange = fallSpeedRange

        // splitmix64 — deterministic stream, no Foundation RNG dependency.
        var state: UInt64 = seed | 1
        func next01() -> CGFloat {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            z = z ^ (z >> 31)
            return CGFloat(Double(z & 0xFFFFFF) / Double(0x1000000))
        }

        var bx: [CGFloat] = [], by: [CGFloat] = []
        var sz: [CGFloat] = [], sp: [CGFloat] = []
        bx.reserveCapacity(count); by.reserveCapacity(count)
        sz.reserveCapacity(count); sp.reserveCapacity(count)
        let sizeSpan = sizeRange.upperBound - sizeRange.lowerBound
        let speedSpan = fallSpeedRange.upperBound - fallSpeedRange.lowerBound
        for _ in 0..<max(0, count) {
            bx.append(next01())
            by.append(next01())
            sz.append(sizeRange.lowerBound + next01() * sizeSpan)
            sp.append(fallSpeedRange.lowerBound + next01() * speedSpan)
        }
        self.baseX = bx
        self.baseY = by
        self.sizes = sz
        self.speeds = sp
    }

    /// Lo-fi preset: 10 玉粉黛 grains, matte, slow.
    static func lofi() -> GrainMaterial {
        GrainMaterial(
            count: 10,
            tint: Color(red: 232/255, green: 200/255, blue: 188/255).opacity(0.22),
            sizeRange: 0.8...1.6,
            fallSpeedRange: 5.0...9.0,
            seed: 0x10F1C0DECAFE0001
        )
    }

    /// Render grains into the given canvas. `density` multiplies the active
    /// count (1.0 = all baseline particles, 0.9 = 10% fewer, etc.).
    func draw(in ctx: GraphicsContext, size: CGSize, time: TimeInterval, density: CGFloat = 1.0) {
        guard size.width > 0, size.height > 0, count > 0 else { return }
        let active = min(count, max(0, Int((CGFloat(count) * density).rounded())))
        guard active > 0 else { return }

        let wrapH = size.height + 20  // 20pt so particles re-enter from just above the frame
        for i in 0..<active {
            let x = baseX[i] * size.width
            let y0 = baseY[i] * size.height
            let fall = speeds[i]
            var y = (y0 + CGFloat(time) * fall).truncatingRemainder(dividingBy: wrapH)
            if y < 0 { y += wrapH }
            y -= 10

            let sz = sizes[i]
            let rect = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)
            ctx.fill(Path(ellipseIn: rect), with: .color(tint))
        }
    }
}

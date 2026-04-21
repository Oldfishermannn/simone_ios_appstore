import SwiftUI

/// Lo-fi Signature Visualizer (v1.4a Part 3).
///
/// Channel totem = **cassette shell**. Restrained, hand-drawn feel.
/// Reused primitives: `GrainMaterial` (dust particles, M1).
///
/// Composition (minimal by contract — CEO banned breathing UI):
/// 1. Shell — rounded-rect outline of a 90-minute cassette, no deck scene
/// 2. Two reels — rotating hubs, omega driven by bass
/// 3. Tape ribbon — single thin oscope-like line spanning the strap window,
///    amplitude bound so it never escapes the rectangle (the "束缚" in 束缚波形)
/// 4. Grains — 10 玉粉黛 dust particles drifting ambient
///
/// Audio binding is FFT-bins only (same contract as every other visualizer):
/// `spectrumData` is a power-of-two-bin array from AudioEngine. We split into
/// thirds for lo/mid/hi energy and reuse the idle blend trick LofiTapeView uses.
///
/// Not a replacement for `LofiTapeView` — that's the full deck scene kept in
/// the Classic Collection. Signature is a separate axis via
/// `AppState.visualizationMode` (M3).
struct LofiSignatureView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// Extra multiplier from Evolve (M4). 1.0 = neutral; 0.9–1.1 typical.
    var densityScale: CGFloat = 1.0
    /// Extra multiplier from Evolve (M4) on reel rotation speed.
    var omegaScale: CGFloat = 1.0

    private let grains = GrainMaterial.lofi()

    // Palette — 玉粉黛 centered, kept local so we don't disturb MorandiPalette.
    // OKLCH-minded but written as sRGB for Canvas interop.
    private let ink        = Color(red:  58/255, green:  48/255, blue:  46/255).opacity(0.92)
    private let inkFaint   = Color(red:  58/255, green:  48/255, blue:  46/255).opacity(0.36)
    private let cream      = Color(red: 232/255, green: 200/255, blue: 190/255)  // 玉粉黛 #e8c8be
    private let creamSoft  = Color(red: 232/255, green: 200/255, blue: 190/255).opacity(0.55)
    private let hub        = Color(red:  72/255, green:  58/255, blue:  54/255).opacity(0.88)
    private let ribbon     = Color(red:  40/255, green:  30/255, blue:  28/255).opacity(0.78)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                render(ctx: ctx,
                       size: size,
                       time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func render(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        let w = size.width, h = size.height
        guard w > 20, h > 20 else { return }

        // --- Spectrum split ---
        let binCount = spectrumData.count
        let thirds = max(1, binCount / 3)
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        if binCount > 0 {
            for i in 0..<thirds { bass += spectrumData[i] }
            for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
            for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
            bass /= Float(thirds)
            mid  /= Float(thirds)
            treble /= Float(max(1, binCount - 2 * thirds))
        }
        let maxV = spectrumData.max() ?? 0
        let idle = max(Float(0), 1 - maxV * 4)
        let bassE = CGFloat(bass   * (1 - idle) + 0.28 * idle)
        let midE  = CGFloat(mid    * (1 - idle) + 0.22 * idle)
        let trebE = CGFloat(treble * (1 - idle))

        // --- Cassette body rect — 60% width, 36% height, centered slightly upper ---
        let bodyW = min(w * 0.62, h * 1.02)
        let bodyH = bodyW * 0.60
        let cx = w * 0.5
        let cy = h * 0.48
        let body = CGRect(x: cx - bodyW / 2, y: cy - bodyH / 2,
                          width: bodyW, height: bodyH)
        let corner = bodyH * 0.10

        drawShell(ctx: ctx, rect: body, corner: corner)
        drawStrap(ctx: ctx, rect: body, corner: corner,
                  waveform: (bassE, midE, trebE), time: time)
        drawReels(ctx: ctx, rect: body, bass: bassE, time: time)
        drawLabel(ctx: ctx, rect: body)

        // Grains — density multiplier fed by Evolve (M4)
        let d = max(0, min(1.3, densityScale))
        grains.draw(in: ctx, size: size, time: time, density: d)
    }

    // MARK: Shell (cassette outline)

    private func drawShell(ctx: GraphicsContext, rect: CGRect, corner: CGFloat) {
        let path = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)
        ctx.fill(path, with: .color(creamSoft))
        ctx.stroke(path, with: .color(ink), lineWidth: 1.2)

        // Inner hairline — a second rounded rect inset 6pt for craft
        let inner = rect.insetBy(dx: 6, dy: 6)
        let innerPath = Path(roundedRect: inner, cornerRadius: max(2, corner - 4),
                             style: .continuous)
        ctx.stroke(innerPath, with: .color(inkFaint), lineWidth: 0.6)
    }

    // MARK: Label — subtle horizontal rules hinting at tape label area
    private func drawLabel(ctx: GraphicsContext, rect: CGRect) {
        let left = rect.minX + rect.width * 0.22
        let right = rect.maxX - rect.width * 0.22
        let y0 = rect.minY + rect.height * 0.18
        for k in 0..<3 {
            let y = y0 + CGFloat(k) * 3.0
            var p = Path()
            p.move(to: CGPoint(x: left, y: y))
            p.addLine(to: CGPoint(x: right, y: y))
            ctx.stroke(p, with: .color(inkFaint), lineWidth: 0.5)
        }
    }

    // MARK: Strap + bound oscope waveform
    //
    // The strap is the dark rectangular window that would hold the tape
    // ribbon. We draw:
    //  - strap rect (dark cream on top, charcoal underneath)
    //  - a single waveform line as the tape itself
    // The waveform is clamped to the strap interior so it never bleeds.
    private func drawStrap(ctx: GraphicsContext,
                           rect: CGRect,
                           corner: CGFloat,
                           waveform: (bass: CGFloat, mid: CGFloat, treble: CGFloat),
                           time: TimeInterval) {
        // Strap geometry: bottom 38% of body, inset sides for reel clearance
        let strapH = rect.height * 0.34
        let strapY = rect.minY + rect.height * 0.56
        let sideInset = rect.width * 0.12
        let strap = CGRect(
            x: rect.minX + sideInset,
            y: strapY,
            width: rect.width - 2 * sideInset,
            height: strapH
        )
        let strapPath = Path(roundedRect: strap,
                             cornerRadius: strapH * 0.12,
                             style: .continuous)
        ctx.fill(strapPath, with: .color(Color(white: 0.08).opacity(0.78)))
        ctx.stroke(strapPath, with: .color(ink), lineWidth: 0.8)

        // --- Waveform (bound oscope line) ---
        // Horizontal center line across the strap. 48 sample points for a
        // stable, low-noise curve. Amplitude capped so the line is contained.
        let sampleN = 48
        let innerLeft = strap.minX + 6
        let innerRight = strap.maxX - 6
        let midY = strap.midY
        let ampBudget = strap.height * 0.40  // ±40% so +budget & -budget always fit

        // Mix of bass + treble drives amplitude; idle stays hairline.
        let amp = max(1.5, min(ampBudget,
                               ampBudget * (0.18 + 0.70 * waveform.bass +
                                            0.35 * waveform.treble)))

        let t = CGFloat(time.truncatingRemainder(dividingBy: 1000))
        var path = Path()
        for i in 0..<sampleN {
            let u = CGFloat(i) / CGFloat(sampleN - 1)
            let x = innerLeft + (innerRight - innerLeft) * u

            // Oscope-like: alternating sign square envelope modulated by
            // slow sine + jitter, per the draft §4.2.
            let sign: CGFloat = (i % 2 == 0) ? 1 : -1
            let envelope = sin(u * .pi)                       // 0 at edges, 1 mid
            let slowMod  = sin(u * 6 + t * 1.2) * 0.35 + 0.65
            let jitter   = sin(u * 37 + t * 3.1) * 0.25
            let yOff = sign * envelope * slowMod * amp
                     + jitter * (1 + waveform.mid) * (amp * 0.18)

            let y = min(max(strap.minY + 4, midY + yOff), strap.maxY - 4)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(cream.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.1, lineCap: .round,
                                      lineJoin: .round))

        // Faint base line behind the waveform for "tape inside window" feel
        var base = Path()
        base.move(to: CGPoint(x: innerLeft, y: midY))
        base.addLine(to: CGPoint(x: innerRight, y: midY))
        ctx.stroke(base, with: .color(ribbon), lineWidth: 0.5)
    }

    // MARK: Reels (two rotating hubs in the upper 2/3 of the body)

    private func drawReels(ctx: GraphicsContext,
                           rect: CGRect,
                           bass: CGFloat,
                           time: TimeInterval) {
        let reelR = rect.height * 0.22
        let reelY = rect.minY + rect.height * 0.38
        let leftX  = rect.minX + rect.width * 0.28
        let rightX = rect.maxX - rect.width * 0.28

        // omega: 0.18 rad/sec idle, up to 0.63 at full bass. Evolve scales it.
        let omega = (0.18 + 0.45 * Double(bass)) * Double(omegaScale)
        let phase = time * omega

        drawReel(ctx: ctx, center: CGPoint(x: leftX, y: reelY),
                 radius: reelR, rotation: phase)
        drawReel(ctx: ctx, center: CGPoint(x: rightX, y: reelY),
                 radius: reelR, rotation: -phase)  // counter-rotating
    }

    private func drawReel(ctx: GraphicsContext,
                          center: CGPoint,
                          radius: CGFloat,
                          rotation: Double) {
        // Outer rim
        let rim = Path(ellipseIn: CGRect(x: center.x - radius,
                                         y: center.y - radius,
                                         width: radius * 2,
                                         height: radius * 2))
        ctx.fill(rim, with: .color(cream.opacity(0.45)))
        ctx.stroke(rim, with: .color(ink), lineWidth: 0.9)

        // Inner hub (rotates)
        let innerR = radius * 0.36
        let innerRect = CGRect(x: center.x - innerR,
                               y: center.y - innerR,
                               width: innerR * 2,
                               height: innerR * 2)
        ctx.fill(Path(ellipseIn: innerRect), with: .color(hub))

        // 6 spokes rotate around the inner hub — the only thing that spins.
        var spokeCtx = ctx
        spokeCtx.translateBy(x: center.x, y: center.y)
        spokeCtx.rotate(by: .radians(rotation))
        let spokeLen = radius * 0.82
        for k in 0..<6 {
            let a = Double(k) * .pi / 3
            var p = Path()
            let x0 = cos(a) * innerR
            let y0 = sin(a) * innerR
            let x1 = cos(a) * spokeLen
            let y1 = sin(a) * spokeLen
            p.move(to: CGPoint(x: x0, y: y0))
            p.addLine(to: CGPoint(x: x1, y: y1))
            spokeCtx.stroke(p, with: .color(inkFaint),
                            style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        }

        // Center pinhole
        let pinR: CGFloat = 1.8
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - pinR, y: center.y - pinR,
                                   width: pinR * 2, height: pinR * 2)),
            with: .color(ink)
        )
    }
}

#Preview {
    LofiSignatureView(
        spectrumData: (0..<64).map { _ in Float.random(in: 0...0.5) }
    )
    .frame(width: 360, height: 500)
    .background(Color(red: 36/255, green: 32/255, blue: 34/255))
}

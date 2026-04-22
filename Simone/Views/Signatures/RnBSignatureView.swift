import SwiftUI

/// R&B Signature — "Whiskey at 2am"
///
/// A crystal rocks tumbler, two ice cubes, bourbon half-full, sitting on
/// an implied dark velvet surface. 3/4 angle, side-lit from off-frame
/// top-right (candle direction).
///
/// Anti-totem render: the Jazz A/B rejection came from 2D cartoon flats —
/// drawn circle + line = "icon," not "object." This view reaches for
/// volume instead: stacked translucent glass layers, liquid meniscus
/// curvature, ice cubes as irregular quads with internal cracks +
/// specular edges, warm caustic spill on the backdrop. No element is a
/// filled silhouette — every surface has at least one highlight and one
/// shadow pass.
///
/// Audio coupling (动而非跳):
///   Bass    → whole glass breathes ±2pt Y + surface meniscus ripples
///   Mid     → ice cubes micro-rotate ±3°
///   Treble  → specular glints flicker on rim + ice edges
///
/// Composition (Fog City Nocturne):
///   ~70% shadow / ~20% mid / ~10% warm accent
///   Glass center at x = 0.48 w (asymmetric, reading-left bias)
///
/// Palette (OKLCH → sRGB, pre-converted):
///   backdrop       ( 12,  8, 10)  near-black warm velvet
///   backdropMid    ( 26, 16, 20)  top-right spill
///   bourbonDeep    ( 68, 32, 12)  bottom-of-glass amber
///   bourbonBody    (140, 72, 28)  mid amber
///   bourbonHot     (220,148, 62)  meniscus highlight
///   glassTint      (220,210,200)@0.10  transparent warm
///   glassRim       (248,232,200)  hot specular
///   iceBody        (200,210,220)@0.38  cool-white translucent
///   iceEdge        (240,240,235)  crystal edge
///   causticAmber   (200,140, 60)@0.22  backdrop spill
struct RnBSignatureView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0
    /// Evolve hook — scales breath amplitude slightly around 1.0.
    var breathBoost: CGFloat = 1.0
    /// Evolve hook — scales specular glint brightness slightly around 1.0.
    var shimmerBoost: CGFloat = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSince1970
            Canvas { gc, size in
                render(gc: gc, size: size, t: t)
            }
        }
    }

    private func render(gc: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Big-mode fade (tabletop reflection + wider caustic + ambient bokeh).
        // smoothstep gives a C1-continuous ramp so nothing pops in as
        // expansion crosses the 30-88% morph window.
        let e: CGFloat = max(0, min(1, expansion))
        let deckAlpha: Double = smoothstep(0.30, 0.88, Double(e))

        // --- Bands (bass / mid / treble) ---
        let binCount = spectrumData.count
        guard binCount > 0 else { return }
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)
        let idleBlend = max(Float(0), 1 - (spectrumData.max() ?? 0) * 4)
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.20 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.18 * idleBlend)
        let trebCG = CGFloat(treble * (1 - idleBlend))

        // --- Palette ---
        let backdrop     = Color(red:  12/255, green:   8/255, blue:  10/255)
        let backdropMid  = Color(red:  26/255, green:  16/255, blue:  20/255)
        // Liquid v5.4: CEO shared a whisky reference — amber/bourbon,
        // not white wine. Pivot back to warm rich amber with proper
        // depth (deep bottom → saturated body → hot gold highlight).
        //   Deep  OKLCH(0.38, 0.12, 55°)  — dark bourbon at glass bottom
        //   Body  OKLCH(0.62, 0.15, 70°)  — saturated amber through body
        //   Hot   OKLCH(0.82, 0.13, 80°)  — bright gold meniscus glint
        let bourbonDeep  = Color(red: 104/255, green:  54/255, blue:  18/255)  // deep bourbon
        let bourbonBody  = Color(red: 190/255, green: 110/255, blue:  40/255)  // amber body
        let bourbonHot   = Color(red: 242/255, green: 186/255, blue:  98/255)  // hot gold highlight
        let glassTint    = Color(red: 220/255, green: 210/255, blue: 200/255)
        let glassRim     = Color(red: 248/255, green: 232/255, blue: 200/255)
        let iceBody      = Color(red: 200/255, green: 210/255, blue: 220/255)
        let iceEdge      = Color(red: 240/255, green: 240/255, blue: 235/255)
        // Caustic matches the liquid — deep amber spill, not pale wheat.
        let causticAmber = Color(red: 210/255, green: 140/255, blue:  58/255)

        // --- 1. Backdrop —
        // 小图：纯黑（CEO 要求），玻璃杯像在虚空中。
        // 大图：暖色 radial spill 用 deckAlpha 淡入 — photographic 暖感留给场景模式。
        gc.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(.black)
        )
        if deckAlpha > 0.01 {
            gc.drawLayer { ctx in
                ctx.opacity = deckAlpha
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: backdropMid.opacity(0.92), location: 0.0),
                            .init(color: backdrop, location: 0.55),
                            .init(color: Color(red: 5/255, green: 3/255, blue: 5/255), location: 1.0)
                        ]),
                        center: CGPoint(x: w * 1.05, y: h * -0.05),
                        startRadius: 0,
                        endRadius: max(w, h) * 1.35
                    )
                )
            }
        }

        // --- 1b. Big-mode: photographic atmosphere, not scene props ---
        //
        // V4.3 rejected: vinyl + candle + bokeh = AI slop (each prop
        // competes, each reads as an icon, composition loses its center).
        //
        // V5 approach (impeccable refined-minimalism): zero new objects.
        // Only three photographic gestures:
        //   1. A deep polished bar plane with NO horizon line (seamless
        //      dark-to-darker merge — the glass sits *on* it but the
        //      boundary is implied by the reflection, not a stripe).
        //   2. A single directional warm rim from off-frame upper-right,
        //      falling off across the canvas in one clean linear sweep
        //      (not a radial halo — directional light feels like a real
        //      light source, radial feels like a vignette filter).
        //   3. Nothing else at this stage. Reflection + shadow are
        //      drawn AFTER the glass is known (see step 3 / step 12).
        if deckAlpha > 0.01 {
            gc.drawLayer { ctx in
                ctx.opacity = deckAlpha

                // 1b-0. Bar back wall + shelves + bottle silhouettes.
                //
                // V5.1: CEO asked for 酒柜 in big mode. Restraint rule
                // (impeccable): shelves read as CONTEXT, not props —
                // bottles are low-contrast silhouettes, never icons.
                // The glass at x~0.48w occludes the middle shelf span,
                // so bottles cluster at the left (0.04-0.28) and right
                // (0.72-0.96) edges with only a few behind the glass.
                let wallTop = Color(red: 22/255, green: 14/255, blue: 11/255)
                let wallBot = Color(red: 12/255, green:  8/255, blue:  8/255)
                let wallRect = CGRect(x: 0, y: 0, width: w, height: h * 0.58)
                ctx.fill(
                    Path(wallRect),
                    with: .linearGradient(
                        Gradient(colors: [wallTop, wallBot]),
                        startPoint: CGPoint(x: w * 0.5, y: 0),
                        endPoint: CGPoint(x: w * 0.5, y: h * 0.58)
                    )
                )

                // Three shelves at 0.16/0.32/0.48 of h. Each shelf has
                // a thin warm plank edge (catches the directional light)
                // and a short dark recess shadow below. No wood grain
                // noise — keep the wall quiet.
                let shelfYs: [CGFloat] = [h * 0.16, h * 0.32, h * 0.48]
                let plankCol  = Color(red: 112/255, green: 68/255, blue: 36/255)
                let recessCol = Color(red:   3/255, green:  2/255, blue:  3/255)
                for sy in shelfYs {
                    ctx.fill(
                        Path(CGRect(x: 0, y: sy, width: w, height: 1.2)),
                        with: .color(plankCol.opacity(0.38))
                    )
                    ctx.fill(
                        Path(CGRect(x: 0, y: sy + 1.2, width: w, height: 14)),
                        with: .linearGradient(
                            Gradient(colors: [recessCol.opacity(0.55), .clear]),
                            startPoint: CGPoint(x: w * 0.5, y: sy + 1.2),
                            endPoint: CGPoint(x: w * 0.5, y: sy + 14)
                        )
                    )
                }

                // Bottles — each tuple: (xFrac, bodyWpt, totalHpt, tint, alpha, shelfIdx).
                // Heights vary so the skyline reads as a real bar, not
                // a pattern. Tints: amber (whisky), green (gin), pale
                // straw (clear liquor). Alphas stay low so the glass
                // keeps the luminance budget.
                let amberTint = Color(red: 136/255, green:  72/255, blue:  28/255)
                let greenTint = Color(red:  36/255, green:  64/255, blue:  44/255)
                let clearTint = Color(red: 180/255, green: 158/255, blue: 124/255)
                let bottles: [(CGFloat, CGFloat, CGFloat, Color, Double, Int)] = [
                    // Shelf 0 (top)
                    (0.05,  9, h * 0.14, amberTint, 0.30, 0),
                    (0.14,  7, h * 0.11, greenTint, 0.26, 0),
                    (0.22, 10, h * 0.15, amberTint, 0.32, 0),
                    (0.30,  6, h * 0.10, clearTint, 0.22, 0),
                    (0.74,  8, h * 0.13, amberTint, 0.28, 0),
                    (0.83, 10, h * 0.15, amberTint, 0.32, 0),
                    (0.92,  7, h * 0.12, greenTint, 0.26, 0),
                    // Shelf 1 (middle)
                    (0.06,  8, h * 0.13, amberTint, 0.28, 1),
                    (0.15, 10, h * 0.15, amberTint, 0.32, 1),
                    (0.24,  7, h * 0.11, greenTint, 0.24, 1),
                    (0.32,  9, h * 0.13, clearTint, 0.22, 1),
                    (0.72,  8, h * 0.13, clearTint, 0.22, 1),
                    (0.81,  7, h * 0.12, amberTint, 0.28, 1),
                    (0.90,  9, h * 0.14, greenTint, 0.28, 1),
                    // Shelf 2 (bottom — mostly occluded by glass)
                    (0.07,  8, h * 0.11, amberTint, 0.24, 2),
                    (0.16,  7, h * 0.10, greenTint, 0.22, 2),
                    (0.84, 10, h * 0.13, amberTint, 0.26, 2),
                    (0.93,  7, h * 0.11, greenTint, 0.22, 2),
                ]
                for (xFrac, bw, bh, tint, alpha, shelfIdx) in bottles {
                    let baseY = shelfYs[shelfIdx]
                    let bx = w * xFrac - bw / 2
                    // V5.9: CEO「把后面的酒瓶做成频谱那样上下动」— map each
                    // bottle's xFrac to a spectrum bin, lift the whole
                    // bottle upward by bin energy. 2.2× gain lets soft
                    // passages register; max lift 14pt keeps the row
                    // from detaching from its shelf. A tiny idle bob
                    // (±0.8pt, per-bottle phase) keeps the shelf alive
                    // in silence instead of freezing stock-still.
                    let bSpecIdx = min(binCount - 1, max(0, Int(xFrac * CGFloat(binCount - 1))))
                    let bSpecVal = min(1.0, CGFloat(spectrumData[bSpecIdx]) * 2.2)
                    let bIdle = CGFloat(sin(t * 0.9 + Double(xFrac) * 6.0)) * 0.8
                    let bobY = -bSpecVal * 14.0 + bIdle
                    let by = baseY - bh + bobY
                    // Body (rounded rect)
                    let bodyH = bh * 0.78
                    ctx.fill(
                        Path(roundedRect: CGRect(x: bx, y: by + bh - bodyH, width: bw, height: bodyH), cornerRadius: 1.2),
                        with: .color(tint.opacity(alpha))
                    )
                    // Shoulder (small taper between body and neck)
                    ctx.fill(
                        Path(CGRect(x: bx + bw * 0.22, y: by + bh * 0.18, width: bw * 0.56, height: bh * 0.10)),
                        with: .color(tint.opacity(alpha * 0.85))
                    )
                    // Neck
                    ctx.fill(
                        Path(CGRect(x: bx + bw * 0.36, y: by, width: bw * 0.28, height: bh * 0.18)),
                        with: .color(tint.opacity(alpha * 0.75))
                    )
                    // Single right-side specular (directional light from upper-right)
                    ctx.fill(
                        Path(CGRect(x: bx + bw * 0.82, y: by + bh * 0.25, width: 0.6, height: bodyH * 0.88)),
                        with: .color(Color.white.opacity(alpha * 0.38))
                    )
                }

                // 1b-a. Bar top — real wooden bar counter with thickness.
                //
                // V5.2: CEO asked for 酒吧那种桌子 under the glass. Upgrade
                // from "seamless dark plane" to a warm walnut surface with
                // a visible front lip (厚度感), subtle grain + polished
                // streak. The glass sits ON this.
                // V5.11: CEO「桌子延伸到底部」→ walnut surface now runs all
                // the way to the frame bottom. No dark front panel below.
                // Front-edge chamfer tucked just above the bottom as a
                // subtle polished lip.
                let barTop         = h * 0.58
                let barFrontEdge   = h * 1.00
                let barFarCol      = Color(red:  22/255, green:  14/255, blue:  10/255)
                let barMidCol      = Color(red:  36/255, green:  22/255, blue:  14/255)
                let barNearCol     = Color(red:  54/255, green:  32/255, blue:  18/255)

                // Base walnut gradient — dim back, warm toward front edge
                ctx.fill(
                    Path(CGRect(x: 0, y: barTop, width: w, height: barFrontEdge - barTop)),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: barFarCol,  location: 0.0),
                            .init(color: barMidCol,  location: 0.45),
                            .init(color: barNearCol, location: 1.0)
                        ]),
                        startPoint: CGPoint(x: w * 0.5, y: barTop),
                        endPoint:   CGPoint(x: w * 0.5, y: barFrontEdge)
                    )
                )

                // Three long horizontal grain strokes — very low contrast
                // so the surface reads as wood without becoming texture.
                let grainCol = Color(red: 10/255, green: 6/255, blue: 4/255)
                let barDepth = barFrontEdge - barTop
                let grainFracs: [CGFloat] = [0.22, 0.55, 0.80]
                for gf in grainFracs {
                    ctx.fill(
                        Path(CGRect(x: 0, y: barTop + barDepth * gf, width: w, height: 0.6)),
                        with: .color(grainCol.opacity(0.55))
                    )
                }

                // Polished streak — soft warm gradient lying across the
                // surface at the directional light's angle. Low alpha per
                // CEO's 光影太抢眼 note; it tells you the wood is polished,
                // not that a stage light is on.
                let polishCol = Color(red: 176/255, green: 128/255, blue: 68/255)
                let polishRect = CGRect(
                    x: w * 0.08,
                    y: barTop + barDepth * 0.34,
                    width:  w * 1.00,
                    height: barDepth * 0.38
                )
                ctx.fill(
                    Path(ellipseIn: polishRect),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: polishCol.opacity(0.09), location: 0.0),
                            .init(color: polishCol.opacity(0.03), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: CGPoint(x: polishRect.midX + w * 0.10, y: polishRect.midY),
                        startRadius: 0,
                        endRadius: polishRect.width * 0.45
                    )
                )

                // Hairline seam where back wall meets bar top (sells
                // depth — two planes at a right angle, not one surface).
                ctx.fill(
                    Path(CGRect(x: 0, y: barTop - 0.3, width: w, height: 0.6)),
                    with: .color(Color.black.opacity(0.72))
                )

                // Front-edge hot line — thin polished "chamfer" catching
                // the warm key light. This is the single detail that
                // sells "bar counter" rather than "floor."
                let edgeCol = Color(red: 170/255, green: 106/255, blue: 50/255)
                // Fall-off glow just above the lip (light bleeding up)
                ctx.fill(
                    Path(CGRect(x: 0, y: barFrontEdge - 3, width: w, height: 3)),
                    with: .linearGradient(
                        Gradient(colors: [.clear, edgeCol.opacity(0.16)]),
                        startPoint: CGPoint(x: w * 0.5, y: barFrontEdge - 3),
                        endPoint:   CGPoint(x: w * 0.5, y: barFrontEdge)
                    )
                )
                // The chamfer itself
                ctx.fill(
                    Path(CGRect(x: 0, y: barFrontEdge, width: w, height: 1.2)),
                    with: .color(edgeCol.opacity(0.38))
                )

                // V5.11: front panel removed. barFrontEdge == h, so the
                // walnut surface runs to the frame bottom. No dark void
                // below the bar.

                // 1b-b. Directional rim light — a *linear* sweep from
                // top-right corner to mid-left. Not a radial halo.
                // V5.1: CEO 反馈光影太抢眼 → peak alpha 0.14 → 0.07,
                // mid-stop 0.04 → 0.02. Still reads as real light source,
                // but yields luminance budget to the glass.
                let warmRim = Color(red: 210/255, green: 148/255, blue:  78/255)
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: warmRim.opacity(0.07), location: 0.0),
                            .init(color: warmRim.opacity(0.02), location: 0.45),
                            .init(color: .clear, location: 0.85)
                        ]),
                        startPoint: CGPoint(x: w * 1.05, y: h * -0.08),
                        endPoint: CGPoint(x: w * 0.20, y: h * 0.70)
                    )
                )
            }
        }

        // --- 2. Breath offsets ---
        // V5.7: CEO「酒杯本身不要晃动」→ drop the bass-driven breath on
        // the glass silhouette. Keep only a very slow idle drift so the
        // glass isn't dead-still (reads as real photography with a
        // handheld camera). Audio coupling moves to the liquid surface.
        let breathY = CGFloat(sin(t * 2 * .pi / 6.0)) * 1.2

        // Glass geometry v4 — morph-driven tulip.
        // Small pose (e=0): glass dominates frame (big, centered-low,
        //   no scene dressing). A single object the eye holds onto in
        //   the carousel card.
        // Big pose  (e=1): glass shrinks ~22% and lifts up ~8% of h,
        //   clearing the lower third for the bartop + coaster + caustic.
        // LofiTape uses the same pattern: the subject retreats slightly
        // to make room for context, instead of the scene piling on top.
        let glassCenterX = w * 0.50    // V5.7: CEO 要完全居中
        let glassScale: CGFloat = 1.0 - 0.22 * e                    // 1.00 → 0.78
        let glassH = min(h * 0.70 * glassScale, w * 0.98 * glassScale)
        // V5.3: CEO 要把大图酒杯往下移 — 玻璃坐实在吧台上，不再悬空。
        // Small pose (e=0) 不变 (0.54h)；big pose (e=1) 从 0.44h 下沉到
        // 0.54h，glass bottom 落在 ~0.79h（在 barTop 0.58h 和 barFrontEdge
        // 0.92h 之间的吧台中段），读作"酒杯摆在吧台上"。
        let centerYFrac: CGFloat = 0.54 + 0.00 * e                  // 0.54 → 0.54
        let glassTopY = h * centerYFrac - glassH * 0.46 + breathY
        let glassBottomY = glassTopY + glassH
        let glassTopW = min(w * 0.48, glassH * 0.58)                // rim (narrow)
        let bellyW = glassTopW * 1.22                               // widest mid-belly
        let glassBottomW = glassTopW * 0.72                         // base (narrower than rim)
        let bellyY = glassTopY + glassH * 0.58

        let topL  = CGPoint(x: glassCenterX - glassTopW / 2, y: glassTopY)
        let topR  = CGPoint(x: glassCenterX + glassTopW / 2, y: glassTopY)
        let botL  = CGPoint(x: glassCenterX - glassBottomW / 2, y: glassBottomY)
        let botR  = CGPoint(x: glassCenterX + glassBottomW / 2, y: glassBottomY)
        let bellyLx = glassCenterX - bellyW / 2
        let bellyRx = glassCenterX + bellyW / 2

        // --- 3a. Cast shadow — opposite the directional rim light ---
        // Light source sits top-right → shadow falls bottom-left.
        // A single elongated ellipse, sheared so the far edge trails
        // away from the base. This is what sells "glass on surface"
        // without any coaster/rim prop.
        if deckAlpha > 0.01 {
            var shadow = Path()
            let shY = glassBottomY + glassH * 0.02
            let shW = glassBottomW * 2.6
            let shH = glassH * 0.08
            let shCx = glassCenterX - glassBottomW * 0.45     // offset toward left (away from light)
            // Skewed ellipse — trace manually so the trailing (left) end
            // stretches. ~24 segments.
            let segs = 24
            for s in 0...segs {
                let tt = Double(s) / Double(segs)
                let ang = tt * .pi * 2
                let rx = Double(shW) * (0.5 + 0.18 * cos(ang) * -1) // stretch left
                let ry = Double(shH) * 0.5
                let px = Double(shCx) + rx * cos(ang)
                let py = Double(shY) + ry * sin(ang)
                if s == 0 { shadow.move(to: CGPoint(x: px, y: py)) }
                else { shadow.addLine(to: CGPoint(x: px, y: py)) }
            }
            shadow.closeSubpath()
            gc.fill(
                shadow,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color.black.opacity(0.50 * deckAlpha), location: 0.0),
                        .init(color: Color.black.opacity(0.26 * deckAlpha), location: 0.55),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: CGPoint(x: shCx + glassBottomW * 0.2, y: shY),
                    startRadius: 0,
                    endRadius: shW * 0.55
                )
            )
        }

        // --- 3b. Amber caustic — implied liquor spill below glass ---
        let causticScale = 1.0 + 0.25 * CGFloat(deckAlpha)
        let causticW = glassBottomW * 2.2 * causticScale
        let causticH = glassH * 0.18 * causticScale
        let causticCenter = CGPoint(x: glassCenterX + glassBottomW * 0.15, y: glassBottomY + causticH * 0.15)
        gc.fill(
            Path(ellipseIn: CGRect(
                x: causticCenter.x - causticW / 2,
                y: causticCenter.y - causticH / 2,
                width: causticW,
                height: causticH
            )),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: causticAmber.opacity(0.16), location: 0.0),
                    .init(color: causticAmber.opacity(0.06), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ]),
                center: causticCenter,
                startRadius: 0,
                endRadius: causticW / 2
            )
        )

        // --- 3c. Mirror reflection (big-mode only) ---
        // The polished bar surface gives back a short, blurred ghost of
        // the glass directly below the base. This is the single move
        // that most sells "photographed on a real surface" — more than
        // any coaster/rim/prop could. Shape is a soft tulip smear mirrored
        // from the glass silhouette, compressed ~0.48x vertically, alpha
        // fading to nothing by the far edge.
        if deckAlpha > 0.01 {
            // V5.3: clamp reflection to stay inside the bar top (above
            // the front-edge chamfer at 0.92h). Glass now sits low on
            // the bar, so the reflection height must shrink to fit.
            let barFrontEdgeRef = h * 0.92
            let maxRefH = max(0, barFrontEdgeRef - glassBottomY - 4)
            let refH = min(glassH * 0.48, maxRefH)
            let refTopY = glassBottomY
            let refBotY = refTopY + refH
            let refW = glassBottomW * 1.12
            let refTip: CGFloat = refW * 0.18

            var refPath = Path()
            refPath.move(to: CGPoint(x: glassCenterX - refW / 2, y: refTopY))
            // top-edge arc (mirrors the base curve underneath)
            refPath.addQuadCurve(
                to: CGPoint(x: glassCenterX + refW / 2, y: refTopY),
                control: CGPoint(x: glassCenterX, y: refTopY - 1.5)
            )
            // right wall curving in toward the tip
            refPath.addCurve(
                to: CGPoint(x: glassCenterX + refTip, y: refBotY),
                control1: CGPoint(x: glassCenterX + refW * 0.56, y: refTopY + refH * 0.35),
                control2: CGPoint(x: glassCenterX + refW * 0.30, y: refTopY + refH * 0.78)
            )
            // tip
            refPath.addQuadCurve(
                to: CGPoint(x: glassCenterX - refTip, y: refBotY),
                control: CGPoint(x: glassCenterX, y: refBotY + 2)
            )
            // left wall back up to start
            refPath.addCurve(
                to: CGPoint(x: glassCenterX - refW / 2, y: refTopY),
                control1: CGPoint(x: glassCenterX - refW * 0.30, y: refTopY + refH * 0.78),
                control2: CGPoint(x: glassCenterX - refW * 0.56, y: refTopY + refH * 0.35)
            )
            refPath.closeSubpath()

            gc.fill(
                refPath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: bourbonBody.opacity(0.20 * deckAlpha), location: 0.0),
                        .init(color: bourbonDeep.opacity(0.10 * deckAlpha), location: 0.35),
                        .init(color: bourbonDeep.opacity(0.03 * deckAlpha), location: 0.75),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: CGPoint(x: glassCenterX, y: refTopY),
                    endPoint: CGPoint(x: glassCenterX, y: refBotY)
                )
            )

            // A thin warm meniscus mirror line right at refTopY — the
            // hard edge where "real liquid surface" kisses "mirrored
            // surface." Makes the reflection read as continuous glass,
            // not a separate blob.
            var refLip = Path()
            refLip.move(to: CGPoint(x: glassCenterX - refW / 2 + 2, y: refTopY))
            refLip.addQuadCurve(
                to: CGPoint(x: glassCenterX + refW / 2 - 2, y: refTopY),
                control: CGPoint(x: glassCenterX, y: refTopY - 0.8)
            )
            gc.stroke(
                refLip,
                with: .color(bourbonHot.opacity(0.13 * deckAlpha)),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
            )
        }

        // --- 4. Glass body — stacked translucent layers for thickness ---
        // Cubic bezier walls — both sides bulge out through the belly.
        // Control points sit beyond bellyLx/Rx so the mid-curve pushes
        // outward past them, producing a convex goblet profile.
        let glassSilhouette = Path { p in
            p.move(to: topL)
            // Left wall: topL → botL, bulging out at belly
            p.addCurve(
                to: botL,
                control1: CGPoint(x: bellyLx - 4, y: glassTopY + glassH * 0.28),
                control2: CGPoint(x: bellyLx - 2, y: glassTopY + glassH * 0.82)
            )
            // Bottom curve (slight downward arc)
            p.addQuadCurve(to: botR, control: CGPoint(x: glassCenterX, y: glassBottomY + 5))
            // Right wall: botR → topR, mirror of left
            p.addCurve(
                to: topR,
                control1: CGPoint(x: bellyRx + 2, y: glassTopY + glassH * 0.82),
                control2: CGPoint(x: bellyRx + 4, y: glassTopY + glassH * 0.28)
            )
            // Close via rim arc
            p.addQuadCurve(to: topL, control: CGPoint(x: glassCenterX, y: glassTopY - 2))
        }
        // Inner faint tint — what passes through the glass
        gc.fill(glassSilhouette, with: .color(glassTint.opacity(0.07)))
        // Directional wash — darker left, brighter right (3/4 lit from right)
        gc.fill(
            glassSilhouette,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color.black.opacity(0.22), location: 0.0),
                    .init(color: .clear, location: 0.55),
                    .init(color: glassTint.opacity(0.14), location: 1.0)
                ]),
                startPoint: CGPoint(x: topL.x, y: glassTopY),
                endPoint: CGPoint(x: topR.x, y: glassBottomY)
            )
        )

        // --- 5. Liquid (bourbon pour ~50% depth) ---
        // Top sits just above the belly (88% of the way from rim to belly)
        // so the pour reads as "bourbon in the belly" not "half a glass".
        // V5.10: CEO「把酒杯的 eq 随音乐动功能去掉」→ strip ALL audio
        // coupling from the liquid surface. Keep only a pure-time gentle
        // tilt so the pour is still alive (reads as hand-held micro-sway),
        // never as "UI meter". rippleAmp is now a constant.
        let liquidTopY = glassTopY + glassH * 0.50
        let rippleAmp: CGFloat = 1.4
        let rippleCycle = CGFloat(sin(t * 1.6)) * rippleAmp

        let inset: CGFloat = 3.5
        // Interior width at liquid surface — lerp rim↔belly by normalized y
        let tLiquid = (liquidTopY - glassTopY) / max(1, bellyY - glassTopY)
        let liquidLx = lerp(topL.x, bellyLx, tLiquid) + inset
        let liquidRx = lerp(topR.x, bellyRx, tLiquid) - inset
        let liquidBotL = CGPoint(x: botL.x + inset, y: glassBottomY - 2)
        let liquidBotR = CGPoint(x: botR.x - inset, y: glassBottomY - 2)
        let liquidSpan = glassBottomY - liquidTopY

        // Smooth surface — left/right endpoints get the idle tilt; mid
        // lifts ~2.4pt for a gentle concave meniscus. No spectrum.
        let liqTopL = CGPoint(x: liquidLx, y: liquidTopY + rippleCycle)
        let liqTopR = CGPoint(x: liquidRx, y: liquidTopY - rippleCycle)
        let liqTopMid = CGPoint(x: glassCenterX, y: liquidTopY - 2.4)

        let liquidPath = Path { p in
            p.move(to: liqTopL)
            // Smooth concave top — quad through mid
            p.addQuadCurve(to: liqTopR, control: liqTopMid)
            // Right interior wall — cubic follow of glass belly curve
            p.addCurve(
                to: liquidBotR,
                control1: CGPoint(x: bellyRx - inset + 1, y: liquidTopY + liquidSpan * 0.20),
                control2: CGPoint(x: bellyRx - inset, y: liquidTopY + liquidSpan * 0.72)
            )
            // Bottom curve
            p.addQuadCurve(
                to: liquidBotL,
                control: CGPoint(x: glassCenterX, y: glassBottomY + 3)
            )
            // Left interior wall back up
            p.addCurve(
                to: liqTopL,
                control1: CGPoint(x: bellyLx + inset, y: liquidTopY + liquidSpan * 0.72),
                control2: CGPoint(x: bellyLx + inset - 1, y: liquidTopY + liquidSpan * 0.20)
            )
            p.closeSubpath()
        }

        // Liquid body v4 — alphas reduced another ~20pts so the velvet
        // backdrop clearly reads through. Goal: white-wine translucent,
        // not lager-juice opaque. The bottom stays slightly deeper so
        // the pour still has a sense of column depth.
        gc.fill(
            liquidPath,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: bourbonBody.opacity(0.54), location: 0.0),
                    .init(color: bourbonBody.opacity(0.62), location: 0.35),
                    .init(color: bourbonDeep.opacity(0.74), location: 1.0)
                ]),
                startPoint: CGPoint(x: glassCenterX, y: liquidTopY),
                endPoint: CGPoint(x: glassCenterX, y: glassBottomY)
            )
        )
        // Right-side light streak — side-lit wine picks up brighter pale
        // gold on the right 85-100% band (where the candle passes through).
        gc.fill(
            liquidPath,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.62),
                    .init(color: bourbonHot.opacity(0.22), location: 0.92),
                    .init(color: bourbonHot.opacity(0.38), location: 1.0)
                ]),
                startPoint: CGPoint(x: botL.x, y: 0),
                endPoint: CGPoint(x: botR.x, y: 0)
            )
        )

        // --- 6. Meniscus line — smooth bright edge at liquid surface ---
        // V5.10: CEO stripped audio coupling from the liquid; meniscus is
        // now a fixed double-stroke (glow 3.6pt + sharp 1.3pt) tracing
        // the same smooth quad as the top of liquidPath.
        let meniscus = Path { p in
            p.move(to: liqTopL)
            p.addQuadCurve(to: liqTopR, control: liqTopMid)
        }
        gc.stroke(meniscus, with: .color(bourbonHot.opacity(0.42)),
                  style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
        gc.stroke(meniscus, with: .color(bourbonHot.opacity(0.78)),
                  style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))

        // --- 7. Ice cubes (two — static, only gentle idle drift) ---
        // V5.7: CEO「冰块跟音乐动效果不好」→ drop all audio coupling on
        // ice position. Keep a very slow sine drift (±1~1.5pt at different
        // phases) so they aren't frozen, but no more band-driven lift.
        // Audio energy shows in the liquid surface EQ (step 6), not here.
        let bob1 = CGFloat(sin(t * 0.75 + 0.0)) * 1.4
        let bob2 = CGFloat(sin(t * 1.05 + 1.8)) * 1.1
        let cube1Cy = liquidTopY + glassH * 0.10 + bob1
        let cube2Cy = liquidTopY + glassH * 0.04 + bob2

        drawIceCube(
            gc: gc,
            center: CGPoint(x: glassCenterX - glassTopW * 0.18, y: cube1Cy),
            size: glassH * 0.22,
            rotation: CGFloat(sin(t * 0.35 + 1.2)) * 0.04 + midCG * 0.10,
            seed: 0.31,
            body: iceBody,
            edge: iceEdge,
            trebGlint: trebCG * shimmerBoost
        )
        drawIceCube(
            gc: gc,
            center: CGPoint(x: glassCenterX + glassTopW * 0.14, y: cube2Cy),
            size: glassH * 0.19,
            rotation: CGFloat(cos(t * 0.42 - 0.7)) * 0.05 + midCG * 0.07,
            seed: 0.77,
            body: iceBody,
            edge: iceEdge,
            trebGlint: trebCG * shimmerBoost
        )

        // --- 8. Glass rim (top ellipse — the opening seen 3/4) ---
        // Rim ellipse — height scales with top width so a wider glass
        // shows a proportionally taller 3/4 rim oval.
        let rimH = max(10, glassTopW * 0.16)
        let rimRect = CGRect(
            x: topL.x - 1,
            y: glassTopY - rimH / 2,
            width: glassTopW + 2,
            height: rimH
        )
        // Rim back half (behind liquid surface — darker)
        gc.stroke(
            Path(ellipseIn: rimRect),
            with: .color(glassTint.opacity(0.35)),
            style: StrokeStyle(lineWidth: 0.9)
        )
        // Rim front half (in front — brighter, on top-right arc)
        let rimCx = rimRect.midX, rimCy = rimRect.midY
        let rimRx = rimRect.width / 2, rimRy = rimRect.height / 2
        var rimHot = Path()
        let rimSegments = 22
        for s in 0...rimSegments {
            let tt = Double(s) / Double(rimSegments)
            // arc from -100° to +10° (top-right catches light)
            let ang = -.pi * 0.55 + tt * .pi * 0.62
            let px = rimCx + rimRx * CGFloat(cos(ang))
            let py = rimCy + rimRy * CGFloat(sin(ang))
            if s == 0 { rimHot.move(to: CGPoint(x: px, y: py)) }
            else { rimHot.addLine(to: CGPoint(x: px, y: py)) }
        }
        let rimGlint = 0.55 + Double(trebCG) * 0.38 * Double(shimmerBoost)
        gc.stroke(rimHot, with: .color(glassRim.opacity(min(0.92, rimGlint) * 0.28)), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
        gc.stroke(rimHot, with: .color(glassRim.opacity(min(0.92, rimGlint))), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        // --- 9. Right-wall specular (follows the belly curve, offset -2.5 into glass) ---
        var rightSpec = Path()
        rightSpec.move(to: CGPoint(x: topR.x - 2.5, y: glassTopY + glassH * 0.10))
        rightSpec.addCurve(
            to: CGPoint(x: botR.x - 2.2, y: glassBottomY - glassH * 0.14),
            control1: CGPoint(x: bellyRx - 2.4, y: glassTopY + glassH * 0.28),
            control2: CGPoint(x: bellyRx - 2.4, y: glassTopY + glassH * 0.82)
        )
        gc.stroke(rightSpec, with: .color(glassRim.opacity(0.12)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        gc.stroke(rightSpec, with: .color(glassRim.opacity(0.42)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        // --- 10. Left interior shadow — follows belly curve inset +3 ---
        var leftShadow = Path()
        leftShadow.move(to: CGPoint(x: topL.x + 3, y: glassTopY + 3))
        leftShadow.addCurve(
            to: CGPoint(x: botL.x + 3, y: glassBottomY - 3),
            control1: CGPoint(x: bellyLx + 2, y: glassTopY + glassH * 0.28),
            control2: CGPoint(x: bellyLx + 2, y: glassTopY + glassH * 0.82)
        )
        gc.stroke(leftShadow, with: .color(Color.black.opacity(0.30)), style: StrokeStyle(lineWidth: 2.2))

        // --- 11. Glass base ellipse (bottom opening seen 3/4, mostly shadow) ---
        // Base ellipse scales with bottom width similarly.
        let baseH = max(7, glassBottomW * 0.13)
        let baseRect = CGRect(
            x: botL.x - 2,
            y: glassBottomY - baseH / 2,
            width: glassBottomW + 4,
            height: baseH
        )
        gc.fill(Path(ellipseIn: baseRect), with: .color(Color.black.opacity(0.55)))
        // Base rim front-right highlight
        let baseCx = baseRect.midX, baseCy = baseRect.midY
        let baseRx = baseRect.width / 2, baseRy = baseRect.height / 2
        var baseHot = Path()
        for s in 0...14 {
            let tt = Double(s) / 14.0
            let ang = -.pi * 0.85 + tt * .pi * 0.45
            let px = baseCx + baseRx * CGFloat(cos(ang))
            let py = baseCy + baseRy * CGFloat(sin(ang))
            if s == 0 { baseHot.move(to: CGPoint(x: px, y: py)) }
            else { baseHot.addLine(to: CGPoint(x: px, y: py)) }
        }
        gc.stroke(baseHot, with: .color(glassRim.opacity(0.22)), style: StrokeStyle(lineWidth: 0.8))
    }

    /// Draw one ice cube — irregular quad + internal crack + one bright edge.
    private func drawIceCube(
        gc: GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        rotation: CGFloat,
        seed: Double,
        body: Color,
        edge: Color,
        trebGlint: CGFloat
    ) {
        var ctx = gc
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .radians(Double(rotation)))

        let half = size / 2
        // Irregular quad — deterministic from seed for stable shape
        let j: (Double) -> CGFloat = { offset in
            CGFloat(sin((seed + offset) * 17.31).truncatingRemainder(dividingBy: 1.0) * 0.10)
        }
        let p0 = CGPoint(x: -half * (1.02 + j(0.1)), y: -half * (0.90 + j(0.2)))
        let p1 = CGPoint(x:  half * (0.94 + j(0.3)), y: -half * (0.96 + j(0.4)))
        let p2 = CGPoint(x:  half * (1.04 + j(0.5)), y:  half * (0.92 + j(0.6)))
        let p3 = CGPoint(x: -half * (0.90 + j(0.7)), y:  half * (1.00 + j(0.8)))

        let cubePath = Path { p in
            p.move(to: p0)
            p.addLine(to: p1)
            p.addLine(to: p2)
            p.addLine(to: p3)
            p.closeSubpath()
        }

        // Body translucent fill
        ctx.fill(cubePath, with: .color(body.opacity(0.34)))
        // Directional gradient — brighter top-right (matches scene light)
        ctx.fill(
            cubePath,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: edge.opacity(0.36), location: 0.0),
                    .init(color: body.opacity(0.12), location: 0.50),
                    .init(color: Color.black.opacity(0.22), location: 1.0)
                ]),
                startPoint: CGPoint(x: half * 0.8, y: -half * 0.9),
                endPoint: CGPoint(x: -half * 0.8, y: half * 0.9)
            )
        )

        // Internal crack — 3-segment polyline
        var crack = Path()
        crack.move(to: CGPoint(x: -half * 0.45, y: -half * 0.12))
        crack.addLine(to: CGPoint(x:  half * 0.08, y:  half * 0.06))
        crack.addLine(to: CGPoint(x:  half * 0.30, y: -half * 0.28))
        ctx.stroke(crack, with: .color(edge.opacity(0.26)), style: StrokeStyle(lineWidth: 0.7))

        // Inner facet hairline (implies 3D cube face)
        var facet = Path()
        facet.move(to: CGPoint(x: p0.x + half * 0.18, y: p0.y + half * 0.16))
        facet.addLine(to: CGPoint(x: p1.x - half * 0.12, y: p1.y + half * 0.18))
        facet.addLine(to: CGPoint(x: p2.x - half * 0.14, y: p2.y - half * 0.18))
        ctx.stroke(facet, with: .color(edge.opacity(0.14)), style: StrokeStyle(lineWidth: 0.6))

        // Top-right specular edge
        var specEdge = Path()
        specEdge.move(to: p0)
        specEdge.addLine(to: p1)
        let glint = 0.55 + Double(trebGlint) * 0.45
        ctx.stroke(specEdge, with: .color(edge.opacity(min(0.95, glint) * 0.35)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        ctx.stroke(specEdge, with: .color(edge.opacity(min(0.95, glint))), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        // Tiny bright corner dot
        let dotR: CGFloat = 1.5
        ctx.fill(
            Path(ellipseIn: CGRect(x: p1.x - dotR, y: p1.y - dotR, width: dotR * 2, height: dotR * 2)),
            with: .color(edge.opacity(min(0.95, 0.5 + Double(trebGlint) * 0.6)))
        )
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

import SwiftUI

// Favorites visualizer — Wax-Sealed Letter Rack.
//
// 小图 (expansion=0): 单格 + 单封焦点信居中，蜡封红点脉动，手写线若隐若现。
// 大图 (expansion=1): 主信缩回到 3×4 pigeon-hole 格栈的中心格位，其他格位信封淡入。
//
// Object: 深棕木信格（老式书房的 letter rack）。侧光从右上角桌灯来，阴影落在左下。
// Spectrum mapping:
//  - 低频 → 焦点信蜡封呼吸 (1 ± bass × 0.35)
//  - 中频 → 纸面纤维微颤（信体 x/y 小位移）
//  - 高频 → 偶发羽毛笔横划过焦点信（稀疏触发）
struct LetterRackView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0

    private static let cols = 3
    private static let rows = 4
    private static let focusCol = 1
    private static let focusRow = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            render(context: context, size: size, binCount: binCount)
        }
    }

    private func render(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let e: CGFloat = max(0, min(1, expansion))
        let sceneAlpha: Double = smoothstep(0.30, 0.88, Double(e))

        // Palette
        let bg         = Color(red: 18/255,  green: 16/255,  blue: 14/255)
        let wallBg     = Color(red: 36/255,  green: 30/255,  blue: 24/255)
        let lamp       = Color(red: 252/255, green: 200/255, blue: 120/255)
        let wood       = Color(red: 52/255,  green: 38/255,  blue: 26/255)
        let woodHL     = Color(red: 94/255,  green: 70/255,  blue: 44/255)
        let woodDark   = Color(red: 24/255,  green: 18/255,  blue: 12/255)
        let paper      = Color(red: 232/255, green: 214/255, blue: 176/255)
        let paperShade = Color(red: 186/255, green: 168/255, blue: 130/255)
        let paperLine  = Color(red: 68/255,  green: 50/255,  blue: 32/255)
        let waxDeep    = Color(red: 128/255, green: 40/255,  blue: 30/255)
        let waxBright  = Color(red: 222/255, green: 92/255,  blue: 56/255)

        // Audio
        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.22 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.12 * idleBlend)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ── 背景：暗墙 + 右上角桌灯（大图淡入）──────────
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                // 墙面径向暗调（lamp 位于右上）
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: wallBg.opacity(0.8), location: 0),
                                .init(color: bg, location: 0.7),
                                .init(color: bg, location: 1)
                            ]),
                            center: CGPoint(x: w * 0.88, y: h * 0.14),
                            startRadius: 0, endRadius: max(w, h) * 0.95
                         ))
                // 桌灯暖晕
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(colors: [
                                lamp.opacity(0.18), lamp.opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.95, y: h * 0.08),
                            startRadius: 0, endRadius: max(w, h) * 0.5
                         ))
            }
        }

        // ── 格栈几何 ──────────────────────────────
        // 小图: rack 虚拟为单一大格占满 0.64w × 0.76h
        // 大图: rack 扩到 0.80w × 0.86h，切成 3×4
        let rackW = (0.64 + (0.80 - 0.64) * e) * w
        let rackH = (0.76 + (0.86 - 0.76) * e) * h
        let rackCX = w * 0.50
        let rackCY = h * 0.50
        let rackX = rackCX - rackW / 2
        let rackY = rackCY - rackH / 2

        let cols = Self.cols
        let rows = Self.rows
        let focusCol = Self.focusCol
        let focusRow = Self.focusRow
        let cellW = rackW / CGFloat(cols)
        let cellH = rackH / CGFloat(rows)

        // Focus 格几何：小图时占满整 rack，大图时缩回到第 (focusCol, focusRow) 格位
        let focusCXSmall = rackCX
        let focusCYSmall = rackCY
        let focusCXBig = rackX + (CGFloat(focusCol) + 0.5) * cellW
        let focusCYBig = rackY + (CGFloat(focusRow) + 0.5) * cellH
        let focusCX = focusCXSmall + (focusCXBig - focusCXSmall) * e
        let focusCY = focusCYSmall + (focusCYBig - focusCYSmall) * e
        let focusW = rackW + (cellW - rackW) * e
        let focusH = rackH + (cellH - rackH) * e
        let focusRect = CGRect(
            x: focusCX - focusW / 2, y: focusCY - focusH / 2,
            width: focusW, height: focusH
        )

        // ── 底层 rack（大图淡入）───────────────────
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let rackRect = CGRect(x: rackX, y: rackY, width: rackW, height: rackH)
                ctx.fill(Path(roundedRect: rackRect, cornerRadius: 4),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: woodHL.opacity(0.85), location: 0),
                                .init(color: wood, location: 0.55),
                                .init(color: woodDark, location: 1)
                            ]),
                            startPoint: CGPoint(x: rackX + rackW, y: rackY),
                            endPoint: CGPoint(x: rackX, y: rackY + rackH)
                         ))

                // 每格 + 露头的信件（焦点格除外）
                for r in 0..<rows {
                    for c in 0..<cols {
                        if r == focusRow && c == focusCol { continue }
                        let cellX = rackX + CGFloat(c) * cellW
                        let cellY = rackY + CGFloat(r) * cellH
                        let cellRect = CGRect(x: cellX + 2, y: cellY + 2,
                                              width: cellW - 4, height: cellH - 4)
                        // 格内暗（深格）
                        ctx.fill(Path(roundedRect: cellRect, cornerRadius: 2),
                                 with: .linearGradient(
                                    Gradient(colors: [woodDark.opacity(0.98), Color.black.opacity(0.85)]),
                                    startPoint: CGPoint(x: cellRect.minX, y: cellRect.minY),
                                    endPoint: CGPoint(x: cellRect.maxX, y: cellRect.maxY)
                                 ))

                        // 这一格的信（非 focus → 信封尾端藏在格内，只露一截）
                        let seed = Double(r * 7 + c * 3) * 1.37
                        drawLetterInCell(ctx: ctx, cellRect: cellRect,
                                         paper: paper, paperShade: paperShade,
                                         paperLine: paperLine,
                                         waxDeep: waxDeep, waxBright: waxBright,
                                         seed: seed, bass: bassCG, mid: midCG, t: t,
                                         isFocus: false)
                    }
                }

                // 格栈外框高光（侧光从右上）
                ctx.stroke(Path(roundedRect: rackRect, cornerRadius: 4),
                           with: .color(woodHL.opacity(0.50)), lineWidth: 0.8)
            }
        }

        // ── 焦点格（永远以完整强度绘制）──────────
        // 格内深色底（在小图时 focusRect 覆盖整个可视区，等于 rack 本身的"单格"）
        context.fill(Path(roundedRect: focusRect.insetBy(dx: 2, dy: 2), cornerRadius: 3),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: woodDark, location: 0),
                            .init(color: Color.black.opacity(0.88), location: 1)
                        ]),
                        startPoint: CGPoint(x: focusRect.minX, y: focusRect.minY),
                        endPoint: CGPoint(x: focusRect.maxX, y: focusRect.maxY)
                     ))
        context.stroke(Path(roundedRect: focusRect.insetBy(dx: 2, dy: 2), cornerRadius: 3),
                       with: .color(woodHL.opacity(0.55)), lineWidth: 0.7)

        // 焦点信
        drawLetterInCell(ctx: context, cellRect: focusRect.insetBy(dx: 4, dy: 4),
                         paper: paper, paperShade: paperShade,
                         paperLine: paperLine,
                         waxDeep: waxDeep, waxBright: waxBright,
                         seed: 0.0, bass: bassCG, mid: midCG, t: t,
                         isFocus: true)

        // 高频触发：羽毛笔划过焦点信（稀疏）
        if treble > 0.09 {
            let phase = sin(Double(t) * 0.83) - floor(sin(Double(t) * 0.83))
            if phase < 0.12 {
                let startX = focusRect.minX + focusRect.width * 0.18
                let endX = focusRect.minX + focusRect.width * 0.82
                let yMid = focusRect.minY + focusRect.height * (0.55 + CGFloat(sin(Double(t) * 2.1)) * 0.08)
                var stroke = Path()
                stroke.move(to: CGPoint(x: startX, y: yMid))
                stroke.addQuadCurve(to: CGPoint(x: endX, y: yMid + 2),
                                    control: CGPoint(x: (startX + endX) / 2, y: yMid - 6))
                context.stroke(stroke,
                               with: .color(paperLine.opacity(Double(treble) * 1.7)),
                               lineWidth: 0.9)
            }
        }
    }

    // MARK: - Single letter draw

    private func drawLetterInCell(ctx: GraphicsContext, cellRect: CGRect,
                                   paper: Color, paperShade: Color, paperLine: Color,
                                   waxDeep: Color, waxBright: Color,
                                   seed: Double, bass: CGFloat, mid: CGFloat, t: Float,
                                   isFocus: Bool) {
        // 信封在格里露头的比例：焦点信露大半，非焦点信只露上半
        let reveal: CGFloat = isFocus ? 0.86 : 0.48
        let paperW = cellRect.width * 0.84
        let paperH = cellRect.height * reveal
        let paperCX = cellRect.midX
        let paperTop = cellRect.minY + cellRect.height * 0.08
        let paperRect = CGRect(
            x: paperCX - paperW / 2, y: paperTop,
            width: paperW, height: paperH
        )

        // 纸面微颤（中频）
        let jx = CGFloat(sin(Double(t) * 2.3 + seed)) * mid * 1.8
        let jy = CGFloat(sin(Double(t) * 1.9 + seed * 2.1)) * mid * 1.0
        let jittered = paperRect.offsetBy(dx: jx, dy: jy)

        // 纸体
        ctx.fill(Path(roundedRect: jittered, cornerRadius: 1.5),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: paper, location: 0),
                        .init(color: paperShade.opacity(0.88), location: 1)
                    ]),
                    startPoint: CGPoint(x: jittered.minX, y: jittered.minY),
                    endPoint: CGPoint(x: jittered.maxX, y: jittered.maxY)
                 ))

        // 左侧投影（右上侧光 → 左下阴影）
        var leftShadow = Path()
        leftShadow.move(to: CGPoint(x: jittered.minX, y: jittered.minY + 1))
        leftShadow.addLine(to: CGPoint(x: jittered.minX, y: jittered.maxY - 1))
        ctx.stroke(leftShadow,
                   with: .color(Color.black.opacity(0.32)), lineWidth: 1.2)
        // 底部阴影
        var bottomShadow = Path()
        bottomShadow.move(to: CGPoint(x: jittered.minX + 1, y: jittered.maxY))
        bottomShadow.addLine(to: CGPoint(x: jittered.maxX - 1, y: jittered.maxY))
        ctx.stroke(bottomShadow,
                   with: .color(Color.black.opacity(0.30)), lineWidth: 1.0)

        // 手写线（只焦点信画）
        if isFocus {
            let lineCount = 4
            let linePad = jittered.width * 0.14
            let lineY0 = jittered.minY + jittered.height * 0.18
            let lineGap = jittered.height * 0.14
            for i in 0..<lineCount {
                let ly = lineY0 + CGFloat(i) * lineGap
                let lineW = jittered.width - linePad * 2 - CGFloat(i) * (jittered.width * 0.08)
                var ln = Path()
                ln.move(to: CGPoint(x: jittered.minX + linePad, y: ly))
                let segments = 12
                for j in 1...segments {
                    let sf = CGFloat(j) / CGFloat(segments)
                    let x = jittered.minX + linePad + lineW * sf
                    let wobble = sin(Double(t) * 0.7 + Double(i) * 1.9 + Double(j) * 0.7) * 0.4
                    ln.addLine(to: CGPoint(x: x, y: ly + CGFloat(wobble)))
                }
                ctx.stroke(ln, with: .color(paperLine.opacity(0.52)), lineWidth: 0.7)
            }
            // 落款小横线（右下）
            var sig = Path()
            let sigY = jittered.maxY - jittered.height * 0.16
            sig.move(to: CGPoint(x: jittered.maxX - jittered.width * 0.38, y: sigY))
            sig.addQuadCurve(
                to: CGPoint(x: jittered.maxX - jittered.width * 0.18, y: sigY),
                control: CGPoint(x: jittered.maxX - jittered.width * 0.28, y: sigY - 4)
            )
            ctx.stroke(sig, with: .color(paperLine.opacity(0.7)), lineWidth: 0.9)
        }

        // 蜡封（焦点信居中靠下；非焦点信在露出部分偏下居中）
        let sealR: CGFloat = isFocus
            ? jittered.width * 0.11
            : jittered.width * 0.14
        let sealCX = jittered.midX
        let sealCY = isFocus
            ? jittered.maxY - jittered.height * 0.16
            : jittered.maxY - jittered.height * 0.30
        let pulse = 0.85 + Double(bass) * 0.40

        // Halo
        let haloR = sealR * 2.4
        ctx.fill(Path(ellipseIn: CGRect(x: sealCX - haloR, y: sealCY - haloR,
                                         width: haloR * 2, height: haloR * 2)),
                 with: .radialGradient(
                    Gradient(colors: [
                        waxBright.opacity(pulse * 0.32),
                        waxBright.opacity(0)
                    ]),
                    center: CGPoint(x: sealCX, y: sealCY),
                    startRadius: 0, endRadius: haloR
                 ))

        // Seal base
        let outR = sealR * CGFloat(pulse)
        let sealRect = CGRect(x: sealCX - outR, y: sealCY - outR,
                              width: outR * 2, height: outR * 2)
        ctx.fill(Path(ellipseIn: sealRect),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: waxBright.opacity(pulse), location: 0),
                        .init(color: waxDeep.opacity(0.95), location: 1)
                    ]),
                    center: CGPoint(x: sealCX - outR * 0.3, y: sealCY - outR * 0.3),
                    startRadius: 0, endRadius: outR * 1.15
                 ))

        // Seal 五角星印（焦点信）
        if isFocus {
            let starR = sealR * 0.52
            var star = Path()
            for i in 0..<10 {
                let angle = -.pi / 2 + CGFloat(i) * (.pi / 5)
                let r = (i % 2 == 0) ? starR : starR * 0.42
                let pt = CGPoint(x: sealCX + cos(angle) * r,
                                 y: sealCY + sin(angle) * r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(waxDeep.opacity(0.62)))
        }
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

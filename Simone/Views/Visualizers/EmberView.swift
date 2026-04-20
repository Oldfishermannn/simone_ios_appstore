import SwiftUI

// Rock visualizer — Ember on Charred Logs.
//
// 小图 (expansion=0): 单枚余烬居中、略大。
// 大图 (expansion=1): 主余烬落在两根交叠炭木上，地面淡出灰烬层，背景
// 深灰垂直渐变 + 顶部 fade 遮罩。场景叙事：壁炉底的最后一点余烬。
//
// 物体连续 morph：余烬本身 radius/cx/cyBase 线性插值；炭木 / 地板 /
// 背景走 sceneAlpha smoothstep(0.30, 0.88) 淡入。
struct EmberView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small (单余烬居中), 1 = big (余烬 + 炭木 + 灰烬层场景)
    var expansion: CGFloat = 1.0

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderEmbers(context: context, size: size, binCount: binCount)
        }
    }

    private struct EmberSpec {
        let cx: CGFloat
        let cyBase: CGFloat
        let radius: CGFloat
        let seed: Double
        let lenFactor: CGFloat
    }

    private func renderEmbers(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let e: CGFloat = max(0, min(1, expansion))
        let sceneAlpha: Double = smoothstep(0.30, 0.88, Double(e))

        let bgDark  = Color(red: 32/255, green: 26/255, blue: 22/255)
        let bgMid   = Color(red: 52/255, green: 42/255, blue: 36/255)
        let emberCore = Color(red: 246/255, green: 156/255, blue: 72/255)
        let emberMid  = Color(red: 186/255, green: 86/255,  blue: 52/255)
        let emberEdge = Color(red: 120/255, green: 54/255,  blue: 42/255)
        let smokeCool = Color(red: 140/255, green: 148/255, blue: 162/255)
        let smokeWarm = Color(red: 120/255, green: 102/255, blue: 88/255)
        let charcoal     = Color(red:  22/255, green:  18/255, blue:  16/255)
        let charcoalHi   = Color(red:  46/255, green:  36/255, blue:  30/255)
        let ashWarm      = Color(red:  72/255, green:  58/255, blue:  48/255)

        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ─── 背景深灰渐变（淡入）────────────────────────────
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: bgMid.opacity(0.85), location: 0),
                                .init(color: bgDark, location: 0.35),
                                .init(color: bgDark, location: 1)
                            ]),
                            startPoint: CGPoint(x: w * 0.5, y: h),
                            endPoint: CGPoint(x: w * 0.5, y: 0)
                         ))
            }
        }

        // ─── 地板灰烬层（大图淡入）──────────────────────────
        // 下缘一条暖灰 gradient，暗示炉膛底的灰堆。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let floorRect = CGRect(x: 0, y: h * 0.90, width: w, height: h * 0.10)
                ctx.fill(Path(floorRect),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: ashWarm.opacity(0), location: 0),
                                .init(color: ashWarm.opacity(0.55), location: 1)
                            ]),
                            startPoint: CGPoint(x: w * 0.5, y: floorRect.minY),
                            endPoint: CGPoint(x: w * 0.5, y: floorRect.maxY)
                         ))
            }
        }

        // ─── 余烬广域暖光（大图淡入）─────────────────────────
        // v1.2.1 新增：与 R&B/Liquor 右下暖光晕对齐。原先 Ember 只有一个像素
        // 级亮点，Rock 频道整屏近全黑，横切到 Liquor（右下暖光晕）亮度跃迁
        // 太大。这里给 ember 位置加一圈低不透明的暖光晕（opacity 0.30、
        // radius ~0.52），余烬周围有一块「被烤暖的空气」，场景温度升到
        // 和 Liquor 同一个量级，但仍是 Fog 冷底主导——不破坏克制温度。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let glowCx = w * 0.52
                let glowCy = h * 0.84
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: emberEdge.opacity(0.30), location: 0),
                                .init(color: bgMid.opacity(0.20), location: 0.45),
                                .init(color: bgDark.opacity(0), location: 1)
                            ]),
                            center: CGPoint(x: glowCx, y: glowCy),
                            startRadius: 0, endRadius: max(w, h) * 0.52
                         ))
            }
        }

        // ─── 炭木堆（大图淡入）──────────────────────────────
        // 后方斜柴 + 前方横柴两根交叠，主余烬坐在顶上。
        // 高频让橙色裂缝脉动——木头里还剩一点活火。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawCharLog(
                    ctx: ctx,
                    centerX: w * 0.46, centerY: h * 0.845,
                    length: w * 0.46, thickness: h * 0.026, angle: -0.20,
                    charcoal: charcoal, light: charcoalHi,
                    emberCore: emberCore, treble: treble, seed: 0.3
                )
                drawCharLog(
                    ctx: ctx,
                    centerX: w * 0.52, centerY: h * 0.882,
                    length: w * 0.56, thickness: h * 0.036, angle: 0.04,
                    charcoal: charcoal, light: charcoalHi,
                    emberCore: emberCore, treble: treble, seed: 1.1
                )
            }
        }

        // 主余烬 —— 连续 morph 物体
        // big pose 调到 0.83h，让余烬正好坐在前方横柴顶面上方。
        let mainEmber = EmberSpec(
            cx: 0.48 + (0.52 - 0.48) * e,
            cyBase: 0.80 + (0.83 - 0.80) * e,
            radius: 0.040 + (0.028 - 0.040) * e,
            seed: 0.0,
            lenFactor: 0.75 + (0.82 - 0.75) * e
        )

        // 小图的 smoke 自己的顶部 fade 由 stroke alpha 衰减处理
        drawSmoke(context: context, w: w, h: h, ember: mainEmber,
                  spectrumData: spectrumData, binCount: binCount,
                  mid: mid, treble: treble, idleBlend: idleBlend, t: t,
                  smokeCool: smokeCool, smokeWarm: smokeWarm)

        drawEmber(context: context, w: w, h: h, ember: mainEmber,
                  bass: bass, idleBlend: idleBlend, t: t,
                  core: emberCore, midColor: emberMid, edge: emberEdge)

        // 顶部淡出遮罩 —— 仅在大图 pose 显示
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let mainTopY = mainEmber.cyBase * h - mainEmber.lenFactor * h
                let fadeRect = CGRect(x: 0, y: mainTopY - h * 0.02, width: w, height: h * 0.25)
                ctx.fill(Path(fadeRect),
                         with: .linearGradient(
                            Gradient(colors: [
                                Color.black.opacity(0.0),
                                Color(red: 32/255, green: 26/255, blue: 22/255).opacity(0.9)
                            ]),
                            startPoint: CGPoint(x: w * 0.5, y: fadeRect.maxY),
                            endPoint: CGPoint(x: w * 0.5, y: fadeRect.minY)
                         ))
            }
        }
    }

    // MARK: - Charred log

    private func drawCharLog(
        ctx: GraphicsContext, centerX: CGFloat, centerY: CGFloat,
        length: CGFloat, thickness: CGFloat, angle: CGFloat,
        charcoal: Color, light: Color, emberCore: Color,
        treble: Float, seed: Double
    ) {
        let transform = CGAffineTransform(translationX: centerX, y: centerY)
            .rotated(by: angle)

        // 地面阴影（柔长椭圆，在柴下方）
        let shadowRect = CGRect(
            x: -length * 0.5 - 2,
            y: thickness * 0.35,
            width: length + 4,
            height: thickness * 1.2
        )
        let shadowPath = Path(ellipseIn: shadowRect).applying(transform)
        ctx.fill(shadowPath, with: .color(Color.black.opacity(0.38)))

        // 木柴本体（炭黑渐变）
        let logRect = CGRect(
            x: -length * 0.5, y: -thickness * 0.5,
            width: length, height: thickness
        )
        let logPath = Path(roundedRect: logRect, cornerRadius: thickness * 0.38)
            .applying(transform)

        ctx.fill(logPath,
                 with: .linearGradient(
                    Gradient(colors: [light, charcoal]),
                    startPoint: CGPoint(x: centerX, y: centerY - thickness * 0.5),
                    endPoint: CGPoint(x: centerX, y: centerY + thickness * 0.5)
                 ))

        // 顶部一线暗高光（侧光从上打）
        var topHL = Path()
        let hlInset: CGFloat = thickness * 0.45
        topHL.move(to: CGPoint(x: -length * 0.5 + hlInset, y: -thickness * 0.28))
        topHL.addLine(to: CGPoint(x: length * 0.5 - hlInset, y: -thickness * 0.28))
        let topHLPath = topHL.applying(transform)
        ctx.stroke(topHLPath, with: .color(light.opacity(0.50)), lineWidth: 0.6)

        // 橙色裂缝 —— 3 条，高频驱动亮度（还剩一点活火）
        for i in 0..<3 {
            let u: CGFloat = 0.22 + CGFloat(i) * 0.26
            let cx: CGFloat = -length * 0.5 + length * u
            let jitter: CGFloat = CGFloat(sin(seed * 3.5 + Double(i))) * 0.25 + 1
            let crackLen: CGFloat = length * 0.08 * jitter
            var crack = Path()
            crack.move(to: CGPoint(x: cx - crackLen * 0.5, y: 0))
            crack.addLine(to: CGPoint(x: cx + crackLen * 0.5, y: 0))
            let crackPath = crack.applying(transform)
            let tPulse = 0.40 + Double(treble) * 0.45
            ctx.stroke(crackPath, with: .color(emberCore.opacity(tPulse)), lineWidth: 1.1)
        }
    }

    // MARK: - Ember

    private func drawEmber(context: GraphicsContext, w: CGFloat, h: CGFloat,
                           ember e: EmberSpec, bass: Float, idleBlend: Float, t: Float,
                           core: Color, midColor: Color, edge: Color) {
        let pulse = bass * (1 - idleBlend) + (0.45 + sinf(t * 1.2 + Float(e.seed)) * 0.25) * idleBlend
        let pulseCG = CGFloat(pulse)
        let cx = e.cx * w
        let cy = e.cyBase * h
        let r = e.radius * w * (0.85 + pulseCG * 0.6)

        let halo = r * 2.8
        let haloRect = CGRect(x: cx - halo, y: cy - halo, width: halo * 2, height: halo * 2)
        context.fill(Path(ellipseIn: haloRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            edge.opacity(0.55 + Double(pulseCG) * 0.25),
                            edge.opacity(0)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: halo
                     ))

        let midR = r * 1.6
        let midRect = CGRect(x: cx - midR, y: cy - midR, width: midR * 2, height: midR * 2)
        context.fill(Path(ellipseIn: midRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            midColor.opacity(0.85),
                            midColor.opacity(0)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: midR
                     ))

        let coreRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: coreRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            core.opacity(0.95 + Double(pulseCG) * 0.05),
                            core.opacity(0.3)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: r
                     ))
    }

    private func drawSmoke(context: GraphicsContext, w: CGFloat, h: CGFloat,
                           ember e: EmberSpec,
                           spectrumData: [Float], binCount: Int,
                           mid: Float, treble: Float,
                           idleBlend: Float, t: Float,
                           smokeCool: Color, smokeWarm: Color) {
        let cx = e.cx * w
        let cyBase = e.cyBase * h
        let smokeLen = e.lenFactor * h

        let steps = 36
        var points: [CGPoint] = []
        let midCG = CGFloat(mid * (1 - idleBlend) + 0.45 * idleBlend)
        let trebleCG = CGFloat(treble * (1 - idleBlend) + 0.12 * idleBlend)

        for s in 0...steps {
            let sf = CGFloat(s) / CGFloat(steps)
            let y = cyBase - sf * smokeLen

            let binF = Float(sf) * Float(binCount - 1) * 0.85
            let binIdx = min(binCount - 1, max(0, Int(binF)))
            let binVal = CGFloat(spectrumData[binIdx])

            let primary = sinf(Float(sf) * 4.2 + t * 0.8 + Float(e.seed)) * 0.6
            let secondary = sinf(Float(sf) * 9 + t * 1.3 + Float(e.seed) * 2) * 0.25
            let baseBend = CGFloat(primary + secondary) * 0.4

            let phase = sinf(Float(binIdx) * 0.7 + t * 0.3 + Float(e.seed) * 1.3)
            let spectrumBend = CGFloat(phase) * binVal * 2.8

            let bend = (baseBend * midCG + spectrumBend) * w * 0.07 * sf
            let x = cx + bend

            points.append(CGPoint(x: x, y: y))
        }

        let widthFactor: [CGFloat] = [4.0, 2.6, 1.4, 0.7]
        let alphas: [Double] = [0.08, 0.14, 0.22, 0.35]

        for (layerIdx, wf) in widthFactor.enumerated() {
            let strokeW = wf * (1 + CGFloat(trebleCG) * 0.8)
            var path = Path()
            path.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midPt = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
                path.addQuadCurve(to: midPt, control: prev)
                if i == points.count - 1 {
                    path.addLine(to: curr)
                }
            }

            let color = layerIdx == 0 ? smokeWarm : smokeCool
            context.stroke(path, with: .color(color.opacity(alphas[layerIdx])),
                           lineWidth: strokeW)
        }
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

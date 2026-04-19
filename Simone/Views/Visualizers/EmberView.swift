import SwiftUI

// Rock visualizer — Ember & Smoke.
//
// 小图 (expansion=0): 单枚余烬居中、略大。
// 大图 (expansion=1): 主余烬右移缩小、两侧余烬淡入、背景深灰渐变 + 顶部 fade 淡入。
//
// Object: 炭灰房间里的余烬火星，一缕烟升起散开。低频让火星脉冲（吸气时亮起），
// 中频驱动烟丝弯曲，高频让烟尾分叉。
struct EmberView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small (单余烬居中), 1 = big (三余烬 + 背景场景)
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

        // 背景深灰渐变（淡入）
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

        // 主余烬 —— 连续 morph 物体
        let mainEmber = EmberSpec(
            cx: 0.48 + (0.55 - 0.48) * e,
            cyBase: 0.80 + (0.87 - 0.80) * e,
            radius: 0.040 + (0.026 - 0.040) * e,
            seed: 0.0,
            lenFactor: 0.75 + (0.85 - 0.75) * e
        )

        // 小图的 smoke 自己的顶部 fade 由 stroke alpha 衰减处理
        // 大图需要画额外的顶部遮罩（sceneAlpha 淡入）
        drawSmoke(context: context, w: w, h: h, ember: mainEmber,
                  spectrumData: spectrumData, binCount: binCount,
                  mid: mid, treble: treble, idleBlend: idleBlend, t: t,
                  smokeCool: smokeCool, smokeWarm: smokeWarm)

        drawEmber(context: context, w: w, h: h, ember: mainEmber,
                  bass: bass, idleBlend: idleBlend, t: t,
                  core: emberCore, midColor: emberMid, edge: emberEdge)

        // 辅余烬（淡入）
        if sceneAlpha > 0.01 {
            let sideEmbers = [
                EmberSpec(cx: 0.22, cyBase: 0.82, radius: 0.022, seed: 1.7,  lenFactor: 0.78),
                EmberSpec(cx: 0.81, cyBase: 0.79, radius: 0.019, seed: 3.4,  lenFactor: 0.72)
            ]
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                for se in sideEmbers {
                    drawSmoke(context: ctx, w: w, h: h, ember: se,
                              spectrumData: spectrumData, binCount: binCount,
                              mid: mid, treble: treble, idleBlend: idleBlend, t: t,
                              smokeCool: smokeCool, smokeWarm: smokeWarm)
                }
                for se in sideEmbers {
                    drawEmber(context: ctx, w: w, h: h, ember: se,
                              bass: bass, idleBlend: idleBlend, t: t,
                              core: emberCore, midColor: emberMid, edge: emberEdge)
                }
            }
        }

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

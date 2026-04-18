import SwiftUI

// R&B visualizer — Ember & Smoke.
//
// Object: 炭灰房间里一支熄到只剩余烬的香/烟，火星在底部悬着，一缕烟从上方缓缓
// 升起，在接近顶部时散开消失。低频让火星脉冲（像吸气时亮起），中频驱动烟丝弯
// 曲，高频让烟尾分叉。
//
// OKLCH（真值）：
//   bg dark   oklch(0.13 0.015 40) → rgb(32, 26, 22)
//   ember core oklch(0.78 0.18 45) → rgb(246, 156, 72)
//   ember mid  oklch(0.58 0.17 32) → rgb(186, 86, 52)
//   ember edge oklch(0.38 0.12 25) → rgb(120, 54, 42)
//   smoke cool oklch(0.62 0.02 240) → rgb(140, 148, 162)
//   smoke warm oklch(0.48 0.03 50)  → rgb(120, 102, 88)
struct EmberView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderEmbers(context: context, size: size, binCount: binCount)
        }
    }

    private struct EmberSpec {
        let cx: CGFloat     // 0..1 x
        let cyBase: CGFloat // 0..1 y (火星位置)
        let radius: CGFloat // 相对 w
        let seed: Double
        let lenFactor: CGFloat  // smoke 长度相对 h
    }

    private func renderEmbers(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let isBig = density > 1

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

        // 背景：底部暗红余温 → 中部几乎黑 → 顶部偏冷（烟扩散的方向）
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: bgMid.opacity(0.85), location: 0),
                            .init(color: bgDark, location: 0.35),
                            .init(color: bgDark, location: 1)
                        ]),
                        startPoint: CGPoint(x: w * 0.5, y: h),
                        endPoint: CGPoint(x: w * 0.5, y: 0)
                     ))

        // Embers 布局
        let embers: [EmberSpec] = isBig ? [
            EmberSpec(cx: 0.22, cyBase: 0.82, radius: 0.022, seed: 0.0,  lenFactor: 0.78),
            EmberSpec(cx: 0.55, cyBase: 0.87, radius: 0.026, seed: 1.7,  lenFactor: 0.85),
            EmberSpec(cx: 0.81, cyBase: 0.79, radius: 0.019, seed: 3.4,  lenFactor: 0.72)
        ] : [
            EmberSpec(cx: 0.48, cyBase: 0.80, radius: 0.040, seed: 0.0,  lenFactor: 0.75)
        ]

        // 烟（先画 — 在 ember 下层才不遮火）
        for e in embers {
            drawSmoke(context: context, w: w, h: h, ember: e,
                     spectrumData: spectrumData, binCount: binCount,
                     mid: mid, treble: treble, idleBlend: idleBlend, t: t,
                     smokeCool: smokeCool, smokeWarm: smokeWarm)
        }

        // Ember（上层）
        for e in embers {
            drawEmber(context: context, w: w, h: h, ember: e,
                     bass: bass, idleBlend: idleBlend, t: t,
                     core: emberCore, midColor: emberMid, edge: emberEdge)
        }
    }

    private func drawEmber(context: GraphicsContext, w: CGFloat, h: CGFloat,
                          ember e: EmberSpec, bass: Float, idleBlend: Float, t: Float,
                          core: Color, midColor: Color, edge: Color) {
        // bass 脉冲（吸气亮起）
        let pulse = bass * (1 - idleBlend) + (0.45 + sinf(t * 1.2 + Float(e.seed)) * 0.25) * idleBlend
        let pulseCG = CGFloat(pulse)
        let cx = e.cx * w
        let cy = e.cyBase * h
        let r = e.radius * w * (0.85 + pulseCG * 0.6)

        // 外晕（宽）
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

        // 中晕
        let mid = r * 1.6
        let midRect = CGRect(x: cx - mid, y: cy - mid, width: mid * 2, height: mid * 2)
        context.fill(Path(ellipseIn: midRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            midColor.opacity(0.85),
                            midColor.opacity(0)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: mid
                     ))

        // 核心
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
        let topY = cyBase - smokeLen

        // 烟丝 = 沿 y 方向分 steps 的 x 偏移 — 频谱 bin 直接塑形。
        // 底部（sf≈0）对应低频，顶部（sf≈1）对应高频；烟每段的水平偏移
        // 是「该高度上那个频段的能量」。音乐越丰富，烟身越扭；静音时只
        // 有轻微正弦基础飘动。这才是频谱理念。
        let steps = 36
        var points: [CGPoint] = []
        let midCG = CGFloat(mid * (1 - idleBlend) + 0.45 * idleBlend)
        let trebleCG = CGFloat(treble * (1 - idleBlend) + 0.12 * idleBlend)

        for s in 0...steps {
            let sf = CGFloat(s) / CGFloat(steps)  // 0 底→1 顶
            let y = cyBase - sf * smokeLen

            // 频谱映射：sf 0→1 对应 bin 0→85% (砍掉最顶那些最高频噪声 bins)
            let binF = Float(sf) * Float(binCount - 1) * 0.85
            let binIdx = min(binCount - 1, max(0, Int(binF)))
            let binVal = CGFloat(spectrumData[binIdx])

            // 基础飘动（sin）— idle 时唯一的运动来源
            let primary = sinf(Float(sf) * 4.2 + t * 0.8 + Float(e.seed)) * 0.6
            let secondary = sinf(Float(sf) * 9 + t * 1.3 + Float(e.seed) * 2) * 0.25
            let baseBend = CGFloat(primary + secondary) * 0.4

            // 频谱塑形：这个 bin 能量推开烟柱
            // 左右方向用 bin 的高位奇偶 + 时间相位，让能量能向两侧扩
            let phase = sinf(Float(binIdx) * 0.7 + t * 0.3 + Float(e.seed) * 1.3)
            let spectrumBend = CGFloat(phase) * binVal * 2.8

            let bend = (baseBend * midCG + spectrumBend) * w * 0.07 * sf  // 越往上摆动越大
            let x = cx + bend

            points.append(CGPoint(x: x, y: y))
        }

        // 分层画 — 多描边层模拟烟的扩散
        let widthFactor: [CGFloat] = [4.0, 2.6, 1.4, 0.7]
        let alphas: [Double] = [0.08, 0.14, 0.22, 0.35]

        for (layerIdx, w_) in widthFactor.enumerated() {
            let strokeW = w_ * (1 + CGFloat(trebleCG) * 0.8)
            var path = Path()
            path.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let mid = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
                path.addQuadCurve(to: mid, control: prev)
                if i == points.count - 1 {
                    path.addLine(to: curr)
                }
            }

            // 渐变色（底部暖 → 顶部冷 → 透明）
            let color = layerIdx == 0 ? smokeWarm : smokeCool
            context.stroke(path, with: .color(color.opacity(alphas[layerIdx])),
                          lineWidth: strokeW)
        }

        // 顶部淡出用一层黑色渐变盖一下
        let fadeRect = CGRect(x: 0, y: topY - h * 0.02, width: w, height: h * 0.25)
        context.fill(Path(fadeRect),
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

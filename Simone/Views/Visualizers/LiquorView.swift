import SwiftUI

// R&B visualizer — Liquor in Glass.
//
// Object: 平底玻璃杯里的威士忌，桌面烛光映在杯身。液面被低频震出波纹，液体
// 内部有光斑（烛反射）随中频漂移，高频让杯口偶尔有一点 rim 反光闪过。
//
// OKLCH（真值）：
//   bg       oklch(0.14 0.015 55) → rgb(35, 30, 25)
//   shadow   oklch(0.24 0.08 55)  → rgb(74, 52, 24)
//   liquid   oklch(0.46 0.14 60)  → rgb(150, 100, 30)
//   highlight oklch(0.72 0.15 70) → rgb(232, 172, 78)
//   rim      oklch(0.82 0.05 75)  → rgb(218, 200, 166)
//   glass    oklch(0.55 0.02 50)  → rgb(138, 128, 118)
struct LiquorView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderLiquor(context: context, size: size, binCount: binCount)
        }
    }

    private struct GlassSpec {
        let cx: CGFloat      // 0..1
        let cyBase: CGFloat  // 0..1, 杯底
        let width: CGFloat   // 相对 w
        let height: CGFloat  // 相对 h
        let fillLevel: CGFloat  // 0..1, 液面位置（从杯底起）
        let taper: CGFloat   // 0..0.2, 上收
        let seed: Double
    }

    private func renderLiquor(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let isBig = density > 1

        let bg        = Color(red: 35/255,  green: 30/255,  blue: 25/255)
        let bgWarm    = Color(red: 58/255,  green: 42/255,  blue: 28/255)
        let shadow    = Color(red: 74/255,  green: 52/255,  blue: 24/255)
        let liquid    = Color(red: 150/255, green: 100/255, blue: 30/255)
        let highlight = Color(red: 232/255, green: 172/255, blue: 78/255)
        let rim       = Color(red: 218/255, green: 200/255, blue: 166/255)
        let glass     = Color(red: 138/255, green: 128/255, blue: 118/255)

        // 频段
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

        // 背景：只在大图画满格暖光。小图里让杯子直接漂在 immersive
        // 底色上，signature 元素抠出来，不成框。
        if isBig {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: bgWarm.opacity(0.65), location: 0),
                                .init(color: bg, location: 0.7),
                                .init(color: bg, location: 1)
                            ]),
                            center: CGPoint(x: w * 0.75, y: h * 0.92),
                            startRadius: 0, endRadius: max(w, h) * 0.85
                         ))
        }

        // 布置玻璃杯
        let glasses: [GlassSpec] = isBig ? [
            GlassSpec(cx: 0.32, cyBase: 0.84, width: 0.30, height: 0.45,
                     fillLevel: 0.62, taper: 0.08, seed: 0.0),
            GlassSpec(cx: 0.74, cyBase: 0.87, width: 0.23, height: 0.32,
                     fillLevel: 0.55, taper: 0.12, seed: 1.9)
        ] : [
            GlassSpec(cx: 0.50, cyBase: 0.82, width: 0.50, height: 0.60,
                     fillLevel: 0.60, taper: 0.06, seed: 0.0)
        ]

        for g in glasses {
            drawGlass(context: context, w: w, h: h, spec: g,
                     spectrumData: spectrumData, binCount: binCount,
                     bass: bass, mid: mid, treble: treble, idleBlend: idleBlend, t: t,
                     shadow: shadow, liquid: liquid, highlight: highlight,
                     rim: rim, glass: glass, bg: bg)
        }
    }

    private func drawGlass(context: GraphicsContext, w: CGFloat, h: CGFloat,
                          spec g: GlassSpec,
                          spectrumData: [Float], binCount: Int,
                          bass: Float, mid: Float, treble: Float,
                          idleBlend: Float, t: Float,
                          shadow: Color, liquid: Color, highlight: Color,
                          rim: Color, glass: Color, bg: Color) {
        let cx = g.cx * w
        let cyBase = g.cyBase * h
        let gw = g.width * w
        let gh = g.height * h
        let taperX = gw * g.taper

        // 杯子轮廓点
        let botLeft  = CGPoint(x: cx - gw * 0.5, y: cyBase)
        let botRight = CGPoint(x: cx + gw * 0.5, y: cyBase)
        let topLeft  = CGPoint(x: cx - gw * 0.5 + taperX, y: cyBase - gh)
        let topRight = CGPoint(x: cx + gw * 0.5 - taperX, y: cyBase - gh)

        // 杯底阴影（桌面倒影）
        let tableEll = CGRect(x: botLeft.x - gw * 0.08,
                             y: cyBase - 2,
                             width: gw + gw * 0.16,
                             height: gh * 0.12)
        context.fill(Path(ellipseIn: tableEll),
                     with: .radialGradient(
                        Gradient(colors: [shadow.opacity(0.55), shadow.opacity(0)]),
                        center: CGPoint(x: cx, y: cyBase + gh * 0.04),
                        startRadius: 0, endRadius: gw * 0.55
                     ))

        // 液面 y（随 bass 震一点）
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.35 * idleBlend)
        let levelY = cyBase - gh * g.fillLevel + (bassCG - 0.5) * gh * 0.03

        // 液面处杯子宽度（线性插值）
        let levelRatio = 1 - g.fillLevel  // 0 杯底..1 杯口
        let levelTaperX = taperX * levelRatio
        let liquidLeftX = cx - gw * 0.5 + levelTaperX
        let liquidRightX = cx + gw * 0.5 - levelTaperX

        // 液体区域
        var liquidPath = Path()
        liquidPath.move(to: botLeft)
        liquidPath.addLine(to: botRight)
        liquidPath.addLine(to: CGPoint(x: liquidRightX, y: levelY))
        // 液面 = 杯中频谱曲线。横跨 24 段，每段读对应 bin 向上抬起液面；
        // 左→右对应 bin 低→高频（bass 在左，treble 在右）。音乐进来时
        // 整个液面变成能量起伏的天际线；静音时只剩 sin 基础波纹。
        let waveSegments = 24
        let baseWaveAmp = CGFloat(bassCG) * gh * 0.012 + 0.6
        let specLiftMax = gh * 0.10  // 最大抬升幅度（相对液面深度 ~17%）
        for i in stride(from: waveSegments, through: 0, by: -1) {
            let sf = CGFloat(i) / CGFloat(waveSegments)
            let x = liquidLeftX + (liquidRightX - liquidLeftX) * sf

            let binF = (0.08 + sf * 0.72) * CGFloat(binCount - 1)
            let binIdx = min(binCount - 1, max(0, Int(binF)))
            let binVal = CGFloat(spectrumData[binIdx])

            let baseDy = sinf(Float(sf) * 6.3 + t * 2.2 + Float(g.seed)) * Float(baseWaveAmp)
            let specLift = binVal * specLiftMax * CGFloat(1 - idleBlend)
            // 液面向上抬 = y 减小
            let dy = CGFloat(baseDy) - specLift
            liquidPath.addLine(to: CGPoint(x: x, y: levelY + dy))
        }
        liquidPath.closeSubpath()

        // 填充液体（上浅下深）
        context.fill(liquidPath,
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: highlight.opacity(0.75), location: 0),
                            .init(color: liquid, location: 0.35),
                            .init(color: shadow, location: 1)
                        ]),
                        startPoint: CGPoint(x: cx, y: levelY),
                        endPoint: CGPoint(x: cx, y: cyBase)
                     ))

        // 液体里的烛光光斑（随 mid 漂移）
        let midCG = CGFloat(mid * (1 - idleBlend) + 0.45 * idleBlend)
        let glimmerFrac = 0.35 + CGFloat(sinf(t * 0.9 + Float(g.seed))) * 0.25 * midCG
        let glimmerX = liquidLeftX + (liquidRightX - liquidLeftX) * glimmerFrac
        let glimmerY = levelY + (cyBase - levelY) * 0.35
        let glimmerR = gw * 0.08
        let glimmerRect = CGRect(x: glimmerX - glimmerR, y: glimmerY - glimmerR * 0.6,
                                width: glimmerR * 2, height: glimmerR * 1.2)
        context.fill(Path(ellipseIn: glimmerRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            highlight.opacity(0.85),
                            highlight.opacity(0)
                        ]),
                        center: CGPoint(x: glimmerX, y: glimmerY),
                        startRadius: 0, endRadius: glimmerR
                     ))

        // 液面亮线（meniscus）— 跟随液面频谱曲线
        var meniscus = Path()
        meniscus.move(to: CGPoint(x: liquidLeftX, y: levelY))
        for i in 0...waveSegments {
            let sf = CGFloat(i) / CGFloat(waveSegments)
            let x = liquidLeftX + (liquidRightX - liquidLeftX) * sf
            let binF = (0.08 + sf * 0.72) * CGFloat(binCount - 1)
            let binIdx = min(binCount - 1, max(0, Int(binF)))
            let binVal = CGFloat(spectrumData[binIdx])
            let baseDy = sinf(Float(sf) * 6.3 + t * 2.2 + Float(g.seed)) * Float(baseWaveAmp)
            let specLift = binVal * specLiftMax * CGFloat(1 - idleBlend)
            let dy = CGFloat(baseDy) - specLift
            meniscus.addLine(to: CGPoint(x: x, y: levelY + dy))
        }
        context.stroke(meniscus, with: .color(highlight.opacity(0.55)), lineWidth: 0.9)

        // 杯子轮廓（细线）
        var glassPath = Path()
        glassPath.move(to: botLeft)
        glassPath.addLine(to: topLeft)
        context.stroke(glassPath, with: .color(glass.opacity(0.5)), lineWidth: 1)

        var glassPath2 = Path()
        glassPath2.move(to: botRight)
        glassPath2.addLine(to: topRight)
        context.stroke(glassPath2, with: .color(glass.opacity(0.5)), lineWidth: 1)

        // 杯底
        var bottomPath = Path()
        bottomPath.move(to: botLeft)
        bottomPath.addLine(to: botRight)
        context.stroke(bottomPath, with: .color(glass.opacity(0.7)), lineWidth: 1.5)

        // 杯口椭圆（细线示意）
        let rimRectBack = CGRect(x: topLeft.x, y: topLeft.y - gh * 0.02,
                                width: topRight.x - topLeft.x, height: gh * 0.04)
        context.stroke(Path(ellipseIn: rimRectBack),
                      with: .color(glass.opacity(0.4)), lineWidth: 0.8)

        // 右侧 rim 反光（偶尔被 treble 触发）
        if treble > 0.06 {
            let rimYStart = topRight.y + gh * 0.06
            let rimYEnd = cyBase - gh * 0.08
            var rimPath = Path()
            rimPath.move(to: CGPoint(x: topRight.x - 1, y: rimYStart))
            rimPath.addLine(to: CGPoint(x: cx + gw * 0.5 - 1, y: rimYEnd))
            context.stroke(rimPath,
                          with: .color(rim.opacity(Double(treble) * 2.5)),
                          lineWidth: 1.2)
        }
    }
}

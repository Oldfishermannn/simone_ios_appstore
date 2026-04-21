import SwiftUI

// R&B visualizer — Whiskey on the Bar.
//
// 小图 (expansion=0): 主杯居中、略大、正面。
// 大图 (expansion=1): 主杯左移缩小，后景淡入吧台水平线 + 软木杯垫 +
// 右后方威士忌瓶（decanter）+ 铜色瓶塞。场景叙事：深夜酒吧吧台一隅。
//
// 物体连续 morph：主杯始终是同一只玻璃杯，width/height/position 线性
// 插值，液面 bass 脉冲。场景物件走 sceneAlpha smoothstep(0.30, 0.88)
// 淡入，和 Jazz/Lo-fi 的大图扩展节奏一致。
struct LiquorView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small (单杯居中), 1 = big (主杯 + coaster + decanter + 吧台)
    var expansion: CGFloat = 1.0

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
        let fillLevel: CGFloat
        let taper: CGFloat
        let seed: Double
    }

    private func renderLiquor(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let e: CGFloat = max(0, min(1, expansion))
        let sceneAlpha: Double = smoothstep(0.30, 0.88, Double(e))

        let bg        = Color(red: 35/255,  green: 30/255,  blue: 25/255)
        let bgWarm    = Color(red: 58/255,  green: 42/255,  blue: 28/255)
        let shadow    = Color(red: 74/255,  green: 52/255,  blue: 24/255)
        let liquid    = Color(red: 150/255, green: 100/255, blue: 30/255)
        let highlight = Color(red: 232/255, green: 172/255, blue: 78/255)
        let rim       = Color(red: 218/255, green: 200/255, blue: 166/255)
        let glass     = Color(red: 138/255, green: 128/255, blue: 118/255)
        let corkDark  = Color(red:  52/255, green:  38/255, blue:  26/255)
        let corkLight = Color(red:  92/255, green:  68/255, blue:  48/255)
        let corkSeam  = Color(red: 156/255, green: 124/255, blue:  82/255)
        let brass     = Color(red: 180/255, green: 130/255, blue:  70/255)
        let brassDark = Color(red: 100/255, green:  70/255, blue:  40/255)

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

        // ─── 背景径向暖光晕（淡入）────────────────────────────
        // v1.2.1 收敛：原 0.65 opacity × 0.85 radius 的大面积暖黄覆盖了 60-70%
        // 屏幕，和 Rock/Ember 的冷暗底在横切频道时亮度落差过大（眼睛不适）。
        // 按 Fog 原则 #3「暖意点缀、底色冷雾」压回：opacity 0.35、radius 0.55，
        // 让暖只在右下酒杯附近生效，屏幕大半回到冷雾底。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: bgWarm.opacity(0.35), location: 0),
                                .init(color: bg.opacity(0.88), location: 0.5),
                                .init(color: bg, location: 1)
                            ]),
                            center: CGPoint(x: w * 0.78, y: h * 0.94),
                            startRadius: 0, endRadius: max(w, h) * 0.55
                         ))
            }
        }

        // 主杯几何（用于 coaster/decanter 几何关联）
        // 小图 (e=0): 威士忌 rocks glass 样式 — 矮胖、直筒微外张、贴下。
        //   cyBase 0.92 贴底；height 0.36 ~ width 0.46 约 0.78 比例（威士忌杯典型）；
        //   taper -0.03 杯口略宽于杯底 3%（经典 rocks glass 侧壁微外张）；
        //   fillLevel 0.62 酒装过半（威士忌通常装 1/3 ~ 1/2，但视觉上过半更有料）。
        // 大图 (e=1): 仍是威士忌杯形 — 保持 rocks glass 一致性，只是缩小左移。
        // v1.3 iter2：CEO 反馈"像啤酒杯"，再夸张矮胖：
        //   小图 width 0.52 宽 × height 0.26 矮 ≈ 0.50 比例（比 tumbler 还扁）
        //   taper -0.06 杯口比杯底宽 6%（明显外张 = rocks glass 签名侧壁）
        let mainSpec = GlassSpec(
            cx: 0.50 + (0.32 - 0.50) * e,
            cyBase: 0.93 + (0.87 - 0.93) * e,
            width: 0.52 + (0.34 - 0.52) * e,
            height: 0.26 + (0.22 - 0.26) * e,
            fillLevel: 0.55 + (0.55 - 0.55) * e,
            taper: -0.06 + (-0.02 - (-0.06)) * e,
            seed: 0.0
        )

        // ─── 吧台水平线（大图淡入）─────────────────────────
        // 一条跨屏暖棕色 highlight，模拟桌面反光接缝。压在暖光晕之上、
        // 主物件之下。用渐变 alpha 让两端柔化进黑底。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let lineY = mainSpec.cyBase * h + 3
                let lineRect = CGRect(x: 0, y: lineY, width: w, height: 1.1)
                ctx.fill(Path(lineRect),
                         with: .linearGradient(
                            Gradient(colors: [
                                corkSeam.opacity(0),
                                corkSeam.opacity(0.55),
                                corkSeam.opacity(0)
                            ]),
                            startPoint: CGPoint(x: 0, y: lineY),
                            endPoint: CGPoint(x: w, y: lineY)
                         ))
            }
        }

        // ─── Coaster（软木杯垫，大图淡入）─────────────────
        // 扁椭圆（俯视透视感），径向 gradient（cork 质感），细圈边。
        // 画在主杯之前，让主杯自己的桌面阴影自然压在垫子上。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let mainW = mainSpec.width * w
                let mainCx = mainSpec.cx * w
                let mainCyBase = mainSpec.cyBase * h
                let coasterW = mainW * 1.32
                let coasterH = coasterW * 0.22
                let coasterRect = CGRect(
                    x: mainCx - coasterW / 2,
                    y: mainCyBase - coasterH * 0.35,
                    width: coasterW, height: coasterH
                )
                ctx.fill(Path(ellipseIn: coasterRect),
                         with: .radialGradient(
                            Gradient(colors: [corkLight, corkDark]),
                            center: CGPoint(x: coasterRect.midX,
                                            y: coasterRect.minY + coasterH * 0.35),
                            startRadius: 0, endRadius: coasterW * 0.55
                         ))
                ctx.stroke(Path(ellipseIn: coasterRect),
                           with: .color(corkSeam.opacity(0.32)), lineWidth: 0.6)
            }
        }

        // ─── 主杯（连续 morph 物体）─────────────────────
        drawGlass(context: context, w: w, h: h, spec: mainSpec,
                  spectrumData: spectrumData, binCount: binCount,
                  bass: bass, mid: mid, treble: treble, idleBlend: idleBlend, t: t,
                  shadow: shadow, liquid: liquid, highlight: highlight,
                  rim: rim, glass: glass)

        // ─── Decanter（威士忌酒瓶，大图淡入）────────────
        // 主杯右后方，宽肩方瓶身 + 过渡肩线 + 细颈 + 铜色球型瓶塞。
        // 瓶内液面和主杯同色同逻辑（bass 脉冲），静一半的幅度——伴随
        // 物件不抢戏。
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawDecanter(
                    ctx: ctx, w: w, h: h,
                    bass: bass, idleBlend: idleBlend, t: t,
                    shadow: shadow, liquid: liquid, highlight: highlight, glass: glass,
                    brass: brass, brassDark: brassDark
                )
            }
        }
    }

    // MARK: - Decanter

    private func drawDecanter(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        bass: Float, idleBlend: Float, t: Float,
        shadow: Color, liquid: Color, highlight: Color, glass: Color,
        brass: Color, brassDark: Color
    ) {
        // 几何
        let bottleCx: CGFloat = w * 0.74
        let bottleBaseY: CGFloat = h * 0.84
        let totalHeight: CGFloat = h * 0.50
        let bodyWidth: CGFloat = w * 0.16
        let neckWidth: CGFloat = w * 0.048

        let shoulderH: CGFloat = totalHeight * 0.12
        let neckH: CGFloat = totalHeight * 0.24
        let stopperH: CGFloat = totalHeight * 0.09
        let bodyH: CGFloat = totalHeight - shoulderH - neckH - stopperH

        let bodyLeftX = bottleCx - bodyWidth / 2
        let bodyRightX = bottleCx + bodyWidth / 2
        let neckLeftX = bottleCx - neckWidth / 2
        let neckRightX = bottleCx + neckWidth / 2

        let bodyTopY = bottleBaseY - bodyH
        let shoulderTopY = bodyTopY - shoulderH
        let neckTopY = shoulderTopY - neckH
        let stopperTopY = neckTopY - stopperH

        // 桌面阴影（椭圆）
        let shadowEll = CGRect(
            x: bodyLeftX - bodyWidth * 0.12,
            y: bottleBaseY - 2,
            width: bodyWidth * 1.24,
            height: bodyWidth * 0.32
        )
        ctx.fill(Path(ellipseIn: shadowEll),
                 with: .radialGradient(
                    Gradient(colors: [shadow.opacity(0.55), shadow.opacity(0)]),
                    center: CGPoint(x: bottleCx, y: bottleBaseY + bodyWidth * 0.08),
                    startRadius: 0, endRadius: bodyWidth * 0.7
                 ))

        // 瓶身外形 (方肩梯形 → 圆过渡 → 细颈)
        var bottle = Path()
        bottle.move(to: CGPoint(x: bodyLeftX, y: bottleBaseY))
        bottle.addLine(to: CGPoint(x: bodyLeftX, y: bodyTopY))
        bottle.addQuadCurve(
            to: CGPoint(x: neckLeftX, y: shoulderTopY),
            control: CGPoint(x: bodyLeftX, y: shoulderTopY + shoulderH * 0.15)
        )
        bottle.addLine(to: CGPoint(x: neckLeftX, y: neckTopY))
        bottle.addLine(to: CGPoint(x: neckRightX, y: neckTopY))
        bottle.addLine(to: CGPoint(x: neckRightX, y: shoulderTopY))
        bottle.addQuadCurve(
            to: CGPoint(x: bodyRightX, y: bodyTopY),
            control: CGPoint(x: bodyRightX, y: shoulderTopY + shoulderH * 0.15)
        )
        bottle.addLine(to: CGPoint(x: bodyRightX, y: bottleBaseY))
        bottle.closeSubpath()

        // 瓶内液面（bass 脉冲，幅度为主杯一半——伴物件不抢戏）
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.35 * idleBlend)
        let liquidLevel = bodyTopY + bodyH * (0.45 - (bassCG - 0.5) * 0.04)
        let levelWobble = CGFloat(sinf(t * 1.5)) * h * 0.003 * CGFloat(1 - idleBlend)

        var liquidShape = Path()
        liquidShape.move(to: CGPoint(x: bodyLeftX, y: bottleBaseY))
        liquidShape.addLine(to: CGPoint(x: bodyRightX, y: bottleBaseY))
        liquidShape.addLine(to: CGPoint(x: bodyRightX, y: liquidLevel + levelWobble))
        liquidShape.addLine(to: CGPoint(x: bodyLeftX, y: liquidLevel - levelWobble))
        liquidShape.closeSubpath()

        ctx.fill(liquidShape,
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: highlight.opacity(0.55), location: 0),
                        .init(color: liquid, location: 0.35),
                        .init(color: shadow, location: 1)
                    ]),
                    startPoint: CGPoint(x: bottleCx, y: liquidLevel),
                    endPoint: CGPoint(x: bottleCx, y: bottleBaseY)
                 ))

        // 液面反光线
        var meniscus = Path()
        meniscus.move(to: CGPoint(x: bodyLeftX + 1, y: liquidLevel - levelWobble))
        meniscus.addLine(to: CGPoint(x: bodyRightX - 1, y: liquidLevel + levelWobble))
        ctx.stroke(meniscus, with: .color(highlight.opacity(0.48)), lineWidth: 0.7)

        // 瓶身外形描边（整体玻璃）
        ctx.stroke(bottle, with: .color(glass.opacity(0.55)), lineWidth: 1.0)

        // 左侧 rim 高光（侧光反射，从右下暖光来）
        var leftHL = Path()
        leftHL.move(to: CGPoint(x: bodyLeftX + 2.2, y: bodyTopY + 8))
        leftHL.addLine(to: CGPoint(x: bodyLeftX + 2.2, y: bottleBaseY - 8))
        ctx.stroke(leftHL, with: .color(highlight.opacity(0.22)), lineWidth: 1.4)

        // 瓶颈左侧一条
        var neckHL = Path()
        neckHL.move(to: CGPoint(x: neckLeftX + 1.2, y: neckTopY + 3))
        neckHL.addLine(to: CGPoint(x: neckLeftX + 1.2, y: shoulderTopY - 1))
        ctx.stroke(neckHL, with: .color(highlight.opacity(0.28)), lineWidth: 0.9)

        // 瓶塞（铜色球型）
        let stopperW = neckWidth * 1.55
        let stopperCy = stopperTopY + stopperH / 2
        let stopperRect = CGRect(
            x: bottleCx - stopperW / 2,
            y: stopperTopY,
            width: stopperW,
            height: stopperH
        )
        ctx.fill(Path(roundedRect: stopperRect, cornerRadius: stopperW * 0.28),
                 with: .linearGradient(
                    Gradient(colors: [brass, brassDark]),
                    startPoint: CGPoint(x: bottleCx, y: stopperRect.minY),
                    endPoint: CGPoint(x: bottleCx, y: stopperRect.maxY)
                 ))
        // 瓶塞侧光高光
        var stopperHL = Path()
        stopperHL.move(to: CGPoint(x: stopperRect.minX + 2, y: stopperCy - 1.5))
        stopperHL.addLine(to: CGPoint(x: stopperRect.minX + 2, y: stopperCy + 1.5))
        ctx.stroke(stopperHL, with: .color(highlight.opacity(0.55)), lineWidth: 0.7)
    }

    // MARK: - 主杯

    private func drawGlass(context: GraphicsContext, w: CGFloat, h: CGFloat,
                           spec g: GlassSpec,
                           spectrumData: [Float], binCount: Int,
                           bass: Float, mid: Float, treble: Float,
                           idleBlend: Float, t: Float,
                           shadow: Color, liquid: Color, highlight: Color,
                           rim: Color, glass: Color) {
        let cx = g.cx * w
        let cyBase = g.cyBase * h
        let gw = g.width * w
        let gh = g.height * h
        let taperX = gw * g.taper

        let botLeft  = CGPoint(x: cx - gw * 0.5, y: cyBase)
        let botRight = CGPoint(x: cx + gw * 0.5, y: cyBase)
        let topLeft  = CGPoint(x: cx - gw * 0.5 + taperX, y: cyBase - gh)
        let topRight = CGPoint(x: cx + gw * 0.5 - taperX, y: cyBase - gh)

        // 桌面阴影（压在 coaster 上）
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

        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.35 * idleBlend)
        let levelY = cyBase - gh * g.fillLevel + (bassCG - 0.5) * gh * 0.03

        let levelRatio = 1 - g.fillLevel
        let levelTaperX = taperX * levelRatio
        let liquidLeftX = cx - gw * 0.5 + levelTaperX
        let liquidRightX = cx + gw * 0.5 - levelTaperX

        var liquidPath = Path()
        liquidPath.move(to: botLeft)
        liquidPath.addLine(to: botRight)
        liquidPath.addLine(to: CGPoint(x: liquidRightX, y: levelY))
        let waveSegments = 24
        let baseWaveAmp = CGFloat(bassCG) * gh * 0.012 + 0.6
        let specLiftMax = gh * 0.10
        for i in stride(from: waveSegments, through: 0, by: -1) {
            let sf = CGFloat(i) / CGFloat(waveSegments)
            let x = liquidLeftX + (liquidRightX - liquidLeftX) * sf
            let binF = (0.08 + sf * 0.72) * CGFloat(binCount - 1)
            let binIdx = min(binCount - 1, max(0, Int(binF)))
            let binVal = CGFloat(spectrumData[binIdx])
            let baseDy = sinf(Float(sf) * 6.3 + t * 2.2 + Float(g.seed)) * Float(baseWaveAmp)
            let specLift = binVal * specLiftMax * CGFloat(1 - idleBlend)
            let dy = CGFloat(baseDy) - specLift
            liquidPath.addLine(to: CGPoint(x: x, y: levelY + dy))
        }
        liquidPath.closeSubpath()

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

        var glassPath = Path()
        glassPath.move(to: botLeft)
        glassPath.addLine(to: topLeft)
        context.stroke(glassPath, with: .color(glass.opacity(0.5)), lineWidth: 1)

        var glassPath2 = Path()
        glassPath2.move(to: botRight)
        glassPath2.addLine(to: topRight)
        context.stroke(glassPath2, with: .color(glass.opacity(0.5)), lineWidth: 1)

        var bottomPath = Path()
        bottomPath.move(to: botLeft)
        bottomPath.addLine(to: botRight)
        context.stroke(bottomPath, with: .color(glass.opacity(0.7)), lineWidth: 1.5)

        let rimRectBack = CGRect(x: topLeft.x, y: topLeft.y - gh * 0.02,
                                 width: topRight.x - topLeft.x, height: gh * 0.04)
        context.stroke(Path(ellipseIn: rimRectBack),
                       with: .color(glass.opacity(0.4)), lineWidth: 0.8)

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

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

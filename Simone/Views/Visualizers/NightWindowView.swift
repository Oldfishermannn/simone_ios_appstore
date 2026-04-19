import SwiftUI

// Favorites visualizer — Night Window.
//
// 小图 (expansion≈0): 单扇窗大特写，玻璃占画面 60%+，mullion 十字，窗内暖光。
// 大图 (expansion=1): Seen From The Street — 窗收到中上方的"家窗"比例（横向偏方），
//   前景是雨后湿地面上的 4 格倒影（左右两列，中间 mullion 黑缝）。
//   原"glass / room"方案砍掉，原雨丝/玻璃雨/涟漪全部移除（物件感盖过装饰）。
//
// Impeccable 原则：
//   - 物件感：窗是一件真物，不图表化
//   - 侧光：画面左上角冷月光束（单主光）+ 窗内暖光（副光对冲）
//   - 动而非跳：倒影 bass 呼吸 + mid 驱动的轻微"水膜风纹"
//   - 60-30-10：冷底主导，暖点克制
//   - 延续感：大图是"从街上抬头看这扇窗"，小图是"站到窗前"

struct NightWindowView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0

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

        // ── Palette (Fog City Nocturne)
        let nightDeep     = Color(red: 10/255,  green: 12/255,  blue: 20/255)
        let nightMid      = Color(red: 18/255,  green: 22/255,  blue: 34/255)
        let fogTint       = Color(red: 44/255,  green: 54/255,  blue: 76/255)
        let cityFar       = Color(red: 18/255,  green: 22/255,  blue: 32/255)
        let mullion       = Color(red: 32/255,  green: 26/255,  blue: 22/255)
        let mullionHL     = Color(red: 78/255,  green: 62/255,  blue: 42/255)
        let glassCold     = Color(red: 36/255,  green: 48/255,  blue: 72/255)
        let glassCoolHL   = Color(red: 180/255, green: 196/255, blue: 220/255)
        let warmLamp      = Color(red: 232/255, green: 178/255, blue: 108/255)
        let moonBeam      = Color(red: 196/255, green: 210/255, blue: 228/255)
        let wallDim       = Color(red: 26/255,  green: 28/255,  blue: 36/255)

        // ── Audio buckets
        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.16 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.12 * idleBlend)
        let trebleCG = CGFloat(treble * (1 - idleBlend) + 0.06 * idleBlend)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 600)

        // ── 通用冷夜渐变底
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: nightDeep, location: 0),
                            .init(color: nightMid,  location: 0.5),
                            .init(color: cityFar,   location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                     ))

        // ── 大图场景背景（Street 基底：冷墙 + 湿地砖）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawStreetBG(ctx: ctx, w: w, h: h,
                             wallDim: wallDim, fogTint: fogTint,
                             t: t, midCG: midCG)
            }
        }

        // ── 主窗矩形（小图→大图平滑插值）
        //   小图 0.64w × 0.68h 居中
        //   大图 0.52w × 0.36h 中上偏方（"家窗"比例，不是狭长办公窗）
        let mainSmall = CGRect(x: w * 0.18, y: h * 0.16,
                                width: w * 0.64, height: h * 0.68)
        let mainTarget = CGRect(x: w * 0.24, y: h * 0.14,
                                 width: w * 0.52, height: h * 0.36)
        let mainRect = CGRect(
            x: mainSmall.minX + (mainTarget.minX - mainSmall.minX) * e,
            y: mainSmall.minY + (mainTarget.minY - mainSmall.minY) * e,
            width: mainSmall.width + (mainTarget.width - mainSmall.width) * e,
            height: mainSmall.height + (mainTarget.height - mainSmall.height) * e
        )

        // ── 主窗
        context.drawLayer { ctx in
            drawWindow(
                ctx: ctx, frame: mainRect, lampColor: warmLamp,
                mullion: mullion, mullionHL: mullionHL,
                glassCold: glassCold, glassCoolHL: glassCoolHL,
                warmLamp: warmLamp,
                bassCG: bassCG, midCG: midCG, trebleCG: trebleCG,
                t: t, isMain: true
            )
        }

        // ── 大图前景（地面倒影）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawStreetFG(ctx: ctx, w: w, h: h,
                             windowRect: mainRect,
                             warmLamp: warmLamp,
                             t: t, bassCG: bassCG, midCG: midCG)
            }
        }

        // ── 左上冷月光束（主光方向）
        let beamIntensity = 0.12 + Double(bassCG) * 0.22 + sceneAlpha * 0.06
        if beamIntensity > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = min(0.8, beamIntensity)
                var beam = Path()
                let bx0: CGFloat = -w * 0.12
                let by0: CGFloat = -h * 0.02
                let beamW: CGFloat = w * 0.22
                beam.move(to: CGPoint(x: bx0, y: by0))
                beam.addLine(to: CGPoint(x: bx0 + beamW, y: by0))
                beam.addLine(to: CGPoint(x: bx0 + beamW + w * 1.1, y: by0 + h * 1.15))
                beam.addLine(to: CGPoint(x: bx0 + w * 1.1, y: by0 + h * 1.15))
                beam.closeSubpath()
                ctx.fill(beam,
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: moonBeam.opacity(0.22), location: 0),
                                .init(color: moonBeam.opacity(0.09), location: 0.5),
                                .init(color: moonBeam.opacity(0),    location: 1)
                            ]),
                            startPoint: CGPoint(x: bx0, y: by0),
                            endPoint: CGPoint(x: bx0 + beamW + w * 1.1,
                                              y: by0 + h * 1.15)
                         ))
            }
        }
    }

    // MARK: - Street BG — 冷墙 + 湿地砖 + 地平线雾

    private func drawStreetBG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                                wallDim: Color, fogTint: Color,
                                t: Float, midCG: CGFloat) {
        // 上半部分：冷墙色（比底渐变亮一档）
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .color(wallDim.opacity(0.45)))

        // 湿地面（画面下 38%）
        let groundY = h * 0.62
        ctx.fill(Path(CGRect(x: 0, y: groundY, width: w, height: h - groundY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.black.opacity(0.75), location: 0),
                        .init(color: Color.black.opacity(0.92), location: 1)
                    ]),
                    startPoint: CGPoint(x: 0, y: groundY),
                    endPoint: CGPoint(x: 0, y: h)
                 ))

        // 地砖接缝 —— 水平 5 道
        for i in 0..<5 {
            let ly = groundY + CGFloat(i) * (h - groundY) / 5
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: ly))
                p.addLine(to: CGPoint(x: w, y: ly))
            }, with: .color(Color.black.opacity(0.55)), lineWidth: 0.6)
        }
        // 垂直接缝（少量几条制造地砖块感）
        let verticals: [CGFloat] = [w * 0.14, w * 0.28, w * 0.44, w * 0.58, w * 0.72, w * 0.88]
        for vx in verticals {
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: vx, y: groundY + 6))
                p.addLine(to: CGPoint(x: vx, y: h))
            }, with: .color(Color.black.opacity(0.4)), lineWidth: 0.5)
        }

        // 地平线雾带
        ctx.fill(Path(CGRect(x: 0, y: groundY - 14, width: w, height: 40)),
                 with: .linearGradient(
                    Gradient(colors: [
                        fogTint.opacity(0),
                        fogTint.opacity(0.35 + Double(midCG) * 0.25),
                        fogTint.opacity(0)
                    ]),
                    startPoint: CGPoint(x: 0, y: groundY - 14),
                    endPoint: CGPoint(x: 0, y: groundY + 26)
                 ))
    }

    // MARK: - Street FG — 地面窗光倒影（无雨无涟漪）

    private func drawStreetFG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                                windowRect: CGRect,
                                warmLamp: Color,
                                t: Float, bassCG: CGFloat, midCG: CGFloat) {
        // 倒影从地面顶部开始，向画面底部柔渐弱
        let groundY = h * 0.62
        let refY0 = groundY
        let refY1 = h * 0.95
        let refH = refY1 - refY0
        let halfW = windowRect.width * 0.5
        let leftX = windowRect.midX - halfW
        let midGap: CGFloat = halfW * 0.05

        // mid 驱动的轻微水膜风纹 —— 倒影列整体横向 ±2pt sin 扰动
        let windDrift = CGFloat(sin(Double(t) * 0.8) * Double(midCG) * 2.4)

        // 左列 + 右列 2 个暖光矩形
        let col1Rect = CGRect(x: leftX + windDrift, y: refY0,
                               width: halfW * 0.95, height: refH)
        let col2Rect = CGRect(x: windowRect.midX + midGap + windDrift * 0.6,
                               y: refY0,
                               width: halfW * 0.95, height: refH)

        let reflBreath = 0.38 + Double(bassCG) * 0.30
        for colRect in [col1Rect, col2Rect] {
            ctx.fill(Path(colRect),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: warmLamp.opacity(reflBreath),       location: 0),
                            .init(color: warmLamp.opacity(reflBreath * 0.3), location: 0.7),
                            .init(color: warmLamp.opacity(0),                location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: colRect.minY),
                        endPoint: CGPoint(x: 0, y: colRect.maxY)
                     ))
        }

        // 中央 mullion 倒影（垂直黑缝，顶部实底淡）
        ctx.fill(Path(CGRect(x: windowRect.midX - midGap/2 + windDrift * 0.8,
                               y: refY0, width: midGap, height: refH * 0.6)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0)
                    ]),
                    startPoint: CGPoint(x: 0, y: refY0),
                    endPoint: CGPoint(x: 0, y: refY0 + refH * 0.6)
                 ))

        // 横向 mullion 倒影（淡一道）
        ctx.fill(Path(CGRect(x: leftX + windDrift,
                               y: refY0 + refH * 0.35,
                               width: halfW * 2, height: 2)),
                 with: .color(Color.black.opacity(0.35)))
    }

    // MARK: - Window

    private func drawWindow(ctx: GraphicsContext, frame: CGRect, lampColor: Color,
                             mullion: Color, mullionHL: Color,
                             glassCold: Color, glassCoolHL: Color,
                             warmLamp: Color,
                             bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat,
                             t: Float, isMain: Bool) {
        // 窗 <100pt 远景分支（过渡期瞬时小态，大图不会触发）
        if frame.width < 100 {
            let breathe = 1.0 + Double(bassCG) * 0.55 + sin(Double(t) * 1.8) * 0.08
            let glowR = max(frame.width, frame.height) * CGFloat(3.0 * breathe)
            let glowAlpha = 0.30 + Double(bassCG) * 0.40
            let cx = frame.midX, cy = frame.midY
            ctx.fill(Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR,
                                               width: glowR * 2, height: glowR * 2)),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: lampColor.opacity(glowAlpha * 1.4),  location: 0),
                            .init(color: lampColor.opacity(glowAlpha * 0.45), location: 0.35),
                            .init(color: lampColor.opacity(0),                 location: 1)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: glowR
                     ))
            let lampIntensity = 0.78 + Double(bassCG) * 0.20
                                 + Double(midCG) * 0.08
                                 + sin(Double(t) * 6.2) * Double(midCG) * 0.10
            let interiorCX = frame.minX + frame.width * 0.62
            let interiorCY = frame.minY + frame.height * 0.42
            ctx.fill(Path(frame),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: lampColor.opacity(lampIntensity),        location: 0),
                            .init(color: lampColor.opacity(lampIntensity * 0.75), location: 0.65),
                            .init(color: lampColor.opacity(lampIntensity * 0.55), location: 1)
                        ]),
                        center: CGPoint(x: interiorCX, y: interiorCY),
                        startRadius: 0,
                        endRadius: max(frame.width, frame.height) * 0.9
                     ))
            let mW: CGFloat = max(0.6, frame.width * 0.018)
            let mxC = frame.minX + frame.width * 0.5
            ctx.fill(Path(CGRect(x: mxC - mW / 2, y: frame.minY,
                                  width: mW, height: frame.height)),
                     with: .color(Color.black.opacity(0.50)))
            let myC = frame.minY + frame.height * 0.5
            ctx.fill(Path(CGRect(x: frame.minX, y: myC - mW / 2,
                                  width: frame.width, height: mW)),
                     with: .color(Color.black.opacity(0.50)))
            let strokeW: CGFloat = max(0.7, frame.width * 0.022)
            ctx.stroke(Path(frame), with: .color(Color.black.opacity(0.75)),
                       lineWidth: strokeW)
            return
        }

        // 窗框外圈
        let frameInset: CGFloat = isMain ? 4 : 2.5
        let frameOuter = frame.insetBy(dx: -frameInset, dy: -frameInset)
        ctx.fill(Path(roundedRect: frameOuter, cornerRadius: 1),
                 with: .linearGradient(
                    Gradient(colors: [mullionHL, mullion]),
                    startPoint: CGPoint(x: frameOuter.minX, y: frameOuter.minY),
                    endPoint: CGPoint(x: frameOuter.maxX, y: frameOuter.maxY)
                 ))

        // 玻璃 + 室内暖光
        let lampIntensity = 0.40 + Double(bassCG) * 0.75
                             + Double(sin(Double(t) * 2.1)) * 0.05
        let interiorCenterX = frame.minX + frame.width * 0.60
        let interiorCenterY = frame.midY + frame.height * 0.10
        ctx.fill(Path(frame),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: lampColor.opacity(lampIntensity),        location: 0),
                        .init(color: lampColor.opacity(lampIntensity * 0.45), location: 0.55),
                        .init(color: glassCold.opacity(0.88),                  location: 1)
                    ]),
                    center: CGPoint(x: interiorCenterX, y: interiorCenterY),
                    startRadius: 0, endRadius: max(frame.width, frame.height) * 0.85
                 ))

        // 窗格 mullion 十字
        let mW: CGFloat = isMain ? 1.8 : 1.2
        let mxC = frame.minX + frame.width * 0.50
        ctx.fill(Path(CGRect(x: mxC - mW / 2, y: frame.minY,
                              width: mW, height: frame.height)),
                 with: .color(mullion))
        let myC = frame.minY + frame.height * 0.55
        ctx.fill(Path(CGRect(x: frame.minX, y: myC - mW / 2,
                              width: frame.width, height: mW)),
                 with: .color(mullion))

        // 玻璃冷反光高光（顶部斜向一道）
        var hl = Path()
        let hlY0 = frame.minY + frame.height * 0.10
        let hlY1 = frame.minY + frame.height * 0.28
        hl.move(to: CGPoint(x: frame.minX, y: hlY1))
        hl.addLine(to: CGPoint(x: frame.minX + frame.width * 0.55, y: hlY0))
        hl.addLine(to: CGPoint(x: frame.minX + frame.width * 0.60, y: hlY0))
        hl.addLine(to: CGPoint(x: frame.minX + frame.width * 0.05, y: hlY1))
        hl.closeSubpath()
        ctx.fill(hl, with: .color(glassCoolHL.opacity(0.10 + Double(trebleCG) * 0.12)))

        // 窗框内缘暗阴影
        ctx.stroke(Path(frame), with: .color(Color.black.opacity(0.58)),
                   lineWidth: 1.0)
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

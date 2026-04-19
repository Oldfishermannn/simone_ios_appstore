import SwiftUI

// Favorites visualizer — Night Window (v2, impeccable-iterated).
//
// 小图 (expansion=0): 单扇窗大特写，玻璃占画面 60%，雨滴凝结/下滑，烛焰映在玻璃里。
// 大图 (expansion=1): 非对称三窗构图——主窗偏左下，左上一扇小远窗，右侧一扇被墙切半。
//                     左上侧斜冷光束穿过画面，窗外 3 个暖橙街灯 bokeh 在雾里化开。
//
// Impeccable 原则落实：
//   - 物件感：窗玻璃是一件真的物件——带污渍、积水、反射
//   - 侧光：左上冷光束 + 室内右上暖灯 = 双向侧光，大半阴影
//   - 动而非跳：雨滴 bezier + head drop + 部分静止，不是 bar 式跳动
//   - 克制温度：冷雾蓝底 + 暖烛光点缀（单点、不重复）
//   - 非对称构图：三窗不等大不对齐
//
// Spectrum mapping:
//   - 低频 → 雨滴下落速度 + 窗内灯光呼吸
//   - 中频 → 雾浓度 + 蜡烛火苗晃动 + 玻璃反射亮度
//   - 高频 → 雨滴水平漂移 + 街灯 bokeh 闪烁
//   - 每条雨痕长度 = 对应频谱 bin 的强度（签名式映射）
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

        // ── Palette (Fog City Nocturne, 冷底 + 克制暖点)
        //    基底 oklch(0.15 0.015 250) 附近
        let nightDeep     = Color(red: 10/255,  green: 12/255,  blue: 20/255)
        let nightMid      = Color(red: 18/255,  green: 22/255,  blue: 34/255)
        let fogTint       = Color(red: 44/255,  green: 54/255,  blue: 76/255)
        let wallDark      = Color(red: 24/255,  green: 22/255,  blue: 26/255)
        let wallMid       = Color(red: 46/255,  green: 40/255,  blue: 42/255)
        let wallSeam      = Color(red: 14/255,  green: 12/255,  blue: 14/255)
        let mullion       = Color(red: 32/255,  green: 26/255,  blue: 22/255)
        let mullionHL     = Color(red: 78/255,  green: 62/255,  blue: 42/255)
        let glassCold     = Color(red: 36/255,  green: 48/255,  blue: 72/255)
        let glassCoolHL   = Color(red: 180/255, green: 196/255, blue: 220/255)
        let warmLamp      = Color(red: 232/255, green: 178/255, blue: 108/255)
        let coolLamp      = Color(red: 142/255, green: 172/255, blue: 202/255)
        let dimLamp       = Color(red: 156/255, green: 156/255, blue: 162/255)
        let candleFlame   = Color(red: 250/255, green: 200/255, blue: 122/255)
        let moonBeam      = Color(red: 196/255, green: 210/255, blue: 228/255)
        let streetAmber   = Color(red: 246/255, green: 158/255, blue: 82/255)

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

        // ── 背景：冷夜渐变（不是纯黑，避免"AI slop dark-mode"）
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: nightDeep, location: 0),
                            .init(color: nightMid,  location: 0.5),
                            .init(color: wallDark,  location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                     ))

        // ── 大图：潮湿深巷石墙（抽象纹理，不用砖块模板）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawWetAlleyWall(
                    ctx: ctx, rect: CGRect(origin: .zero, size: size),
                    wallDark: wallDark, wallMid: wallMid, wallSeam: wallSeam,
                    t: t
                )

                // 远处楼宇若隐（更低对比，藏在雾里）
                var cityPath = Path()
                let skyline: CGFloat = h * 0.62
                cityPath.move(to: CGPoint(x: 0, y: skyline))
                var cursor: CGFloat = 0
                var step = 0
                while cursor < w {
                    let bw = CGFloat(42 + Int(sin(Double(cursor) * 0.015 + Double(step)) * 16 + 20))
                    let bh = CGFloat(26 + Int(cos(Double(cursor) * 0.022) * 18 + 22))
                    cityPath.addLine(to: CGPoint(x: cursor, y: skyline - bh))
                    cityPath.addLine(to: CGPoint(x: cursor + bw, y: skyline - bh))
                    cursor += bw
                    step += 1
                }
                cityPath.addLine(to: CGPoint(x: w, y: skyline))
                cityPath.closeSubpath()
                ctx.fill(cityPath, with: .color(nightDeep.opacity(0.75)))

                // 远楼零星窗灯（极稀疏）
                for i in 0..<14 {
                    let s = Double(i) * 7.13
                    let lx = CGFloat(s.truncatingRemainder(dividingBy: 1.0)) * w
                    let ly = h * 0.54 + CGFloat((cos(s * 1.3) * 0.5 + 0.5)) * h * 0.06
                    let lr: CGFloat = 0.9
                    ctx.fill(Path(ellipseIn: CGRect(x: lx, y: ly, width: lr * 2, height: lr * 2)),
                             with: .color(warmLamp.opacity(0.45)))
                }

                // 雾气 band —— 水平主雾腰带 + 两层叠加
                for band in 0..<2 {
                    let bandY = h * (band == 0 ? 0.48 : 0.66)
                    let bandH = h * 0.20
                    let fogAlpha = (band == 0 ? 0.35 : 0.22) + Double(midCG) * 0.25
                    ctx.fill(Path(CGRect(x: 0, y: bandY, width: w, height: bandH)),
                             with: .linearGradient(
                                Gradient(colors: [
                                    fogTint.opacity(0),
                                    fogTint.opacity(fogAlpha),
                                    fogTint.opacity(0)
                                ]),
                                startPoint: CGPoint(x: 0, y: bandY),
                                endPoint: CGPoint(x: 0, y: bandY + bandH)
                             ))
                }
            }
        }

        // ── 街灯 bokeh（大图才出现，雾中化开）
        if sceneAlpha > 0.01 {
            let lamps: [(x: CGFloat, y: CGFloat, r: CGFloat, color: Color, alpha: Double)] = [
                (w * 0.82, h * 0.38, 68, streetAmber, 0.38),   // 右上远街灯
                (w * 0.14, h * 0.72, 78, streetAmber, 0.30),   // 左下近街灯
                (w * 0.58, h * 0.50, 48, warmLamp,   0.28)     // 中间一盏（更远）
            ]
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                for lamp in lamps {
                    let breathe = 1.0 + Double(bassCG) * 0.12
                    let r = lamp.r * CGFloat(breathe)
                    let rect = CGRect(x: lamp.x - r, y: lamp.y - r,
                                        width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .radialGradient(
                                Gradient(stops: [
                                    .init(color: lamp.color.opacity(lamp.alpha),       location: 0),
                                    .init(color: lamp.color.opacity(lamp.alpha * 0.4), location: 0.45),
                                    .init(color: lamp.color.opacity(0),                location: 1)
                                ]),
                                center: CGPoint(x: lamp.x, y: lamp.y),
                                startRadius: 0, endRadius: r
                             ))
                    // 中心小亮点
                    let coreR: CGFloat = 2.5
                    ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - coreR, y: lamp.y - coreR,
                                                      width: coreR * 2, height: coreR * 2)),
                             with: .color(lamp.color.opacity(0.95)))
                }
            }
        }

        // ── 窗户几何（非对称三窗）
        struct WindowFrame {
            let rect: CGRect
            let lampColor: Color
            let clipMask: CGRect?  // 右侧半窗用的"墙切"裁切矩形（nil = 完整）
            let isMain: Bool
        }
        var windows: [WindowFrame] = []

        // 主窗：小图居中大特写，大图偏左下
        let mainSmall = CGRect(x: w * 0.18, y: h * 0.16,
                                width: w * 0.64, height: h * 0.68)
        let mainBig   = CGRect(x: w * 0.18, y: h * 0.42,
                                width: w * 0.40, height: h * 0.42)
        let mainRect = CGRect(
            x: mainSmall.minX + (mainBig.minX - mainSmall.minX) * e,
            y: mainSmall.minY + (mainBig.minY - mainSmall.minY) * e,
            width: mainSmall.width + (mainBig.width - mainSmall.width) * e,
            height: mainSmall.height + (mainBig.height - mainSmall.height) * e
        )
        windows.append(WindowFrame(rect: mainRect, lampColor: warmLamp,
                                    clipMask: nil, isMain: true))

        // 左上小远窗（大图）—— 更冷光，更小
        if sceneAlpha > 0.01 {
            let farSmall = CGRect(x: w * 0.08, y: h * 0.18,
                                    width: w * 0.20, height: h * 0.22)
            windows.append(WindowFrame(rect: farSmall, lampColor: coolLamp,
                                        clipMask: nil, isMain: false))

            // 右侧被墙切半的窗 —— 只露左半扇（clipMask 模拟墙缘）
            let splitFull = CGRect(x: w * 0.72, y: h * 0.30,
                                     width: w * 0.34, height: h * 0.46)
            let splitMask = CGRect(x: w * 0.72, y: h * 0.30,
                                     width: w * 0.16, height: h * 0.46)
            windows.append(WindowFrame(rect: splitFull, lampColor: dimLamp,
                                        clipMask: splitMask, isMain: false))
        }

        // ── 绘制所有窗
        for (idx, win) in windows.enumerated() {
            let alpha: Double = idx == 0 ? 1.0 : sceneAlpha
            context.drawLayer { ctx in
                ctx.opacity = alpha
                if let clip = win.clipMask {
                    ctx.clip(to: Path(clip))
                }
                drawWindow(
                    ctx: ctx, frame: win.rect, lampColor: win.lampColor,
                    mullion: mullion, mullionHL: mullionHL,
                    glassCold: glassCold, glassCoolHL: glassCoolHL,
                    warmLamp: warmLamp, candleFlame: candleFlame,
                    bassCG: bassCG, midCG: midCG, trebleCG: trebleCG,
                    t: t, isMain: win.isMain,
                    spectrumData: spectrumData,
                    sceneAlpha: sceneAlpha
                )
            }
        }

        // ── 主窗下方窗台 + 蜡烛
        let sillH: CGFloat = 8 + 4 * (1 - e)
        let sillRect = CGRect(x: mainRect.minX - 6, y: mainRect.maxY,
                               width: mainRect.width + 12, height: sillH)
        context.fill(Path(sillRect),
                     with: .linearGradient(
                        Gradient(colors: [mullionHL, mullion]),
                        startPoint: CGPoint(x: 0, y: sillRect.minY),
                        endPoint: CGPoint(x: 0, y: sillRect.maxY)
                     ))
        var sillSh = Path()
        sillSh.move(to: CGPoint(x: sillRect.minX + 2, y: sillRect.maxY + 1.5))
        sillSh.addLine(to: CGPoint(x: sillRect.maxX - 2, y: sillRect.maxY + 1.5))
        context.stroke(sillSh, with: .color(Color.black.opacity(0.55)), lineWidth: 0.8)

        // 蜡烛
        let candleX = mainRect.minX + mainRect.width * 0.16
        let candleBaseY = sillRect.minY
        let candleH: CGFloat = 14 + 6 * (1 - e)
        let candleW: CGFloat = 5
        let candleRect = CGRect(x: candleX - candleW / 2, y: candleBaseY - candleH,
                                 width: candleW, height: candleH)
        context.fill(Path(candleRect),
                     with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 226/255, green: 214/255, blue: 192/255),
                            Color(red: 172/255, green: 152/255, blue: 120/255)
                        ]),
                        startPoint: CGPoint(x: candleRect.minX, y: candleRect.minY),
                        endPoint: CGPoint(x: candleRect.maxX, y: candleRect.maxY)
                     ))

        // 火焰
        let flameJitter = CGFloat(sin(Double(t) * 6)) * (0.5 + midCG * 2.8)
        let flameH: CGFloat = 9 + midCG * 7
        let flameW: CGFloat = 4 + midCG * 1.6
        let flameCX = candleX + flameJitter
        let flameCY = candleRect.minY - flameH / 2
        var flame = Path()
        flame.move(to: CGPoint(x: flameCX, y: flameCY - flameH / 2))
        flame.addQuadCurve(to: CGPoint(x: flameCX, y: flameCY + flameH / 2),
                            control: CGPoint(x: flameCX + flameW, y: flameCY))
        flame.addQuadCurve(to: CGPoint(x: flameCX, y: flameCY - flameH / 2),
                            control: CGPoint(x: flameCX - flameW, y: flameCY))
        context.fill(flame,
                     with: .radialGradient(
                        Gradient(colors: [
                            candleFlame,
                            warmLamp.opacity(0.55),
                            Color.clear
                        ]),
                        center: CGPoint(x: flameCX, y: flameCY + flameH / 4),
                        startRadius: 0, endRadius: flameH
                     ))
        // 火焰光晕
        let glowR: CGFloat = 22 + midCG * 16
        context.fill(Path(ellipseIn: CGRect(x: flameCX - glowR, y: flameCY - glowR,
                                             width: glowR * 2, height: glowR * 2)),
                     with: .radialGradient(
                        Gradient(colors: [
                            warmLamp.opacity(0.38),
                            warmLamp.opacity(0)
                        ]),
                        center: CGPoint(x: flameCX, y: flameCY),
                        startRadius: 0, endRadius: glowR
                     ))

        // ── 蜡烛火焰在主窗玻璃里的"倒影"（关键细节——玻璃内侧反射）
        // 反射位置：火焰对称投在窗玻璃下部，颜色更淡，水平抖动稍滞后。
        let reflY = mainRect.maxY - mainRect.height * 0.22
        let reflX = candleX + flameJitter * 0.7  // 稍迟的晃动
        let reflAlpha = 0.32 + Double(midCG) * 0.22
        let reflW: CGFloat = flameW * 0.9
        let reflH: CGFloat = flameH * 0.8
        var reflection = Path()
        reflection.move(to: CGPoint(x: reflX, y: reflY - reflH / 2))
        reflection.addQuadCurve(to: CGPoint(x: reflX, y: reflY + reflH / 2),
                                 control: CGPoint(x: reflX + reflW, y: reflY))
        reflection.addQuadCurve(to: CGPoint(x: reflX, y: reflY - reflH / 2),
                                 control: CGPoint(x: reflX - reflW, y: reflY))
        context.fill(reflection,
                     with: .radialGradient(
                        Gradient(colors: [
                            candleFlame.opacity(reflAlpha),
                            warmLamp.opacity(reflAlpha * 0.35),
                            Color.clear
                        ]),
                        center: CGPoint(x: reflX, y: reflY),
                        startRadius: 0, endRadius: reflH
                     ))
        // 玻璃反射的一条竖向 streak（拉伸感——符合光学）
        var reflStreak = Path()
        reflStreak.move(to: CGPoint(x: reflX, y: reflY - reflH * 1.4))
        reflStreak.addLine(to: CGPoint(x: reflX, y: reflY + reflH * 0.8))
        context.stroke(reflStreak,
                        with: .color(candleFlame.opacity(reflAlpha * 0.4)),
                        lineWidth: 0.8)

        // ── 左上斜冷光束（月光/街灯切入室内，主光方向）
        // 贯穿左上外 → 右下，覆盖整个画面，但强度随 bass 微调
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

    // MARK: - Wet alley wall (抽象湿墙，不是砖块模板)

    private func drawWetAlleyWall(ctx: GraphicsContext, rect: CGRect,
                                    wallDark: Color, wallMid: Color, wallSeam: Color,
                                    t: Float) {
        // 底色：整个画面的中下部铺一层偏暖灰的墙面感（被雾盖了一层）
        let wallRect = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.08,
                               width: rect.width, height: rect.height * 0.92)
        ctx.fill(Path(wallRect),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: wallMid.opacity(0.48), location: 0),
                        .init(color: wallDark.opacity(0.80), location: 0.6),
                        .init(color: wallDark,                location: 1)
                    ]),
                    startPoint: CGPoint(x: 0, y: wallRect.minY),
                    endPoint: CGPoint(x: 0, y: wallRect.maxY)
                 ))

        // 不规则"石缝"水平短线（伪随机 seed，营造斑驳）
        let seamCount = 16
        for i in 0..<seamCount {
            let s = Double(i) * 17.31
            let y = wallRect.minY + CGFloat(s.truncatingRemainder(dividingBy: 1.0)) * wallRect.height
            let x0 = CGFloat((s * 1.7).truncatingRemainder(dividingBy: 1.0)) * rect.width
            let len = CGFloat(20 + Int((s * 2.3).truncatingRemainder(dividingBy: 1.0) * 60))
            var line = Path()
            line.move(to: CGPoint(x: x0, y: y))
            line.addLine(to: CGPoint(x: x0 + len, y: y + CGFloat(sin(s * 1.1) * 1.2)))
            ctx.stroke(line, with: .color(wallSeam.opacity(0.55)), lineWidth: 0.5)
        }

        // 潮湿污渍斑（椭圆 radial，更暗）
        for i in 0..<8 {
            let s = Double(i) * 23.19
            let cx = CGFloat(s.truncatingRemainder(dividingBy: 1.0)) * rect.width
            let cy = wallRect.minY + CGFloat((s * 2.7).truncatingRemainder(dividingBy: 1.0))
                     * wallRect.height
            let rw = CGFloat(40 + Int((s * 3.1).truncatingRemainder(dividingBy: 1.0) * 80))
            let rh = rw * CGFloat(0.5 + (s * 0.5).truncatingRemainder(dividingBy: 1.0))
            let stainRect = CGRect(x: cx - rw / 2, y: cy - rh / 2, width: rw, height: rh)
            ctx.fill(Path(ellipseIn: stainRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            wallSeam.opacity(0.35),
                            Color.clear
                        ]),
                        center: CGPoint(x: stainRect.midX, y: stainRect.midY),
                        startRadius: 0, endRadius: rw / 2
                     ))
        }

        // 垂直湿痕（水从墙上流下的 streak）
        let streakCount = 7
        for i in 0..<streakCount {
            let s = Double(i) * 13.7
            let x = CGFloat(s.truncatingRemainder(dividingBy: 1.0)) * rect.width
            let y0 = wallRect.minY + CGFloat((s * 1.3).truncatingRemainder(dividingBy: 1.0))
                     * wallRect.height * 0.3
            let y1 = y0 + CGFloat(60 + Int((s * 2.1).truncatingRemainder(dividingBy: 1.0) * 140))
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y0))
            streak.addLine(to: CGPoint(x: x + CGFloat(sin(s) * 2), y: y1))
            ctx.stroke(streak, with: .color(wallSeam.opacity(0.5)), lineWidth: 0.8)
        }
    }

    // MARK: - Window

    private func drawWindow(ctx: GraphicsContext, frame: CGRect, lampColor: Color,
                             mullion: Color, mullionHL: Color,
                             glassCold: Color, glassCoolHL: Color,
                             warmLamp: Color, candleFlame: Color,
                             bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat,
                             t: Float, isMain: Bool,
                             spectrumData: [Float],
                             sceneAlpha: Double) {
        // 窗框外圈 —— 主窗粗一点
        let frameInset: CGFloat = isMain ? 4 : 2.5
        let frameOuter = frame.insetBy(dx: -frameInset, dy: -frameInset)
        ctx.fill(Path(roundedRect: frameOuter, cornerRadius: 1),
                 with: .linearGradient(
                    Gradient(colors: [mullionHL, mullion]),
                    startPoint: CGPoint(x: frameOuter.minX, y: frameOuter.minY),
                    endPoint: CGPoint(x: frameOuter.maxX, y: frameOuter.maxY)
                 ))

        // 玻璃 + 室内暖光（从右上角透出，模拟室内光源在右侧）
        let lampIntensity = 0.55 + Double(bassCG) * 0.38
                             + Double(sin(Double(t) * 2.1)) * 0.04
        let interiorCenterX = frame.minX + frame.width * 0.68
        let interiorCenterY = frame.midY + frame.height * 0.05
        ctx.fill(Path(frame),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: lampColor.opacity(lampIntensity),        location: 0),
                        .init(color: lampColor.opacity(lampIntensity * 0.42), location: 0.5),
                        .init(color: glassCold.opacity(0.88),                  location: 1)
                    ]),
                    center: CGPoint(x: interiorCenterX, y: interiorCenterY),
                    startRadius: 0, endRadius: max(frame.width, frame.height) * 0.85
                 ))

        // 玻璃斜冷反光（sheen，从左上）
        var sheen = Path()
        sheen.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * 0.22))
        sheen.addLine(to: CGPoint(x: frame.minX + frame.width * 0.38, y: frame.minY))
        sheen.addLine(to: CGPoint(x: frame.minX + frame.width * 0.55, y: frame.minY))
        sheen.addLine(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * 0.52))
        sheen.closeSubpath()
        ctx.fill(sheen, with: .color(glassCoolHL.opacity(0.08)))

        // 室内剪影（仅主窗）
        if isMain {
            drawInterior(ctx: ctx, frame: frame, bassCG: bassCG, warmLamp: warmLamp)
        }

        // 窗格 mullion（2 竖 × 2 横，取代原来均匀 3 横）
        let mW: CGFloat = isMain ? 2.0 : 1.4
        // 一竖中线
        let mxC = frame.minX + frame.width * 0.48
        ctx.fill(Path(CGRect(x: mxC - mW / 2, y: frame.minY,
                              width: mW, height: frame.height)),
                 with: .color(mullion))
        // 两横（黄金比）
        for r in 0..<2 {
            let my = frame.minY + frame.height * (r == 0 ? 0.38 : 0.72)
            ctx.fill(Path(CGRect(x: frame.minX, y: my - mW / 2,
                                  width: frame.width, height: mW)),
                     with: .color(mullion))
        }

        // 雨水 —— bezier + head drop + 部分静止
        drawRainOnGlass(
            ctx: ctx, frame: frame,
            spectrumData: spectrumData,
            bassCG: bassCG, midCG: midCG, trebleCG: trebleCG,
            t: t, isMain: isMain,
            glassCoolHL: glassCoolHL
        )

        // 窗框内缘暗阴影
        ctx.stroke(Path(frame), with: .color(Color.black.opacity(0.58)),
                   lineWidth: 1.0)
    }

    // MARK: - Interior (简短但有暖意)

    private func drawInterior(ctx: GraphicsContext, frame: CGRect,
                                bassCG: CGFloat, warmLamp: Color) {
        // 椅子剪影 + 台灯，右下 2/5 区域
        // 椅背（圆角矩形暗面，带一丝暖色透光 —— 不是纯黑）
        let chairBackRect = CGRect(x: frame.minX + frame.width * 0.56,
                                     y: frame.minY + frame.height * 0.42,
                                     width: frame.width * 0.18,
                                     height: frame.height * 0.40)
        ctx.fill(Path(roundedRect: chairBackRect, cornerRadius: 3),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color.black.opacity(0.65),
                        warmLamp.opacity(0.12)
                    ]),
                    startPoint: CGPoint(x: chairBackRect.minX, y: chairBackRect.minY),
                    endPoint: CGPoint(x: chairBackRect.maxX, y: chairBackRect.maxY)
                 ))
        // 椅子靠垫（小椭圆）
        let cushionRect = CGRect(x: chairBackRect.minX + 2,
                                   y: chairBackRect.minY + chairBackRect.height * 0.12,
                                   width: chairBackRect.width - 4,
                                   height: chairBackRect.height * 0.36)
        ctx.fill(Path(roundedRect: cushionRect, cornerRadius: 4),
                 with: .color(Color.black.opacity(0.5)))

        // 台灯：杆 + 锥形灯罩 + 灯泡 + 光晕
        let lampX = frame.minX + frame.width * 0.82
        let lampBaseY = frame.minY + frame.height * 0.78
        // 杆
        var pole = Path()
        pole.move(to: CGPoint(x: lampX, y: lampBaseY))
        pole.addLine(to: CGPoint(x: lampX, y: lampBaseY - frame.height * 0.34))
        ctx.stroke(pole, with: .color(Color.black.opacity(0.72)), lineWidth: 1.4)
        // 灯罩
        let shadeW: CGFloat = frame.width * 0.13
        let shadeH: CGFloat = frame.height * 0.11
        var shade = Path()
        shade.move(to: CGPoint(x: lampX - shadeW / 2,
                                y: lampBaseY - frame.height * 0.34))
        shade.addLine(to: CGPoint(x: lampX + shadeW / 2,
                                   y: lampBaseY - frame.height * 0.34))
        shade.addLine(to: CGPoint(x: lampX + shadeW * 0.30,
                                   y: lampBaseY - frame.height * 0.34 - shadeH))
        shade.addLine(to: CGPoint(x: lampX - shadeW * 0.30,
                                   y: lampBaseY - frame.height * 0.34 - shadeH))
        shade.closeSubpath()
        ctx.fill(shade, with: .color(Color.black.opacity(0.68)))
        // 灯泡暖光
        let bulbR: CGFloat = 3.5
        let bulbY = lampBaseY - frame.height * 0.31
        ctx.fill(Path(ellipseIn: CGRect(x: lampX - bulbR, y: bulbY - bulbR,
                                         width: bulbR * 2, height: bulbR * 2)),
                 with: .color(warmLamp.opacity(0.92)))
        // 台灯暖光扩散（室内散射）
        let hotR: CGFloat = 22 + bassCG * 10
        ctx.fill(Path(ellipseIn: CGRect(x: lampX - hotR, y: bulbY - hotR,
                                          width: hotR * 2, height: hotR * 2)),
                 with: .radialGradient(
                    Gradient(colors: [
                        warmLamp.opacity(0.32),
                        Color.clear
                    ]),
                    center: CGPoint(x: lampX, y: bulbY),
                    startRadius: 0, endRadius: hotR
                 ))
    }

    // MARK: - Rain on glass (bezier + head drop + partial dwell)

    private func drawRainOnGlass(ctx: GraphicsContext, frame: CGRect,
                                   spectrumData: [Float],
                                   bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat,
                                   t: Float, isMain: Bool,
                                   glassCoolHL: Color) {
        let rainCount = isMain ? min(28, spectrumData.count) : 10
        let idle = idleBlend(spectrumData)

        for i in 0..<rainCount {
            let s = Double(i) * 9.71 + (isMain ? 0 : 37.2)

            // 横向稳定位置（带极微漂移）
            let xRand = s.truncatingRemainder(dividingBy: 1.0)
            let x = frame.minX + (CGFloat(xRand) * 0.90 + 0.05) * frame.width

            // bin 强度 → 长度签名
            let binIdx = Int(Double(i) * Double(spectrumData.count) / Double(rainCount))
                .clamped(to: 0...(spectrumData.count - 1))
            let bin = spectrumData[binIdx]
            let magnitude = CGFloat(bin) * (1 - CGFloat(idle))
                           + 0.08 * CGFloat(idle)

            // 三状态：~20% 静止水珠；~55% 慢速下滑；~25% 快速下滑
            let behaviorSeed = (s * 3.17).truncatingRemainder(dividingBy: 1.0)
            let isDwell = behaviorSeed < 0.20
            let isFast = behaviorSeed > 0.75

            let maxLen = frame.height * (isMain ? 0.42 : 0.28)
            let streakLen = isDwell
                ? 3 + magnitude * maxLen * 0.15  // 静止水珠基本没 trail
                : 6 + magnitude * maxLen

            // 下落速度（静止的几乎不动，慢 0.10，快 2.0）
            let fallSpeed: Double
            if isDwell { fallSpeed = 0.04 + Double(bassCG) * 0.10 }
            else if isFast { fallSpeed = 0.55 + Double(bassCG) * 2.5 }
            else { fallSpeed = 0.18 + Double(bassCG) * 1.2 }

            let yCycle = (Double(t) * fallSpeed + s * 3.3).truncatingRemainder(dividingBy: 1.0)
            let y0 = frame.minY + CGFloat(yCycle) * frame.height

            // 横向漂移（treble —— 风）
            let drift = CGFloat(sin(Double(t) * 1.3 + s)) * trebleCG * (isFast ? 8 : 4)

            // bezier 曲线：head drop 在 y0；trail 向上弯一点（不是直线）
            let headX = x + drift
            let headY = y0
            let midY = y0 - streakLen * 0.5
            let midX = x + drift + (isFast ? CGFloat(sin(s * 2.1)) * 2 : CGFloat(sin(s * 2.1)))
            let tailX = x + drift * 0.4 + CGFloat(sin(s * 0.7)) * 1.5
            let tailY = y0 - streakLen

            // Trail —— 从 tail 到 head 渐粗
            if streakLen > 4 {
                var trail = Path()
                trail.move(to: CGPoint(x: tailX, y: tailY))
                trail.addQuadCurve(to: CGPoint(x: headX, y: headY),
                                    control: CGPoint(x: midX, y: midY))
                let trailAlpha = 0.20 + Double(magnitude) * 0.45
                let trailWidth: CGFloat = isFast ? 0.9 : (isMain ? 0.8 : 0.55)
                ctx.stroke(trail,
                           with: .color(glassCoolHL.opacity(trailAlpha
                                                              * (isMain ? 0.85 : 0.55))),
                           lineWidth: trailWidth)
            }

            // Head drop —— 明显的小水珠（亮点 + 微反光）
            let headR: CGFloat = isDwell ? 1.6 : (isFast ? 1.3 : 1.5)
            let headRect = CGRect(x: headX - headR, y: headY - headR,
                                    width: headR * 2, height: headR * 2)
            ctx.fill(Path(ellipseIn: headRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            glassCoolHL.opacity(0.95),
                            glassCoolHL.opacity(0.0)
                        ]),
                        center: CGPoint(x: headX - headR * 0.3, y: headY - headR * 0.3),
                        startRadius: 0, endRadius: headR * 1.6
                     ))

            // 静止水珠：画一个更小的静态 cluster（2-3 个小珠），主窗才加
            if isDwell && isMain && magnitude > 0.05 {
                for k in 1...2 {
                    let kx = headX + CGFloat(k) * 2.5
                    let ky = headY + CGFloat(sin(s + Double(k))) * 1.5
                    let kr: CGFloat = 0.8
                    ctx.fill(Path(ellipseIn: CGRect(x: kx - kr, y: ky - kr,
                                                      width: kr * 2, height: kr * 2)),
                             with: .color(glassCoolHL.opacity(0.55)))
                }
            }

            // 底沿积水（水珠到达 0.94 以上 —— 主窗才有，细节）
            if yCycle > 0.93 && isMain && !isDwell {
                let puddleR: CGFloat = 2.8
                ctx.fill(Path(ellipseIn: CGRect(x: headX - puddleR,
                                                  y: y0 + streakLen * 0.3,
                                                  width: puddleR * 2, height: puddleR * 1.2)),
                         with: .color(glassCoolHL.opacity(0.75)))
            }
        }
    }

    private func idleBlend(_ spectrumData: [Float]) -> Float {
        let maxValue = spectrumData.max() ?? 0
        return max(Float(0), 1 - maxValue * 4)
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

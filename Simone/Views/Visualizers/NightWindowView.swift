import SwiftUI

// Favorites visualizer — Night Window (v3, lone-lamp-in-city).
//
// 小图 (expansion=0): 单扇窗大特写，玻璃占画面 60%，雨滴凝结/下滑，烛焰映在玻璃里。
// 大图 (expansion=1): 茫茫城市夜景，一座座高楼密密的窗格全是灭的，只有我们这一扇主窗亮着暖光。
//                     远层天际线剪影 + 左右近层楼群，每栋楼密集熄灭窗格阵列。
//                     极少数（~2%）窗里透着极暗冷反光或遥远邻居的暖光，强化"我们是唯一完全醒着的人"。
//
// Impeccable 原则落实：
//   - 物件感：窗玻璃是一件真的物件；楼是有体积的，上下渐变、层次错落
//   - 侧光：左上冷月光束 + 室内右上暖灯 = 双向侧光
//   - 动而非跳：雨滴 bezier + head drop + 部分静止
//   - 60-30-10：60% 楼群死灰 / 30% 冷雾+夜空 / 10% 主窗唯一暖点
//   - 非对称：楼高参差、错前错后、窗格行列数每栋不同，绝不网格 UI 感
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
        let cityFar       = Color(red: 18/255,  green: 22/255,  blue: 32/255)   // 远楼剪影 oklch(~0.12 0.012 250)
        let cityNear      = Color(red: 30/255,  green: 36/255,  blue: 48/255)   // 近楼体 oklch(~0.17 0.015 252)
        let windowDead    = Color(red: 24/255,  green: 28/255,  blue: 38/255)   // 死窗（比楼体略冷略亮）
        let windowFaintC  = Color(red: 58/255,  green: 72/255,  blue: 92/255)   // 极少数冷玻璃反光
        let windowFaintW  = Color(red: 78/255,  green: 60/255,  blue: 38/255)   // 极少数遥远邻居暖窗
        let mullion       = Color(red: 32/255,  green: 26/255,  blue: 22/255)
        let mullionHL     = Color(red: 78/255,  green: 62/255,  blue: 42/255)
        let glassCold     = Color(red: 36/255,  green: 48/255,  blue: 72/255)
        let glassCoolHL   = Color(red: 180/255, green: 196/255, blue: 220/255)
        let warmLamp      = Color(red: 232/255, green: 178/255, blue: 108/255)
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
                            .init(color: cityFar,   location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                     ))

        // ── 大图：城市夜景楼群 —— 一座座高楼全是灭灯的窗户
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawCitySkyline(
                    ctx: ctx, w: w, h: h,
                    cityFar: cityFar, cityNear: cityNear,
                    windowDead: windowDead,
                    windowFaintC: windowFaintC,
                    windowFaintW: windowFaintW
                )

                // 楼群 flicker 窗 —— 偶发蓝白光（电视/屏幕光），随 treble 触发
                drawCityFlickers(ctx: ctx, w: w, h: h,
                                   glassCoolHL: glassCoolHL,
                                   t: t, trebleCG: trebleCG, midCG: midCG)

                // 雾气 band —— 浓度跟 mid 明显变化
                for band in 0..<2 {
                    let bandY = h * (band == 0 ? 0.38 : 0.60)
                    let bandH = h * 0.22
                    let fogAlpha = (band == 0 ? 0.26 : 0.18) + Double(midCG) * 0.38
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

                // 全画面远处雨丝 —— 随 bass 加速、treble 加密
                drawFarRain(ctx: ctx, w: w, h: h,
                              glassCoolHL: glassCoolHL,
                              t: t, bassCG: bassCG, trebleCG: trebleCG)
            }
        }

        // ── 街灯 bokeh（大图才出现，穿过楼缝透出来的远处街灯）
        if sceneAlpha > 0.01 {
            let lamps: [(x: CGFloat, y: CGFloat, r: CGFloat, color: Color, alpha: Double)] = [
                (w * 0.88, h * 0.42, 62, streetAmber, 0.32),   // 右侧楼缝间远街灯
                (w * 0.06, h * 0.76, 68, streetAmber, 0.26)    // 左侧底部近街灯
            ]
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                for (lampIdx, lamp) in lamps.enumerated() {
                    // 呼吸 + treble 微闪（每盏相位不同）
                    let breathe = 1.0 + Double(bassCG) * 0.22
                                   + sin(Double(t) * 3.2 + Double(lampIdx) * 1.9)
                                     * Double(trebleCG) * 0.18
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

        // 主窗：小图居中大特写，大图收缩成楼群里一扇能一眼认出来的亮窗
        //       (drawWindow 内按尺寸分级渲染——小了走 pixel 分支，只剩暖光+辉光+十字 mullion)
        let mainSmall = CGRect(x: w * 0.18, y: h * 0.16,
                                width: w * 0.64, height: h * 0.68)
        let mainBigW: CGFloat = max(44, w * 0.12)
        let mainBigH: CGFloat = max(54, h * 0.068)
        let mainBig   = CGRect(x: w * 0.695, y: h * 0.50,
                                width: mainBigW, height: mainBigH)
        let mainRect = CGRect(
            x: mainSmall.minX + (mainBig.minX - mainSmall.minX) * e,
            y: mainSmall.minY + (mainBig.minY - mainSmall.minY) * e,
            width: mainSmall.width + (mainBig.width - mainSmall.width) * e,
            height: mainSmall.height + (mainBig.height - mainSmall.height) * e
        )
        windows.append(WindowFrame(rect: mainRect, lampColor: warmLamp,
                                    clipMask: nil, isMain: true))
        // 大图下没有其他亮窗——"孤独一扇"是整个构图的核心叙事

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

    // MARK: - City skyline (楼群剪影 + 密集熄灯窗格)

    private func drawCitySkyline(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                                   cityFar: Color, cityNear: Color,
                                   windowDead: Color, windowFaintC: Color,
                                   windowFaintW: Color) {
        // ── 远层天际线：剪影式多栋楼，横穿整幅画面
        //    楼高参差、楼宽不齐；窗格尺度最小；基线在 h*0.48
        let farBaseY = h * 0.48
        var cursor: CGFloat = -6
        var step = 0
        while cursor < w {
            let s = Double(step)
            let bw = CGFloat(30 + Int((sin(s * 1.71 + Double(cursor) * 0.019) * 0.5 + 0.5) * 44))
            let bh = CGFloat(44 + Int((cos(s * 2.33 + Double(cursor) * 0.027) * 0.5 + 0.5) * 74))
            let rect = CGRect(x: cursor, y: farBaseY - bh, width: bw, height: bh)
            ctx.fill(Path(rect), with: .color(cityFar.opacity(0.90)))
            drawWindowGrid(ctx: ctx, building: rect,
                           cellW: 7, cellH: 9, wFrac: 0.54, hFrac: 0.58,
                           dead: windowDead, faintC: windowFaintC, faintW: windowFaintW,
                           seedBase: s * 11.3,
                           deadOpacity: 0.80, faintOpacity: 0.40)
            cursor += bw + CGFloat(1 + (step % 3))
            step += 1
        }

        // ── 左侧近层：单栋楼撑到画面左边缘
        let leftRect = CGRect(x: -3, y: h * 0.26,
                               width: w * 0.16 + 3, height: h - h * 0.26)
        ctx.fill(Path(leftRect),
                 with: .linearGradient(
                    Gradient(colors: [cityNear, cityFar]),
                    startPoint: CGPoint(x: 0, y: leftRect.minY),
                    endPoint: CGPoint(x: 0, y: leftRect.maxY)
                 ))
        drawWindowGrid(ctx: ctx, building: leftRect,
                       cellW: 10, cellH: 13, wFrac: 0.56, hFrac: 0.60,
                       dead: windowDead, faintC: windowFaintC, faintW: windowFaintW,
                       seedBase: 91.7,
                       deadOpacity: 0.78, faintOpacity: 0.50)

        // ── 右侧近层：3 栋楼参差，顶端高度各异
        let rightTops: [CGFloat] = [h * 0.22, h * 0.32, h * 0.18]
        let rightWidths: [CGFloat] = [w * 0.14, w * 0.12, w * 0.20]
        var rc: CGFloat = w * 0.60
        for (idx, bw) in rightWidths.enumerated() {
            if rc >= w + 3 { break }
            let topY = rightTops[idx % rightTops.count]
            let actualW = min(bw, w + 4 - rc)
            let r = CGRect(x: rc, y: topY, width: actualW, height: h - topY)
            ctx.fill(Path(r),
                     with: .linearGradient(
                        Gradient(colors: [cityNear, cityFar]),
                        startPoint: CGPoint(x: 0, y: r.minY),
                        endPoint: CGPoint(x: 0, y: r.maxY)
                     ))
            // 每栋楼窗格参数略不同，避免网格 UI 感
            let cellW: CGFloat = idx == 0 ? 10 : (idx == 1 ? 12 : 9)
            let cellH: CGFloat = idx == 0 ? 13 : (idx == 1 ? 15 : 12)
            drawWindowGrid(ctx: ctx, building: r,
                           cellW: cellW, cellH: cellH, wFrac: 0.56, hFrac: 0.60,
                           dead: windowDead, faintC: windowFaintC, faintW: windowFaintW,
                           seedBase: 50.3 + Double(idx) * 29.7,
                           deadOpacity: 0.78, faintOpacity: 0.50)
            rc += actualW + CGFloat(2 + idx)
        }
    }

    // 楼立面的窗格阵列 —— 绝大多数死灰，极少数极暗冷/暖
    private func drawWindowGrid(ctx: GraphicsContext, building: CGRect,
                                  cellW: CGFloat, cellH: CGFloat,
                                  wFrac: CGFloat, hFrac: CGFloat,
                                  dead: Color, faintC: Color, faintW: Color,
                                  seedBase: Double,
                                  deadOpacity: Double, faintOpacity: Double) {
        // 窗格从楼顶往下 6pt 处起，避免压楼顶
        let topPad: CGFloat = 6
        let bottomPad: CGFloat = 4
        let usableH = building.height - topPad - bottomPad
        guard building.width > cellW * 2, usableH > cellH * 2 else { return }

        let cols = max(2, Int(building.width / cellW))
        let rows = max(3, Int(usableH / cellH))
        let cw = building.width / CGFloat(cols)
        let ch = usableH / CGFloat(rows)
        for ci in 0..<cols {
            for ri in 0..<rows {
                let wx = building.minX + CGFloat(ci) * cw + cw * (1 - wFrac) * 0.5
                let wy = building.minY + topPad + CGFloat(ri) * ch
                        + ch * (1 - hFrac) * 0.5
                let ww = cw * wFrac
                let wh = ch * hFrac

                let seed = (Double(ci) * 7.31 + Double(ri) * 13.113 + seedBase)
                    .truncatingRemainder(dividingBy: 1.0)
                let cellRect = CGRect(x: wx, y: wy, width: ww, height: wh)
                if seed > 0.996 {         // ~0.4% 极远邻居暖窗（打破 Matrix 齐整感）
                    ctx.fill(Path(cellRect),
                             with: .color(faintW.opacity(faintOpacity * 0.85)))
                } else if seed > 0.982 {  // ~1.4% 冷玻璃反光
                    ctx.fill(Path(cellRect),
                             with: .color(faintC.opacity(faintOpacity)))
                } else {                   // 98%+ 死灰窗
                    ctx.fill(Path(cellRect),
                             with: .color(dead.opacity(deadOpacity)))
                }
            }
        }
    }

    // MARK: - City flickers (TV/screen light in distant windows)

    private func drawCityFlickers(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                                   glassCoolHL: Color,
                                   t: Float, trebleCG: CGFloat, midCG: CGFloat) {
        // 16 hand-placed flicker positions across skyline; each with own period/phase
        // 主窗在 (x≈0.765·w, y≈0.545·h) — 避开
        let spots: [(nx: CGFloat, ny: CGFloat, period: Float, phase: Float)] = [
            (0.08, 0.58, 3.7, 0.1),  (0.14, 0.62, 5.2, 0.4),
            (0.19, 0.55, 2.9, 0.7),  (0.23, 0.66, 4.3, 0.2),
            (0.32, 0.48, 6.1, 0.55), (0.38, 0.52, 3.3, 0.85),
            (0.44, 0.57, 4.8, 0.15), (0.51, 0.50, 2.4, 0.95),
            (0.57, 0.60, 5.6, 0.35), (0.62, 0.53, 3.9, 0.05),
            (0.68, 0.61, 4.5, 0.75), (0.72, 0.49, 2.7, 0.25),
            (0.83, 0.64, 5.0, 0.45), (0.88, 0.56, 3.5, 0.9),
            (0.92, 0.60, 4.1, 0.3),  (0.96, 0.52, 6.3, 0.65)
        ]
        let threshold = 0.015 + Double(trebleCG) * 0.06 + Double(midCG) * 0.02

        for spot in spots {
            let phaseVal = (t / spot.period + spot.phase)
                .truncatingRemainder(dividingBy: 1.0)
            let normalized = phaseVal < 0 ? phaseVal + 1 : phaseVal
            if Double(normalized) < threshold {
                let x = spot.nx * w
                let y = spot.ny * h
                let sw: CGFloat = 2.2
                let sh: CGFloat = 2.8
                let rect = CGRect(x: x - sw/2, y: y - sh/2, width: sw, height: sh)
                // 外层散光
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                         with: .color(glassCoolHL.opacity(0.22)))
                // 核心亮点
                ctx.fill(Path(rect),
                         with: .color(glassCoolHL.opacity(0.68)))
            }
        }
    }

    // MARK: - Far rain (full-canvas sparse rain threads)

    private func drawFarRain(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                              glassCoolHL: Color,
                              t: Float, bassCG: CGFloat, trebleCG: CGFloat) {
        // 稀疏远景雨丝，打满画面；密度跟 treble,速度跟 bass
        let count = 18 + Int(trebleCG * 30)
        let fallSpeed: Float = 0.55 + Float(bassCG) * 1.8
        let baseY = t * fallSpeed
        let angle: CGFloat = 0.18  // 轻微斜向

        for i in 0..<count {
            let s = Float(i) * 0.7131
            let colFrac = (s * 1.618).truncatingRemainder(dividingBy: 1.0)
            let x = CGFloat(colFrac) * w
            let yFrac = (baseY + s * 2.37).truncatingRemainder(dividingBy: 1.6)
            let yNorm = yFrac < 0 ? yFrac + 1.6 : yFrac
            // yNorm 0..1.6 → y 覆盖画面并允许上方/下方溢出
            let y = CGFloat(yNorm - 0.3) * h

            let streakLen: CGFloat = 7 + CGFloat(i % 3) * 2
            let alpha = 0.16 + Double(trebleCG) * 0.10

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - angle * streakLen, y: y + streakLen))
            ctx.stroke(path,
                       with: .color(glassCoolHL.opacity(alpha)),
                       lineWidth: 0.5)
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
        // ── 远景小窗分支：楼群里的一扇亮窗
        //    不画窗框/室内/雨水/反射——那些细节在近景大特写时走完整分支
        //    这里只负责：外圈暖辉光（随 bass 显著呼吸）+ 暖矩形 + mini mullion
        //    阈值 100pt 覆盖从 pixel 到"一眼能看出是窗户"的远景尺寸
        if frame.width < 100 {
            // 外圈辉光 —— 半径+亮度随 bass 大幅呼吸，让"活人"在楼海里一眼能看出
            let breathe = 1.0 + Double(bassCG) * 0.55
                           + sin(Double(t) * 1.8) * 0.08
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

            // 窗格本体：内层暖光随 mid 微闪（用 radial 从偏右上开始，模拟室内光源）
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

            // 内部 mini mullion（一竖一横十字）—— 线宽随 frame size 缩放
            let mW: CGFloat = max(0.6, frame.width * 0.018)
            let mxC = frame.minX + frame.width * 0.5
            ctx.fill(Path(CGRect(x: mxC - mW / 2, y: frame.minY,
                                  width: mW, height: frame.height)),
                     with: .color(Color.black.opacity(0.50)))
            let myC = frame.minY + frame.height * 0.5
            ctx.fill(Path(CGRect(x: frame.minX, y: myC - mW / 2,
                                  width: frame.width, height: mW)),
                     with: .color(Color.black.opacity(0.50)))

            // 窗框外缘暗线（让它嵌在楼面里）—— 线宽随 size 缩放
            let strokeW: CGFloat = max(0.7, frame.width * 0.022)
            ctx.stroke(Path(frame), with: .color(Color.black.opacity(0.75)),
                       lineWidth: strokeW)
            return
        }

        // 窗框外圈 —— 主窗粗一点
        let frameInset: CGFloat = isMain ? 4 : 2.5
        let frameOuter = frame.insetBy(dx: -frameInset, dy: -frameInset)
        ctx.fill(Path(roundedRect: frameOuter, cornerRadius: 1),
                 with: .linearGradient(
                    Gradient(colors: [mullionHL, mullion]),
                    startPoint: CGPoint(x: frameOuter.minX, y: frameOuter.minY),
                    endPoint: CGPoint(x: frameOuter.maxX, y: frameOuter.maxY)
                 ))

        // 玻璃 + 室内暖光 —— 随 bass 明显呼吸（范围加大到几乎覆盖整扇窗亮度）
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

        // 窗格 mullion —— 简化：仅 1 竖 1 横（十字型）
        let mW: CGFloat = isMain ? 1.8 : 1.2
        let mxC = frame.minX + frame.width * 0.50
        ctx.fill(Path(CGRect(x: mxC - mW / 2, y: frame.minY,
                              width: mW, height: frame.height)),
                 with: .color(mullion))
        let myC = frame.minY + frame.height * 0.55
        ctx.fill(Path(CGRect(x: frame.minX, y: myC - mW / 2,
                              width: frame.width, height: mW)),
                 with: .color(mullion))

        // 雨水打在玻璃上
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

    // MARK: - Rain on glass (bezier + head drop)

    private func drawRainOnGlass(ctx: GraphicsContext, frame: CGRect,
                                   spectrumData: [Float],
                                   bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat,
                                   t: Float, isMain: Bool,
                                   glassCoolHL: Color) {
        // 雨水数量：静默 base + treble 激活——音乐高频高时雨变密
        let baseRain = isMain ? 10 : 6
        let trebleBoost = Int(trebleCG * 18)
        let rainCount = min(spectrumData.count, baseRain + trebleBoost)
        let idle = idleBlend(spectrumData)

        for i in 0..<rainCount {
            let s = Double(i) * 9.71 + (isMain ? 0 : 37.2)

            let xRand = s.truncatingRemainder(dividingBy: 1.0)
            let x = frame.minX + (CGFloat(xRand) * 0.90 + 0.05) * frame.width

            let binIdx = Int(Double(i) * Double(spectrumData.count) / Double(max(rainCount, 1)))
                .clamped(to: 0...(spectrumData.count - 1))
            let bin = spectrumData[binIdx]
            let magnitude = CGFloat(bin) * (1 - CGFloat(idle))
                           + 0.08 * CGFloat(idle)

            let maxLen = frame.height * (isMain ? 0.40 : 0.26)
            let streakLen = 8 + magnitude * maxLen * 1.2

            // 下落速度 —— 主要驱动：bass 明显放大（×2.5）
            let fallSpeed = 0.30 + Double(bassCG) * 2.5 + Double(magnitude) * 0.4

            let yCycle = (Double(t) * fallSpeed + s * 3.3).truncatingRemainder(dividingBy: 1.0)
            let y0 = frame.minY + CGFloat(yCycle) * frame.height

            // 横向漂移 —— treble 风压，幅度放大
            let drift = CGFloat(sin(Double(t) * 1.6 + s)) * trebleCG * 12

            let headX = x + drift
            let headY = y0
            let midY = y0 - streakLen * 0.5
            let midX = x + drift + CGFloat(sin(s * 2.1)) * 1.6
            let tailX = x + drift * 0.4 + CGFloat(sin(s * 0.7)) * 1.5
            let tailY = y0 - streakLen

            // Trail bezier
            var trail = Path()
            trail.move(to: CGPoint(x: tailX, y: tailY))
            trail.addQuadCurve(to: CGPoint(x: headX, y: headY),
                                control: CGPoint(x: midX, y: midY))
            let trailAlpha = 0.24 + Double(magnitude) * 0.50
            ctx.stroke(trail,
                       with: .color(glassCoolHL.opacity(trailAlpha
                                                          * (isMain ? 0.88 : 0.55))),
                       lineWidth: isMain ? 0.85 : 0.55)

            // Head drop
            let headR: CGFloat = 1.4 + magnitude * 1.0
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

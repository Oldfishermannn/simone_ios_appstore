import SwiftUI

// Favorites visualizer — Curator's Drawer (v2, bolder).
//
// 小图 (expansion=0): 抽屉居中特写，一件铜怀表作为"hero"物件斜放，
//                     侧光打在金属上高光强烈。
// 大图 (expansion=1): 镜头拉远，抽屉置于桃木桌面，2x2 不对称格局显现，
//                     怀表在右下焦点格，其它三格分别：古钥匙 / 缎带信 / 干玫瑰。
//                     左上角一道斜光束带灰尘从窗户射下。
//
// 和 v1 的差别：
//   - 不再是 4x3 平铺，而是 2x2 不对称 + hero 焦点，构图更大胆
//   - 引入体积光（斜光束 parallelogram）和显著投影
//   - 物件本身重新设计（怀表/钥匙/信/玫瑰），更有叙事感
//   - 抽屉呼吸幅度翻倍，侧壁暗阴影营造深度
//
// Spectrum mapping:
//  - 低频 → 抽屉前后呼吸 + 光束强度
//  - 中频 → 怀表指针微颤 + 灯光呼吸
//  - 高频 → 光束内灰尘粒子
struct DrawerView: View {
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

        // Palette — Fog City Nocturne 冷底 + 暖铜/烛光
        let bg         = Color(red: 14/255,  green: 13/255,  blue: 16/255)
        let deskTone   = Color(red: 58/255,  green: 40/255,  blue: 26/255)
        let deskShadow = Color(red: 28/255,  green: 18/255,  blue: 10/255)
        let oakLit     = Color(red: 148/255, green: 106/255, blue: 62/255)
        let oak        = Color(red: 86/255,  green: 58/255,  blue: 32/255)
        let oakDark    = Color(red: 34/255,  green: 22/255,  blue: 12/255)
        let velvet     = Color(red: 30/255,  green: 24/255,  blue: 34/255)
        let velvetDeep = Color(red: 14/255,  green: 10/255,  blue: 18/255)
        let brass      = Color(red: 208/255, green: 172/255, blue: 96/255)
        let brassDark  = Color(red: 108/255, green: 78/255,  blue: 38/255)
        let lightWarm  = Color(red: 238/255, green: 198/255, blue: 128/255)

        // Audio buckets
        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.18 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.10 * idleBlend)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ── 背景 / 桌面渐显
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))

        if sceneAlpha > 0.01 {
            // 桌面大面深桃木 + 顶侧光
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: deskTone.opacity(0.90),  location: 0),
                                .init(color: deskTone.opacity(0.55),  location: 0.55),
                                .init(color: deskShadow,              location: 1)
                            ]),
                            startPoint: CGPoint(x: w * 0.10, y: h * 0.05),
                            endPoint: CGPoint(x: w * 0.95, y: h * 1.00)
                         ))
                // 木纹横线
                for i in 0..<10 {
                    let gy = h * (0.10 + CGFloat(i) * 0.09)
                    var grain = Path()
                    grain.move(to: CGPoint(x: 0, y: gy))
                    let amp: CGFloat = 2.5 + CGFloat(i).truncatingRemainder(dividingBy: 3) * 0.5
                    for px in stride(from: CGFloat(0), through: w, by: 6) {
                        let wobble = sin(Double(px) * 0.018 + Double(i) * 1.3) * Double(amp)
                        grain.addLine(to: CGPoint(x: px, y: gy + CGFloat(wobble)))
                    }
                    let alpha = 0.09 + Double(i).truncatingRemainder(dividingBy: 2) * 0.03
                    ctx.stroke(grain, with: .color(oakDark.opacity(alpha)), lineWidth: 0.6)
                }
            }
        }

        // ── 抽屉几何 —— 呼吸更夸张（低频）
        let breathe = CGFloat(sin(Double(t) * 0.85)) * 1.1 + bassCG * 4.5

        // 小图：抽屉铺满（0.86w × 0.60h），focus-only 视野
        // 大图：抽屉后退到画面中下（0.66w × 0.46h），留桌面 context
        let drawerW = (0.86 + (0.66 - 0.86) * e) * w
        let drawerH = (0.60 + (0.46 - 0.60) * e) * h
        let drawerCX = w * (0.50 + (0.52 - 0.50) * e)
        let drawerCY = (0.52 + (0.60 - 0.52) * e) * h
        let drawerRect = CGRect(
            x: drawerCX - drawerW / 2,
            y: drawerCY - drawerH / 2 + breathe,
            width: drawerW, height: drawerH
        )

        // ── 抽屉地面长投影（侧光来自左上，向右下）
        let shadowW = drawerRect.width * 1.25
        let shadowH: CGFloat = 42 + (18 * e)
        let shadowRect = CGRect(
            x: drawerRect.minX - 10,
            y: drawerRect.maxY - 4,
            width: shadowW, height: shadowH
        )
        context.fill(Path(shadowRect),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color.black.opacity(0.72), location: 0),
                            .init(color: Color.black.opacity(0.30), location: 0.5),
                            .init(color: Color.black.opacity(0),    location: 1)
                        ]),
                        center: CGPoint(x: shadowRect.midX + 32, y: shadowRect.minY + 10),
                        startRadius: 0, endRadius: shadowRect.width * 0.58
                     ))

        // ── 抽屉木体（立体感 —— 左上高光 + 右下暗面）
        let frontLipH: CGFloat = h * 0.05
        context.fill(Path(roundedRect: drawerRect, cornerRadius: 5),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: oakLit,              location: 0),
                            .init(color: oak,                 location: 0.48),
                            .init(color: oakDark,             location: 1)
                        ]),
                        startPoint: CGPoint(x: drawerRect.minX, y: drawerRect.minY),
                        endPoint: CGPoint(x: drawerRect.maxX, y: drawerRect.maxY)
                     ))
        // 顶面 rim 高光（左上侧光）
        var topHL = Path()
        topHL.move(to: CGPoint(x: drawerRect.minX + 5, y: drawerRect.minY + 1.3))
        topHL.addLine(to: CGPoint(x: drawerRect.maxX - 5, y: drawerRect.minY + 1.3))
        context.stroke(topHL, with: .color(oakLit.opacity(0.75)), lineWidth: 0.8)
        // 左侧竖直高光
        var leftHL = Path()
        leftHL.move(to: CGPoint(x: drawerRect.minX + 1.0, y: drawerRect.minY + 4))
        leftHL.addLine(to: CGPoint(x: drawerRect.minX + 1.0, y: drawerRect.maxY - 4))
        context.stroke(leftHL, with: .color(oakLit.opacity(0.35)), lineWidth: 0.6)
        // 右侧竖直暗影
        var rightSh = Path()
        rightSh.move(to: CGPoint(x: drawerRect.maxX - 1.0, y: drawerRect.minY + 4))
        rightSh.addLine(to: CGPoint(x: drawerRect.maxX - 1.0, y: drawerRect.maxY - 4))
        context.stroke(rightSh, with: .color(Color.black.opacity(0.55)), lineWidth: 0.7)

        // 前 lip
        let frontLipRect = CGRect(x: drawerRect.minX, y: drawerRect.maxY - frontLipH,
                                   width: drawerRect.width, height: frontLipH)
        context.fill(Path(frontLipRect),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: oak,     location: 0),
                            .init(color: oakDark, location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: frontLipRect.minY),
                        endPoint: CGPoint(x: 0, y: frontLipRect.maxY)
                     ))
        var lipHL = Path()
        lipHL.move(to: CGPoint(x: frontLipRect.minX + 4, y: frontLipRect.minY + 0.5))
        lipHL.addLine(to: CGPoint(x: frontLipRect.maxX - 4, y: frontLipRect.minY + 0.5))
        context.stroke(lipHL, with: .color(oakLit.opacity(0.45)), lineWidth: 0.5)

        // ── 抽屉内腔（velvet 深井）—— 四壁暗阴影营造深度
        let interiorInset: CGFloat = 8
        let interiorRect = CGRect(
            x: drawerRect.minX + interiorInset,
            y: drawerRect.minY + interiorInset,
            width: drawerRect.width - interiorInset * 2,
            height: drawerRect.height - frontLipH - interiorInset
        )
        // 底色 velvet
        context.fill(Path(roundedRect: interiorRect, cornerRadius: 2),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: velvetDeep, location: 0),
                            .init(color: velvet,     location: 0.48),
                            .init(color: velvetDeep, location: 1)
                        ]),
                        startPoint: CGPoint(x: interiorRect.minX, y: interiorRect.minY),
                        endPoint: CGPoint(x: interiorRect.maxX, y: interiorRect.maxY)
                     ))
        // 上沿 / 左沿 深阴影（凹陷感）
        var topWell = Path()
        topWell.move(to: CGPoint(x: interiorRect.minX, y: interiorRect.minY))
        topWell.addLine(to: CGPoint(x: interiorRect.maxX, y: interiorRect.minY))
        context.stroke(topWell, with: .color(Color.black.opacity(0.85)), lineWidth: 2.0)
        var leftWell = Path()
        leftWell.move(to: CGPoint(x: interiorRect.minX, y: interiorRect.minY + 1))
        leftWell.addLine(to: CGPoint(x: interiorRect.minX, y: interiorRect.maxY - 1))
        context.stroke(leftWell, with: .color(Color.black.opacity(0.6)), lineWidth: 1.2)

        // ── 2x2 不对称格位 —— 焦点在右下
        // 横分割：55% / 45% ；竖分割：45% / 55%（不对称）
        let colSplit: CGFloat = 0.52
        let rowSplit: CGFloat = 0.46
        let colW0 = interiorRect.width * colSplit
        let colW1 = interiorRect.width * (1 - colSplit)
        let rowH0 = interiorRect.height * rowSplit
        let rowH1 = interiorRect.height * (1 - rowSplit)

        // 格线（大图淡入）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                var divV = Path()
                let divX = interiorRect.minX + colW0
                divV.move(to: CGPoint(x: divX, y: interiorRect.minY + 4))
                divV.addLine(to: CGPoint(x: divX, y: interiorRect.maxY - 4))
                ctx.stroke(divV, with: .color(Color.black.opacity(0.7)), lineWidth: 1.0)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: divX + 0.8, y: interiorRect.minY + 4))
                    p.addLine(to: CGPoint(x: divX + 0.8, y: interiorRect.maxY - 4))
                }, with: .color(oakLit.opacity(0.18)), lineWidth: 0.5)

                var divH = Path()
                let divY = interiorRect.minY + rowH0
                divH.move(to: CGPoint(x: interiorRect.minX + 4, y: divY))
                divH.addLine(to: CGPoint(x: interiorRect.maxX - 4, y: divY))
                ctx.stroke(divH, with: .color(Color.black.opacity(0.7)), lineWidth: 1.0)

                // 非焦点三格：左上=古钥匙，右上=缎带信，左下=压花玫瑰
                // 左上
                let cell00 = CGRect(x: interiorRect.minX, y: interiorRect.minY,
                                     width: colW0, height: rowH0)
                drawAntiqueKey(ctx: ctx, in: cell00, brass: brass, brassDark: brassDark,
                               t: t, jitter: midCG * 0.5)
                // 右上
                let cell10 = CGRect(x: interiorRect.minX + colW0, y: interiorRect.minY,
                                     width: colW1, height: rowH0)
                drawRibbonLetter(ctx: ctx, in: cell10, t: t, jitter: midCG * 0.4)
                // 左下
                let cell01 = CGRect(x: interiorRect.minX, y: interiorRect.minY + rowH0,
                                     width: colW0, height: rowH1)
                drawPressedRose(ctx: ctx, in: cell01, t: t, jitter: midCG * 0.4)
            }
        }

        // ── 焦点 hero：铜怀表（永远全强度）
        //   小图：占据整个 interior，居中
        //   大图：移到右下格中心
        let heroCellSmall = interiorRect
        let heroCellBig   = CGRect(x: interiorRect.minX + colW0,
                                    y: interiorRect.minY + rowH0,
                                    width: colW1, height: rowH1)
        let heroCX = heroCellSmall.midX + (heroCellBig.midX - heroCellSmall.midX) * e
        let heroCY = heroCellSmall.midY + (heroCellBig.midY - heroCellSmall.midY) * e
        let heroW  = heroCellSmall.width + (heroCellBig.width - heroCellSmall.width) * e
        let heroH  = heroCellSmall.height + (heroCellBig.height - heroCellSmall.height) * e
        let heroBounds = CGRect(x: heroCX - heroW / 2, y: heroCY - heroH / 2,
                                 width: heroW, height: heroH)
        drawPocketWatch(ctx: context, in: heroBounds, brass: brass, brassDark: brassDark,
                         t: t, midJitter: midCG, bassPulse: bassCG)

        // ── 铜把手（前 lip 上居中）— 更厚更有分量
        let pullW = drawerRect.width * 0.24
        let pullH: CGFloat = 10
        let pullCX = drawerRect.midX
        let pullCY = frontLipRect.midY - 0.5
        let pullRect = CGRect(x: pullCX - pullW / 2, y: pullCY - pullH / 2,
                              width: pullW, height: pullH)
        context.fill(Path(roundedRect: pullRect, cornerRadius: pullH * 0.5),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: lightWarm.opacity(0.9), location: 0),
                            .init(color: brass,                  location: 0.4),
                            .init(color: brassDark,              location: 1)
                        ]),
                        startPoint: CGPoint(x: pullCX, y: pullRect.minY),
                        endPoint: CGPoint(x: pullCX, y: pullRect.maxY)
                     ))
        var pullHL = Path()
        pullHL.addArc(center: CGPoint(x: pullCX, y: pullRect.midY - 1.5),
                      radius: pullW * 0.42,
                      startAngle: .radians(.pi * 1.08),
                      endAngle: .radians(.pi * 1.92),
                      clockwise: false)
        context.stroke(pullHL, with: .color(Color.white.opacity(0.45)), lineWidth: 0.8)
        // 把手下投影
        var pullShadow = Path()
        pullShadow.move(to: CGPoint(x: pullRect.minX + 2, y: pullRect.maxY + 1.4))
        pullShadow.addLine(to: CGPoint(x: pullRect.maxX - 2, y: pullRect.maxY + 1.4))
        context.stroke(pullShadow, with: .color(Color.black.opacity(0.6)), lineWidth: 0.7)

        // ── 戏剧斜光束（贯穿左上→右下，体积感）
        // 任何模式都可见，强度随 bass。
        let beamIntensity = 0.18 + Double(bassCG) * 0.45 + sceneAlpha * 0.15
        if beamIntensity > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = min(0.9, beamIntensity)
                // parallelogram 从左上外飞入，穿过 drawer
                var beam = Path()
                let bx0: CGFloat = -w * 0.15
                let by0: CGFloat = -h * 0.05
                let beamW: CGFloat = w * 0.28
                beam.move(to: CGPoint(x: bx0, y: by0))
                beam.addLine(to: CGPoint(x: bx0 + beamW, y: by0))
                beam.addLine(to: CGPoint(x: bx0 + beamW + w * 1.2, y: by0 + h * 1.25))
                beam.addLine(to: CGPoint(x: bx0 + w * 1.2, y: by0 + h * 1.25))
                beam.closeSubpath()
                ctx.fill(beam,
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: lightWarm.opacity(0.28), location: 0),
                                .init(color: lightWarm.opacity(0.12), location: 0.45),
                                .init(color: lightWarm.opacity(0),    location: 1)
                            ]),
                            startPoint: CGPoint(x: bx0, y: by0),
                            endPoint: CGPoint(x: bx0 + beamW + w * 1.2,
                                              y: by0 + h * 1.25)
                         ))
            }
        }

        // ── 光束内灰尘（高频）
        if treble > 0.05 {
            let dustCount = min(Int(treble * 90), 32)
            for i in 0..<dustCount {
                let s = Double(i) * 13.7
                // 沿着光束方向（左上→右下对角线）分布
                let along = (sin(Double(t) * 0.18 + s) * 0.5 + 0.5)
                let across = (cos(Double(t) * 0.24 + s * 1.4) * 0.5 + 0.5)
                // along: 0..1 沿对角线位置；across: 距对角线宽度
                let diagX = CGFloat(along) * (w * 1.1) - w * 0.05
                let diagY = CGFloat(along) * (h * 1.1) - h * 0.05
                // 横向抖动（垂直光束方向）
                let offN = (CGFloat(across) - 0.5) * w * 0.18
                let x = diagX + offN
                let y = diagY - offN
                let alpha = 0.25 + Double(treble) * 0.55
                let dotR: CGFloat = 0.7 + CGFloat(treble) * 1.2
                let dr = CGRect(x: x, y: y, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: dr),
                             with: .color(lightWarm.opacity(alpha * 0.6)))
            }
        }
    }

    // MARK: - Hero: Pocket Watch
    //
    // 铜怀表：圆表壳 + 表冠 + 短链 + 指针（时/分）。侧光强高光。
    private func drawPocketWatch(ctx: GraphicsContext, in bounds: CGRect,
                                  brass: Color, brassDark: Color,
                                  t: Float, midJitter: CGFloat, bassPulse: CGFloat) {
        let cx = bounds.midX
        let cy = bounds.midY
        let r  = min(bounds.width, bounds.height) * 0.32

        // 表壳投影（右下偏移）
        let shadowOffset: CGFloat = r * 0.18
        let shadow = CGRect(x: cx - r + shadowOffset * 0.6, y: cy - r + shadowOffset,
                             width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: shadow),
                 with: .radialGradient(
                    Gradient(colors: [
                        Color.black.opacity(0.55), Color.black.opacity(0)
                    ]),
                    center: CGPoint(x: shadow.midX, y: shadow.midY),
                    startRadius: 0, endRadius: r * 1.1
                 ))

        // 表冠（顶部小头）
        let crownW = r * 0.22
        let crownH = r * 0.20
        let crownRect = CGRect(x: cx - crownW / 2, y: cy - r - crownH * 0.7,
                                width: crownW, height: crownH)
        ctx.fill(Path(roundedRect: crownRect, cornerRadius: 2),
                 with: .linearGradient(
                    Gradient(colors: [brass, brassDark]),
                    startPoint: CGPoint(x: crownRect.minX, y: crownRect.minY),
                    endPoint: CGPoint(x: crownRect.maxX, y: crownRect.maxY)
                 ))
        // 表冠齿纹（三道）
        for i in 0..<3 {
            let gx = crownRect.minX + 2 + CGFloat(i) * (crownW - 4) / 2
            var g = Path()
            g.move(to: CGPoint(x: gx, y: crownRect.minY + 2))
            g.addLine(to: CGPoint(x: gx, y: crownRect.maxY - 2))
            ctx.stroke(g, with: .color(Color.black.opacity(0.45)), lineWidth: 0.5)
        }

        // 短链（表冠接一个小环 + 几节链）
        let linkCY = crownRect.minY - 2
        let ring = CGRect(x: cx - 3, y: linkCY - 6, width: 6, height: 6)
        ctx.stroke(Path(ellipseIn: ring), with: .color(brass), lineWidth: 1.2)
        for i in 0..<3 {
            let chainCY = linkCY - 10 - CGFloat(i) * 5
            let chainX = cx + CGFloat(i - 1) * 1.2
            let link = CGRect(x: chainX - 2.2, y: chainCY - 2.5, width: 4.4, height: 5)
            ctx.stroke(Path(ellipseIn: link),
                       with: .color(brass.opacity(0.9 - Double(i) * 0.15)),
                       lineWidth: 0.9)
        }

        // 表壳外圈（侧光径向渐变）
        let caseRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: caseRect),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color.white.opacity(0.85), location: 0),
                        .init(color: brass,                     location: 0.35),
                        .init(color: brassDark,                 location: 1)
                    ]),
                    center: CGPoint(x: cx - r * 0.35, y: cy - r * 0.35),
                    startRadius: 0, endRadius: r * 1.3
                 ))
        // 外圈 rim
        ctx.stroke(Path(ellipseIn: caseRect),
                   with: .color(brassDark.opacity(0.8)), lineWidth: 1.0)
        // 内圈（表盘边界）
        let innerR = r * 0.82
        let dialRect = CGRect(x: cx - innerR, y: cy - innerR,
                               width: innerR * 2, height: innerR * 2)
        // 表盘（米白）
        let dialCream = Color(red: 232/255, green: 216/255, blue: 188/255)
        ctx.fill(Path(ellipseIn: dialRect),
                 with: .radialGradient(
                    Gradient(colors: [dialCream, dialCream.opacity(0.75)]),
                    center: CGPoint(x: cx - innerR * 0.2, y: cy - innerR * 0.3),
                    startRadius: 0, endRadius: innerR * 1.1
                 ))
        ctx.stroke(Path(ellipseIn: dialRect),
                   with: .color(brassDark.opacity(0.55)), lineWidth: 0.6)

        // 时刻（12 个点）
        for i in 0..<12 {
            let a = -.pi / 2 + CGFloat(i) * .pi / 6
            let rx = cx + cos(a) * innerR * 0.85
            let ry = cy + sin(a) * innerR * 0.85
            let isMain = i % 3 == 0
            let dotR: CGFloat = isMain ? 1.5 : 0.9
            let dot = CGRect(x: rx - dotR, y: ry - dotR, width: dotR * 2, height: dotR * 2)
            ctx.fill(Path(ellipseIn: dot),
                     with: .color(Color(red: 60/255, green: 42/255, blue: 22/255)
                                   .opacity(isMain ? 0.95 : 0.7)))
        }

        // 指针 —— 随时间+中频微颤
        let jitter = Double(midJitter) * 0.15
        let hourAngle: Double = Double(t) * 0.018 + jitter // 慢
        let minuteAngle: Double = Double(t) * 0.22 + jitter * 2 // 快
        drawHand(ctx: ctx, cx: cx, cy: cy, angle: hourAngle,
                 length: innerR * 0.48, width: 2.0,
                 color: Color(red: 40/255, green: 28/255, blue: 16/255))
        drawHand(ctx: ctx, cx: cx, cy: cy, angle: minuteAngle,
                 length: innerR * 0.70, width: 1.4,
                 color: Color(red: 40/255, green: 28/255, blue: 16/255))
        // 中心轴
        let pivotR: CGFloat = 2.2 + bassPulse * 1.2
        ctx.fill(Path(ellipseIn: CGRect(x: cx - pivotR, y: cy - pivotR,
                                         width: pivotR * 2, height: pivotR * 2)),
                 with: .color(brass))
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - pivotR, y: cy - pivotR,
                                           width: pivotR * 2, height: pivotR * 2)),
                   with: .color(brassDark), lineWidth: 0.4)

        // 镜面高光弧
        var glassHL = Path()
        glassHL.addArc(center: CGPoint(x: cx - innerR * 0.18, y: cy - innerR * 0.18),
                        radius: innerR * 0.55,
                        startAngle: .radians(.pi * 1.12),
                        endAngle: .radians(.pi * 1.45),
                        clockwise: false)
        ctx.stroke(glassHL, with: .color(Color.white.opacity(0.55)), lineWidth: 1.2)
    }

    private func drawHand(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                           angle: Double, length: CGFloat, width: CGFloat, color: Color) {
        let endX = cx + CGFloat(cos(angle - .pi / 2)) * length
        let endY = cy + CGFloat(sin(angle - .pi / 2)) * length
        var hand = Path()
        hand.move(to: CGPoint(x: cx, y: cy))
        hand.addLine(to: CGPoint(x: endX, y: endY))
        ctx.stroke(hand, with: .color(color), lineWidth: width)
    }

    // MARK: - Secondary mementos (only visible at big pose)

    // 古钥匙 — bow (圆头) + shaft + teeth (齿)
    private func drawAntiqueKey(ctx: GraphicsContext, in cell: CGRect,
                                 brass: Color, brassDark: Color,
                                 t: Float, jitter: CGFloat) {
        let cx = cell.midX + CGFloat(sin(Double(t) * 1.3)) * jitter * 0.8
        let cy = cell.midY + CGFloat(sin(Double(t) * 1.7)) * jitter * 0.5
        let scale = min(cell.width, cell.height) * 0.42

        // 倾斜 -30°
        let rot = -CGFloat.pi / 6
        let cosR = cos(rot), sinR = sin(rot)

        func transform(_ p: CGPoint) -> CGPoint {
            let dx = p.x - cx, dy = p.y - cy
            return CGPoint(x: cx + dx * cosR - dy * sinR,
                           y: cy + dx * sinR + dy * cosR)
        }

        // bow (ornate 三叶）
        let bowR = scale * 0.34
        let bowCenter = transform(CGPoint(x: cx - scale * 0.55, y: cy))
        let bowRect = CGRect(x: bowCenter.x - bowR, y: bowCenter.y - bowR,
                              width: bowR * 2, height: bowR * 2)
        // 投影
        let bowShadow = CGRect(x: bowRect.minX + 2, y: bowRect.minY + 3,
                                width: bowRect.width, height: bowRect.height)
        ctx.fill(Path(ellipseIn: bowShadow),
                 with: .color(Color.black.opacity(0.4)))
        // bow 本体
        ctx.fill(Path(ellipseIn: bowRect),
                 with: .radialGradient(
                    Gradient(colors: [brass, brassDark]),
                    center: CGPoint(x: bowRect.midX - bowR * 0.3, y: bowRect.midY - bowR * 0.3),
                    startRadius: 0, endRadius: bowR * 1.3
                 ))
        // bow 内孔
        let holeR = bowR * 0.42
        ctx.fill(Path(ellipseIn: CGRect(x: bowCenter.x - holeR, y: bowCenter.y - holeR,
                                          width: holeR * 2, height: holeR * 2)),
                 with: .color(Color.black.opacity(0.75)))

        // shaft
        let shaftLen = scale * 1.1
        let shaftH: CGFloat = 4.5
        let shaftStart = transform(CGPoint(x: cx - scale * 0.21, y: cy - shaftH / 2))
        let shaftEnd   = transform(CGPoint(x: cx + scale * 0.85, y: cy + shaftH / 2))
        // 构造旋转矩形
        var shaftPath = Path()
        let corners = [
            transform(CGPoint(x: cx - scale * 0.21, y: cy - shaftH / 2)),
            transform(CGPoint(x: cx + scale * 0.85, y: cy - shaftH / 2)),
            transform(CGPoint(x: cx + scale * 0.85, y: cy + shaftH / 2)),
            transform(CGPoint(x: cx - scale * 0.21, y: cy + shaftH / 2))
        ]
        shaftPath.move(to: corners[0])
        for p in corners.dropFirst() { shaftPath.addLine(to: p) }
        shaftPath.closeSubpath()
        ctx.fill(shaftPath,
                 with: .linearGradient(
                    Gradient(colors: [brass, brassDark]),
                    startPoint: shaftStart, endPoint: shaftEnd
                 ))

        // 齿（两块）在右端下方
        for k in 0..<2 {
            let tx = cx + scale * (0.60 + CGFloat(k) * 0.15)
            let ty = cy + shaftH / 2
            let th = scale * 0.22
            let tw: CGFloat = 5
            var toothCorners = [
                transform(CGPoint(x: tx - tw / 2, y: ty)),
                transform(CGPoint(x: tx + tw / 2, y: ty)),
                transform(CGPoint(x: tx + tw / 2, y: ty + th)),
                transform(CGPoint(x: tx - tw / 2, y: ty + th))
            ]
            var toothPath = Path()
            toothPath.move(to: toothCorners[0])
            for p in toothCorners.dropFirst() { toothPath.addLine(to: p) }
            toothPath.closeSubpath()
            ctx.fill(toothPath, with: .color(brassDark.opacity(0.95)))
            _ = toothCorners
        }

        // 高光（bow 上侧）
        var hl = Path()
        hl.addArc(center: CGPoint(x: bowCenter.x - bowR * 0.3, y: bowCenter.y - bowR * 0.3),
                   radius: bowR * 0.55,
                   startAngle: .radians(.pi * 1.15),
                   endAngle: .radians(.pi * 1.55),
                   clockwise: false)
        ctx.stroke(hl, with: .color(Color.white.opacity(0.45)), lineWidth: 0.8)
    }

    // 缎带信：米色信纸 + 红缎带 + 蝴蝶结
    private func drawRibbonLetter(ctx: GraphicsContext, in cell: CGRect,
                                   t: Float, jitter: CGFloat) {
        let cx = cell.midX + CGFloat(sin(Double(t) * 1.4)) * jitter * 0.6
        let cy = cell.midY + CGFloat(sin(Double(t) * 1.8)) * jitter * 0.4
        let w = cell.width * 0.68
        let hgt = cell.height * 0.58
        let rot: CGFloat = -0.16
        let cosR = cos(rot), sinR = sin(rot)
        func tr(_ p: CGPoint) -> CGPoint {
            let dx = p.x - cx, dy = p.y - cy
            return CGPoint(x: cx + dx * cosR - dy * sinR,
                           y: cy + dx * sinR + dy * cosR)
        }

        // 投影
        var sh = Path()
        let shc = [
            tr(CGPoint(x: cx - w / 2 + 2, y: cy - hgt / 2 + 3)),
            tr(CGPoint(x: cx + w / 2 + 2, y: cy - hgt / 2 + 3)),
            tr(CGPoint(x: cx + w / 2 + 2, y: cy + hgt / 2 + 3)),
            tr(CGPoint(x: cx - w / 2 + 2, y: cy + hgt / 2 + 3))
        ]
        sh.move(to: shc[0])
        for p in shc.dropFirst() { sh.addLine(to: p) }
        sh.closeSubpath()
        ctx.fill(sh, with: .color(Color.black.opacity(0.45)))

        // 信纸
        let paper = Color(red: 218/255, green: 198/255, blue: 168/255)
        let paperShade = Color(red: 180/255, green: 160/255, blue: 128/255)
        var p = Path()
        let c = [
            tr(CGPoint(x: cx - w / 2, y: cy - hgt / 2)),
            tr(CGPoint(x: cx + w / 2, y: cy - hgt / 2)),
            tr(CGPoint(x: cx + w / 2, y: cy + hgt / 2)),
            tr(CGPoint(x: cx - w / 2, y: cy + hgt / 2))
        ]
        p.move(to: c[0])
        for pp in c.dropFirst() { p.addLine(to: pp) }
        p.closeSubpath()
        ctx.fill(p,
                 with: .linearGradient(
                    Gradient(colors: [paper, paperShade]),
                    startPoint: c[0], endPoint: c[2]
                 ))
        ctx.stroke(p, with: .color(paperShade.opacity(0.7)), lineWidth: 0.5)

        // 信纸上的"字迹"—— 三道模糊横线
        for i in 0..<4 {
            let ly = cy - hgt / 2 + hgt * (0.22 + CGFloat(i) * 0.18)
            let ls = tr(CGPoint(x: cx - w * 0.36, y: ly))
            let le = tr(CGPoint(x: cx + w * (i == 3 ? 0.10 : 0.34), y: ly))
            var line = Path()
            line.move(to: ls)
            line.addLine(to: le)
            ctx.stroke(line, with: .color(Color(red: 0.25, green: 0.18, blue: 0.10).opacity(0.35)),
                       lineWidth: 0.5)
        }

        // 红缎带（竖 + 横十字）
        let ribbon = Color(red: 158/255, green: 48/255, blue: 52/255)
        let ribbonHL = Color(red: 208/255, green: 82/255, blue: 82/255)
        // 竖带
        let vbW = w * 0.12
        var vb = Path()
        let vbC = [
            tr(CGPoint(x: cx - vbW / 2, y: cy - hgt / 2 - 2)),
            tr(CGPoint(x: cx + vbW / 2, y: cy - hgt / 2 - 2)),
            tr(CGPoint(x: cx + vbW / 2, y: cy + hgt / 2 + 2)),
            tr(CGPoint(x: cx - vbW / 2, y: cy + hgt / 2 + 2))
        ]
        vb.move(to: vbC[0])
        for pp in vbC.dropFirst() { vb.addLine(to: pp) }
        vb.closeSubpath()
        ctx.fill(vb, with: .linearGradient(
            Gradient(colors: [ribbonHL, ribbon]),
            startPoint: vbC[0], endPoint: vbC[2]
        ))
        // 横带
        let hbH = hgt * 0.13
        var hb = Path()
        let hbC = [
            tr(CGPoint(x: cx - w / 2 - 2, y: cy - hbH / 2)),
            tr(CGPoint(x: cx + w / 2 + 2, y: cy - hbH / 2)),
            tr(CGPoint(x: cx + w / 2 + 2, y: cy + hbH / 2)),
            tr(CGPoint(x: cx - w / 2 - 2, y: cy + hbH / 2))
        ]
        hb.move(to: hbC[0])
        for pp in hbC.dropFirst() { hb.addLine(to: pp) }
        hb.closeSubpath()
        ctx.fill(hb, with: .linearGradient(
            Gradient(colors: [ribbonHL, ribbon]),
            startPoint: hbC[0], endPoint: hbC[3]
        ))
        // 蝴蝶结（中心左右两叶）
        let bowY = cy
        let bowX = cx
        let petalW: CGFloat = w * 0.16
        let petalH: CGFloat = hgt * 0.22
        for dir in [-1, 1] {
            let px = bowX + CGFloat(dir) * petalW * 0.55
            let petalRect = CGRect(x: px - petalW / 2, y: bowY - petalH / 2,
                                    width: petalW, height: petalH)
            // 不做旋转（简化），信本身已倾斜
            ctx.fill(Path(ellipseIn: petalRect),
                     with: .linearGradient(
                        Gradient(colors: [ribbonHL, ribbon]),
                        startPoint: CGPoint(x: petalRect.minX, y: petalRect.minY),
                        endPoint: CGPoint(x: petalRect.maxX, y: petalRect.maxY)
                     ))
        }
        // 结扣
        let knotR: CGFloat = 3
        ctx.fill(Path(ellipseIn: CGRect(x: bowX - knotR, y: bowY - knotR,
                                         width: knotR * 2, height: knotR * 2)),
                 with: .color(ribbon))
    }

    // 压花玫瑰：层叠花瓣深暗红
    private func drawPressedRose(ctx: GraphicsContext, in cell: CGRect,
                                  t: Float, jitter: CGFloat) {
        let cx = cell.midX + CGFloat(sin(Double(t) * 1.1)) * jitter * 0.5
        let cy = cell.midY + CGFloat(sin(Double(t) * 1.5)) * jitter * 0.5
        let r = min(cell.width, cell.height) * 0.36

        let rose = Color(red: 128/255, green: 44/255, blue: 56/255)
        let roseDeep = Color(red: 78/255, green: 22/255, blue: 32/255)
        let roseLit = Color(red: 178/255, green: 80/255, blue: 84/255)

        // 外圈 5 瓣
        for i in 0..<6 {
            let a = CGFloat(i) * .pi * 2 / 6 - .pi / 2
            let px = cx + cos(a) * r * 0.55
            let py = cy + sin(a) * r * 0.55
            let petalR = r * 0.48
            let petalRect = CGRect(x: px - petalR * 0.52, y: py - petalR * 0.48,
                                    width: petalR * 1.04, height: petalR * 0.96)
            ctx.fill(Path(ellipseIn: petalRect),
                     with: .radialGradient(
                        Gradient(colors: [rose, roseDeep]),
                        center: CGPoint(x: petalRect.midX - petalR * 0.1,
                                         y: petalRect.midY - petalR * 0.1),
                        startRadius: 0, endRadius: petalR * 0.9
                     ))
        }
        // 中圈 4 瓣
        for i in 0..<5 {
            let a = CGFloat(i) * .pi * 2 / 5 + .pi / 5
            let px = cx + cos(a) * r * 0.25
            let py = cy + sin(a) * r * 0.25
            let petalR = r * 0.32
            let petalRect = CGRect(x: px - petalR * 0.52, y: py - petalR * 0.5,
                                    width: petalR * 1.04, height: petalR * 1.0)
            ctx.fill(Path(ellipseIn: petalRect),
                     with: .color(roseLit.opacity(0.85)))
        }
        // 中心
        let centerR = r * 0.18
        ctx.fill(Path(ellipseIn: CGRect(x: cx - centerR, y: cy - centerR,
                                         width: centerR * 2, height: centerR * 2)),
                 with: .color(roseDeep))
        // 叶（右下）
        let leafCX = cx + r * 0.7
        let leafCY = cy + r * 0.55
        var leaf = Path()
        leaf.move(to: CGPoint(x: leafCX - r * 0.3, y: leafCY + r * 0.35))
        leaf.addQuadCurve(to: CGPoint(x: leafCX + r * 0.35, y: leafCY - r * 0.2),
                           control: CGPoint(x: leafCX + r * 0.15, y: leafCY + r * 0.18))
        leaf.addQuadCurve(to: CGPoint(x: leafCX - r * 0.3, y: leafCY + r * 0.35),
                           control: CGPoint(x: leafCX - r * 0.08, y: leafCY - r * 0.08))
        ctx.fill(leaf, with: .color(Color(red: 90/255, green: 96/255, blue: 62/255).opacity(0.85)))
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

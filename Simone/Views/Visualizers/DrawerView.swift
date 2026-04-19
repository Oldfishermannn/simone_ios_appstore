import SwiftUI

// Favorites visualizer — Curiosity Drawer.
//
// 小图 (expansion=0): 抽屉只露一格 — 单件 memento 居中，铜把手在下方。
// 大图 (expansion=1): 抽屉完全拉开，4×3 格 velvet-衬内陈列多件 memento，柜身顶架淡入。
//
// Object: 深棕橡木小收藏柜，铜把手，内衬暗绒布。每件 memento（硬币/贝壳/票根/
// 干花/小石头/叶子）是一份收藏。侧光从左上角桌灯来。
// Spectrum mapping:
//  - 低频 → 抽屉微微前后呼吸（0.6 ± bass × 2.5 px）
//  - 中频 → 焦点 memento 位置小颤（x/y 位移）
//  - 高频 → 灰尘粒子浮动（稀疏亮点）
struct DrawerView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0

    private static let cols = 4
    private static let rows = 3
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
        let bg         = Color(red: 16/255,  green: 14/255,  blue: 12/255)
        let cabinetBg  = Color(red: 28/255,  green: 22/255,  blue: 16/255)
        let oak        = Color(red: 72/255,  green: 52/255,  blue: 32/255)
        let oakLit     = Color(red: 134/255, green: 96/255,  blue: 58/255)
        let oakShadow  = Color(red: 38/255,  green: 26/255,  blue: 16/255)
        let velvet     = Color(red: 30/255,  green: 26/255,  blue: 32/255)
        let velvetDeep = Color(red: 14/255,  green: 12/255,  blue: 18/255)
        let brassPull  = Color(red: 194/255, green: 158/255, blue: 96/255)
        let brassDark  = Color(red: 108/255, green: 82/255,  blue: 46/255)

        // Memento palettes
        let shellPink  = Color(red: 222/255, green: 196/255, blue: 178/255)
        let coinGold   = Color(red: 188/255, green: 154/255, blue: 88/255)
        let paperTan   = Color(red: 198/255, green: 172/255, blue: 128/255)
        let driedRose  = Color(red: 148/255, green: 74/255,  blue: 78/255)
        let stoneGrey  = Color(red: 122/255, green: 112/255, blue: 104/255)
        let leafGreen  = Color(red: 112/255, green: 128/255, blue: 96/255)

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
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.18 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.10 * idleBlend)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ── 背景房间（大图淡入）──────────
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: cabinetBg.opacity(0.92), location: 0),
                                .init(color: bg, location: 0.7),
                                .init(color: bg, location: 1)
                            ]),
                            center: CGPoint(x: w * 0.12, y: h * 0.10),
                            startRadius: 0, endRadius: max(w, h) * 0.95
                         ))
            }
        }

        // ── 抽屉几何 —— 呼吸（低频） ──────────
        let breathe = CGFloat(sin(Double(t) * 0.85)) * 0.6 + bassCG * 2.5

        // 小图: drawer 占满上半视觉区（0.84w × 0.62h），居中偏上
        // 大图: drawer 略窄略矮（0.74w × 0.52h），下移让柜顶架显露
        let drawerW = (0.84 + (0.74 - 0.84) * e) * w
        let drawerH = (0.62 + (0.52 - 0.62) * e) * h
        let drawerCX = w * 0.50
        let drawerCY = (0.50 + (0.58 - 0.50) * e) * h
        let drawerRect = CGRect(
            x: drawerCX - drawerW / 2,
            y: drawerCY - drawerH / 2 + breathe,
            width: drawerW, height: drawerH
        )

        // ── 柜顶架（大图淡入，作为画面"在大柜里"的线索）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let cabinetW = drawerW * 1.12
                let cabinetX = (w - cabinetW) / 2
                let shelfY = drawerRect.minY - h * 0.11
                let shelfRect = CGRect(x: cabinetX, y: shelfY,
                                       width: cabinetW, height: h * 0.07)
                ctx.fill(Path(shelfRect),
                         with: .linearGradient(
                            Gradient(colors: [oakShadow, oak]),
                            startPoint: CGPoint(x: 0, y: shelfRect.minY),
                            endPoint: CGPoint(x: 0, y: shelfRect.maxY)
                         ))
                // 顶架下沿（阴影）
                var bottomEdge = Path()
                bottomEdge.move(to: CGPoint(x: cabinetX, y: shelfRect.maxY))
                bottomEdge.addLine(to: CGPoint(x: cabinetX + cabinetW, y: shelfRect.maxY))
                ctx.stroke(bottomEdge, with: .color(Color.black.opacity(0.6)), lineWidth: 1.2)
                // 顶架上沿高光
                var topHL = Path()
                topHL.move(to: CGPoint(x: cabinetX + 4, y: shelfRect.minY + 1))
                topHL.addLine(to: CGPoint(x: cabinetX + cabinetW - 4, y: shelfRect.minY + 1))
                ctx.stroke(topHL, with: .color(oakLit.opacity(0.45)), lineWidth: 0.6)
            }
        }

        // ── 抽屉底部投影
        let shadowRect = CGRect(x: drawerRect.minX - 8, y: drawerRect.maxY + 2,
                                 width: drawerRect.width + 16, height: 22)
        context.fill(Path(shadowRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            Color.black.opacity(0.60), Color.black.opacity(0)
                        ]),
                        center: CGPoint(x: shadowRect.midX + 14, y: shadowRect.minY + 8),
                        startRadius: 0, endRadius: shadowRect.width * 0.48
                     ))

        // ── 抽屉木体（外壳 + 前 lip）
        let frontLipH: CGFloat = h * 0.045
        // 外层木框
        context.fill(Path(roundedRect: drawerRect, cornerRadius: 4),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: oakLit.opacity(0.95), location: 0),
                            .init(color: oak, location: 0.5),
                            .init(color: oakShadow, location: 1)
                        ]),
                        startPoint: CGPoint(x: drawerRect.minX, y: drawerRect.minY),
                        endPoint: CGPoint(x: drawerRect.maxX, y: drawerRect.maxY)
                     ))

        // 木顶高光（左上侧光）
        var topWoodHL = Path()
        topWoodHL.move(to: CGPoint(x: drawerRect.minX + 4, y: drawerRect.minY + 1.2))
        topWoodHL.addLine(to: CGPoint(x: drawerRect.maxX - 4, y: drawerRect.minY + 1.2))
        context.stroke(topWoodHL, with: .color(oakLit.opacity(0.55)), lineWidth: 0.7)

        // 前 lip
        let frontLipRect = CGRect(x: drawerRect.minX, y: drawerRect.maxY - frontLipH,
                                   width: drawerRect.width, height: frontLipH)
        context.fill(Path(frontLipRect),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: oak, location: 0),
                            .init(color: oakShadow, location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: frontLipRect.minY),
                        endPoint: CGPoint(x: 0, y: frontLipRect.maxY)
                     ))
        // front-lip 上沿高光
        var lipHL = Path()
        lipHL.move(to: CGPoint(x: frontLipRect.minX + 3, y: frontLipRect.minY + 0.5))
        lipHL.addLine(to: CGPoint(x: frontLipRect.maxX - 3, y: frontLipRect.minY + 0.5))
        context.stroke(lipHL, with: .color(oakLit.opacity(0.35)), lineWidth: 0.5)

        // ── 抽屉内腔（velvet）
        let interiorInset: CGFloat = 6
        let interiorRect = CGRect(
            x: drawerRect.minX + interiorInset,
            y: drawerRect.minY + interiorInset,
            width: drawerRect.width - interiorInset * 2,
            height: drawerRect.height - frontLipH - interiorInset
        )
        context.fill(Path(roundedRect: interiorRect, cornerRadius: 2),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: velvetDeep, location: 0),
                            .init(color: velvet.opacity(0.95), location: 0.4),
                            .init(color: velvetDeep, location: 1)
                        ]),
                        startPoint: CGPoint(x: interiorRect.minX, y: interiorRect.minY),
                        endPoint: CGPoint(x: interiorRect.maxX, y: interiorRect.maxY)
                     ))
        // velvet 顶内阴影（模拟凹陷）
        var velvetRim = Path()
        velvetRim.move(to: CGPoint(x: interiorRect.minX, y: interiorRect.minY))
        velvetRim.addLine(to: CGPoint(x: interiorRect.maxX, y: interiorRect.minY))
        context.stroke(velvetRim, with: .color(Color.black.opacity(0.7)), lineWidth: 1.2)

        // ── 格位几何
        let cols = Self.cols
        let rows = Self.rows
        let focusCol = Self.focusCol
        let focusRow = Self.focusRow
        let compW = interiorRect.width / CGFloat(cols)
        let compH = interiorRect.height / CGFloat(rows)

        // 格线（大图淡入）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                for c in 1..<cols {
                    let x = interiorRect.minX + CGFloat(c) * compW
                    var v = Path()
                    v.move(to: CGPoint(x: x, y: interiorRect.minY + 3))
                    v.addLine(to: CGPoint(x: x, y: interiorRect.maxY - 3))
                    ctx.stroke(v, with: .color(Color.black.opacity(0.75)), lineWidth: 0.8)
                    var vh = Path()
                    vh.move(to: CGPoint(x: x + 0.6, y: interiorRect.minY + 3))
                    vh.addLine(to: CGPoint(x: x + 0.6, y: interiorRect.maxY - 3))
                    ctx.stroke(vh, with: .color(oakLit.opacity(0.14)), lineWidth: 0.4)
                }
                for r in 1..<rows {
                    let y = interiorRect.minY + CGFloat(r) * compH
                    var hl = Path()
                    hl.move(to: CGPoint(x: interiorRect.minX + 3, y: y))
                    hl.addLine(to: CGPoint(x: interiorRect.maxX - 3, y: y))
                    ctx.stroke(hl, with: .color(Color.black.opacity(0.75)), lineWidth: 0.8)
                }

                // 非焦点格 memento
                let mementoColors: [Color] = [
                    shellPink, coinGold, paperTan, driedRose, stoneGrey, leafGreen,
                    coinGold.opacity(0.85), shellPink.opacity(0.85),
                    driedRose.opacity(0.85), leafGreen.opacity(0.85),
                    paperTan.opacity(0.80), stoneGrey.opacity(0.80)
                ]
                var idx = 0
                for r in 0..<rows {
                    for c in 0..<cols {
                        if r == focusRow && c == focusCol { idx += 1; continue }
                        let cellCX = interiorRect.minX + (CGFloat(c) + 0.5) * compW
                        let cellCY = interiorRect.minY + (CGFloat(r) + 0.5) * compH
                        let color = mementoColors[idx % mementoColors.count]
                        let kind = (idx * 7 + r * 3 + c) % 6
                        let seed = Double(r * 11 + c * 7 + 1) * 1.4
                        drawMemento(ctx: ctx, cx: cellCX, cy: cellCY,
                                    cellW: compW, cellH: compH,
                                    color: color, kind: kind,
                                    seed: seed, t: t,
                                    jitter: midCG * 0.4, isFocus: false)
                        idx += 1
                    }
                }
            }
        }

        // ── 焦点 memento（永远完整强度）
        // 小图时：没有格线，memento 居中；大图时：memento 移回到焦点格中心
        let focusCellCXSmall = interiorRect.midX
        let focusCellCYSmall = interiorRect.midY
        let focusCellCXBig = interiorRect.minX + (CGFloat(focusCol) + 0.5) * compW
        let focusCellCYBig = interiorRect.minY + (CGFloat(focusRow) + 0.5) * compH
        let focusCX = focusCellCXSmall + (focusCellCXBig - focusCellCXSmall) * e
        let focusCY = focusCellCYSmall + (focusCellCYBig - focusCellCYSmall) * e
        // 焦点 memento 在小图用整个内腔作为"格"（决定大小），在大图收到单 cell 尺寸
        let focusCellW = interiorRect.width + (compW - interiorRect.width) * e
        let focusCellH = interiorRect.height + (compH - interiorRect.height) * e
        drawMemento(ctx: context, cx: focusCX, cy: focusCY,
                    cellW: focusCellW, cellH: focusCellH,
                    color: coinGold, kind: 0,
                    seed: 0.0, t: t,
                    jitter: midCG * 1.0, isFocus: true)

        // ── 铜把手（前 lip 上居中）
        let pullW = drawerRect.width * 0.22
        let pullH: CGFloat = 8
        let pullCX = drawerRect.midX
        let pullCY = frontLipRect.midY - 0.5
        let pullRect = CGRect(x: pullCX - pullW / 2, y: pullCY - pullH / 2,
                              width: pullW, height: pullH)
        context.fill(Path(roundedRect: pullRect, cornerRadius: pullH * 0.5),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: brassPull, location: 0),
                            .init(color: brassDark, location: 1)
                        ]),
                        startPoint: CGPoint(x: pullCX, y: pullRect.minY),
                        endPoint: CGPoint(x: pullCX, y: pullRect.maxY)
                     ))
        // 把手高光（上弧）
        var pullHL = Path()
        pullHL.addArc(center: CGPoint(x: pullCX, y: pullRect.midY - 1),
                      radius: pullW * 0.42,
                      startAngle: .radians(.pi * 1.08),
                      endAngle: .radians(.pi * 1.92),
                      clockwise: false)
        context.stroke(pullHL, with: .color(Color.white.opacity(0.32)), lineWidth: 0.7)
        // 把手侧面投影（把手下一条极细暗线）
        var pullShadow = Path()
        pullShadow.move(to: CGPoint(x: pullRect.minX + 2, y: pullRect.maxY + 1.2))
        pullShadow.addLine(to: CGPoint(x: pullRect.maxX - 2, y: pullRect.maxY + 1.2))
        context.stroke(pullShadow, with: .color(Color.black.opacity(0.55)), lineWidth: 0.6)

        // ── 灰尘粒子（高频，稀疏）
        if treble > 0.08 {
            let dustCount = min(Int(treble * 70), 20)
            for i in 0..<dustCount {
                let s = Double(i) * 11.31
                let xRand = sin(Double(t) * 0.28 + s) - floor(sin(Double(t) * 0.28 + s))
                let yRand = cos(Double(t) * 0.21 + s * 1.3) - floor(cos(Double(t) * 0.21 + s * 1.3))
                let x = interiorRect.minX + CGFloat(xRand) * interiorRect.width
                let y = interiorRect.minY + CGFloat(yRand) * interiorRect.height * 0.55
                let alpha = Double(treble) * 0.5
                let dotR: CGFloat = 0.6 + CGFloat(treble) * 0.7
                let dr = CGRect(x: x, y: y, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: dr),
                             with: .color(brassPull.opacity(alpha)))
            }
        }
    }

    // MARK: - Memento shapes

    private func drawMemento(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                              cellW: CGFloat, cellH: CGFloat,
                              color: Color, kind: Int, seed: Double, t: Float,
                              jitter: CGFloat, isFocus: Bool) {
        let jx = CGFloat(sin(Double(t) * 1.7 + seed)) * jitter * 1.3
        let jy = CGFloat(sin(Double(t) * 2.1 + seed * 1.3)) * jitter * 0.8
        let ccx = cx + jx
        let ccy = cy + jy
        let size = min(cellW, cellH) * (isFocus ? 0.42 : 0.34)

        switch kind {
        case 0: // 铜币
            let r = size
            let coinRect = CGRect(x: ccx - r, y: ccy - r * 0.88,
                                  width: r * 2, height: r * 1.76)
            ctx.fill(Path(ellipseIn: coinRect),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: color, location: 0),
                            .init(color: color.opacity(0.55), location: 1)
                        ]),
                        center: CGPoint(x: ccx - r * 0.35, y: ccy - r * 0.30),
                        startRadius: 0, endRadius: r * 1.2
                     ))
            ctx.stroke(Path(ellipseIn: coinRect),
                       with: .color(color.opacity(0.55)), lineWidth: 0.5)
            // 内圈线
            let innerR = r * 0.55
            ctx.stroke(Path(ellipseIn: CGRect(x: ccx - innerR, y: ccy - innerR * 0.88,
                                               width: innerR * 2, height: innerR * 1.76)),
                       with: .color(color.opacity(0.35)), lineWidth: 0.4)
        case 1: // 贝壳
            let r = size
            var shell = Path()
            shell.move(to: CGPoint(x: ccx, y: ccy + r * 0.45))
            shell.addQuadCurve(to: CGPoint(x: ccx + r, y: ccy - r * 0.45),
                               control: CGPoint(x: ccx + r * 0.72, y: ccy + r * 0.22))
            shell.addQuadCurve(to: CGPoint(x: ccx - r, y: ccy - r * 0.45),
                               control: CGPoint(x: ccx, y: ccy - r * 0.92))
            shell.addQuadCurve(to: CGPoint(x: ccx, y: ccy + r * 0.45),
                               control: CGPoint(x: ccx - r * 0.72, y: ccy + r * 0.22))
            ctx.fill(shell, with: .linearGradient(
                Gradient(colors: [color, color.opacity(0.55)]),
                startPoint: CGPoint(x: ccx, y: ccy - r),
                endPoint: CGPoint(x: ccx, y: ccy + r)
            ))
            // 脊线
            for i in 0..<5 {
                let a = -.pi / 2 + CGFloat(i - 2) * .pi / 12
                var rib = Path()
                rib.move(to: CGPoint(x: ccx, y: ccy + r * 0.45))
                rib.addLine(to: CGPoint(x: ccx + cos(a) * r * 0.92,
                                        y: ccy + sin(a) * r * 0.92))
                ctx.stroke(rib, with: .color(color.opacity(0.45)), lineWidth: 0.5)
            }
        case 2: // 车票/纸签
            let rw = size * 1.55
            let rh = size * 0.82
            let pr = CGRect(x: ccx - rw/2, y: ccy - rh/2, width: rw, height: rh)
            ctx.fill(Path(roundedRect: pr, cornerRadius: 1), with: .color(color))
            // 票头齿孔感（左侧三道竖线）
            for i in 0..<3 {
                let px = pr.minX + 2.5 + CGFloat(i) * 2.5
                var dl = Path()
                dl.move(to: CGPoint(x: px, y: pr.minY + 2))
                dl.addLine(to: CGPoint(x: px, y: pr.maxY - 2))
                ctx.stroke(dl, with: .color(Color.black.opacity(0.28)), lineWidth: 0.3)
            }
            // 文字感横线
            for i in 0..<3 {
                var ln = Path()
                let ly = pr.minY + rh * (0.30 + CGFloat(i) * 0.18)
                ln.move(to: CGPoint(x: pr.minX + rw * 0.22, y: ly))
                ln.addLine(to: CGPoint(x: pr.maxX - rw * 0.10, y: ly))
                ctx.stroke(ln, with: .color(Color.black.opacity(0.38)), lineWidth: 0.4)
            }
        case 3: // 干花
            let r = size * 0.9
            for i in 0..<5 {
                let a = CGFloat(i) * .pi * 2 / 5
                let px = ccx + cos(a) * r * 0.48
                let py = ccy + sin(a) * r * 0.48
                let petal = CGRect(x: px - r * 0.36, y: py - r * 0.36,
                                   width: r * 0.72, height: r * 0.72)
                ctx.fill(Path(ellipseIn: petal), with: .color(color.opacity(0.88)))
            }
            let centerR = r * 0.22
            ctx.fill(Path(ellipseIn: CGRect(x: ccx - centerR, y: ccy - centerR,
                                             width: centerR * 2, height: centerR * 2)),
                     with: .color(Color(red: 0.55, green: 0.38, blue: 0.18)))
        case 4: // 鹅卵石
            let r = size
            let stoneRect = CGRect(x: ccx - r * 0.95, y: ccy - r * 0.62,
                                    width: r * 1.9, height: r * 1.24)
            ctx.fill(Path(ellipseIn: stoneRect),
                     with: .radialGradient(
                        Gradient(colors: [color, color.opacity(0.55)]),
                        center: CGPoint(x: ccx - r * 0.32, y: ccy - r * 0.28),
                        startRadius: 0, endRadius: r
                     ))
            // 薄高光
            var stoneHL = Path()
            stoneHL.addArc(center: CGPoint(x: ccx - r * 0.25, y: ccy - r * 0.15),
                           radius: r * 0.4,
                           startAngle: .radians(.pi * 1.15),
                           endAngle: .radians(.pi * 1.75),
                           clockwise: false)
            ctx.stroke(stoneHL, with: .color(Color.white.opacity(0.22)), lineWidth: 0.5)
        case 5: fallthrough
        default: // 叶子
            let r = size
            var leaf = Path()
            leaf.move(to: CGPoint(x: ccx - r * 0.32, y: ccy + r * 0.72))
            leaf.addQuadCurve(to: CGPoint(x: ccx + r * 0.72, y: ccy - r * 0.32),
                              control: CGPoint(x: ccx + r * 0.32, y: ccy + r * 0.15))
            leaf.addQuadCurve(to: CGPoint(x: ccx - r * 0.32, y: ccy + r * 0.72),
                              control: CGPoint(x: ccx - r * 0.15, y: ccy + r * 0.15))
            ctx.fill(leaf, with: .color(color))
            // 主脉
            var vein = Path()
            vein.move(to: CGPoint(x: ccx - r * 0.3, y: ccy + r * 0.7))
            vein.addLine(to: CGPoint(x: ccx + r * 0.72, y: ccy - r * 0.32))
            ctx.stroke(vein, with: .color(color.opacity(0.55)), lineWidth: 0.6)
        }
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

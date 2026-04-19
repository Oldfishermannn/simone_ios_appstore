import SwiftUI

// Favorites visualizer — Vinyl Booth (mid-century turntable).
//
// 小图 (expansion=0): 俯拍唱盘特写——黑胶 + 铜臂 + 中心贴纸，唱纹绕圈。
// 大图 (expansion=1): 3/4 视角拉远，唱机坐在桃木桌面上，
//                     右侧小铜台灯，左侧一沓黑胶封套斜靠墙，桌面纹理淡入。
//
// Object: mid-century 木底唱机。黑色 12 吋黑胶持续慢转。每圈唱纹的亮度
//         绑到一个频谱 bin —— 音乐"刻"在唱片上的感觉。
// Spectrum mapping:
//   - 低频 → 唱盘微微晃动 + 中心贴纸呼吸
//   - 中频 → 每圈唱纹的亮度 + 铜臂反光
//   - 高频 → 空气灰尘粒子 + 指示灯闪烁
struct VinylBoothView: View {
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

        // Palette
        let roomBg      = Color(red: 16/255,  green: 14/255,  blue: 18/255)
        let deskTone    = Color(red: 62/255,  green: 42/255,  blue: 28/255)
        let deskDark    = Color(red: 30/255,  green: 20/255,  blue: 12/255)
        let deskHL      = Color(red: 108/255, green: 78/255,  blue: 44/255)
        let plinthTop   = Color(red: 100/255, green: 74/255,  blue: 46/255)
        let plinthMid   = Color(red: 72/255,  green: 52/255,  blue: 30/255)
        let plinthDark  = Color(red: 30/255,  green: 20/255,  blue: 12/255)
        let vinylBlack  = Color(red: 14/255,  green: 12/255,  blue: 16/255)
        let vinylRim    = Color(red: 28/255,  green: 26/255,  blue: 30/255)
        let labelRed    = Color(red: 158/255, green: 46/255,  blue: 52/255)
        let labelGold   = Color(red: 208/255, green: 172/255, blue: 96/255)
        let brass       = Color(red: 210/255, green: 172/255, blue: 92/255)
        let brassDark   = Color(red: 110/255, green: 80/255,  blue: 38/255)
        let brassLit    = Color(red: 238/255, green: 210/255, blue: 150/255)
        let sleeveTones: [Color] = [
            Color(red: 74/255,  green: 62/255,  blue: 48/255),  // 棕
            Color(red: 46/255,  green: 56/255,  blue: 70/255),  // 深蓝
            Color(red: 100/255, green: 50/255,  blue: 52/255)   // 暗红
        ]

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
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.16 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.12 * idleBlend)
        let trebleCG = CGFloat(treble * (1 - idleBlend) + 0.06 * idleBlend)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ── 背景
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: roomBg.opacity(0.85), location: 0),
                            .init(color: roomBg,               location: 0.7),
                            .init(color: Color.black,          location: 1)
                        ]),
                        center: CGPoint(x: w * 0.28, y: h * 0.18),
                        startRadius: 0, endRadius: max(w, h)
                     ))

        // ── 桌面渐显（大图）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let deskRect = CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45)
                ctx.fill(Path(deskRect),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: deskTone.opacity(0.85), location: 0),
                                .init(color: deskDark,               location: 1)
                            ]),
                            startPoint: CGPoint(x: 0, y: deskRect.minY),
                            endPoint: CGPoint(x: 0, y: deskRect.maxY)
                         ))
                // 木纹横线
                for i in 0..<8 {
                    let gy = deskRect.minY + CGFloat(i) * (deskRect.height / 8) + 4
                    var grain = Path()
                    grain.move(to: CGPoint(x: 0, y: gy))
                    for px in stride(from: CGFloat(0), through: w, by: 7) {
                        let wobble = sin(Double(px) * 0.018 + Double(i) * 1.1) * 2.2
                        grain.addLine(to: CGPoint(x: px, y: gy + CGFloat(wobble)))
                    }
                    ctx.stroke(grain, with: .color(deskDark.opacity(0.55)), lineWidth: 0.6)
                }
                // 桌面前缘高光
                var edgeHL = Path()
                edgeHL.move(to: CGPoint(x: 0, y: deskRect.minY + 1))
                edgeHL.addLine(to: CGPoint(x: w, y: deskRect.minY + 1))
                ctx.stroke(edgeHL, with: .color(deskHL.opacity(0.55)), lineWidth: 1.0)
            }
        }

        // ── 黑胶 + 唱盘几何
        // 小图：正圆铺满画面中心（radius = 0.42 min(w,h)）
        // 大图：椭圆（y 轴压缩到 0.42），放在桌面偏左
        let rSmall: CGFloat = min(w, h) * 0.40
        let rBig:   CGFloat = min(w, h) * 0.24
        let rNow = rSmall + (rBig - rSmall) * e
        let aspectSmall: CGFloat = 1.0
        let aspectBig: CGFloat = 0.42
        let aspect = aspectSmall + (aspectBig - aspectSmall) * e

        let vinylCX = w * (0.50 + (0.38 - 0.50) * e)
        let vinylCY = h * (0.50 + (0.56 - 0.50) * e)

        // 微晃（低频）
        let wobbleX = CGFloat(sin(Double(t) * 2.3)) * bassCG * 1.5
        let wobbleY = CGFloat(cos(Double(t) * 1.9)) * bassCG * 1.2

        let cx = vinylCX + wobbleX
        let cy = vinylCY + wobbleY

        // ── Plinth（唱机底座）—— 大图显著，小图只露一圈
        let plinthW = rNow * (1.75 + e * 0.35)
        let plinthH = rNow * aspect * (1.4 + e * 0.6)
        let plinthRect = CGRect(x: cx - plinthW / 2,
                                 y: cy - plinthH * 0.42,
                                 width: plinthW,
                                 height: plinthH)
        // Plinth 顶面（矩形）
        let plinthTopRect = plinthRect
        context.fill(Path(roundedRect: plinthTopRect, cornerRadius: 4),
                     with: .linearGradient(
                        Gradient(colors: [plinthTop, plinthMid]),
                        startPoint: CGPoint(x: plinthTopRect.minX, y: plinthTopRect.minY),
                        endPoint: CGPoint(x: plinthTopRect.maxX, y: plinthTopRect.maxY)
                     ))
        // Plinth 前立面（大图才明显）—— 把底座厚度显示出来
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let sideH: CGFloat = 16 + e * 10
                let sideRect = CGRect(x: plinthTopRect.minX, y: plinthTopRect.maxY,
                                       width: plinthTopRect.width, height: sideH)
                ctx.fill(Path(sideRect),
                         with: .linearGradient(
                            Gradient(colors: [plinthMid, plinthDark]),
                            startPoint: CGPoint(x: 0, y: sideRect.minY),
                            endPoint: CGPoint(x: 0, y: sideRect.maxY)
                         ))
                // 前立面下投影
                var sh = Path()
                sh.move(to: CGPoint(x: sideRect.minX + 4, y: sideRect.maxY + 2))
                sh.addLine(to: CGPoint(x: sideRect.maxX - 4, y: sideRect.maxY + 2))
                ctx.stroke(sh, with: .color(Color.black.opacity(0.65)), lineWidth: 1.2)
            }
        }
        // Plinth 顶面高光
        var plHL = Path()
        plHL.move(to: CGPoint(x: plinthTopRect.minX + 4, y: plinthTopRect.minY + 1))
        plHL.addLine(to: CGPoint(x: plinthTopRect.maxX - 4, y: plinthTopRect.minY + 1))
        context.stroke(plHL, with: .color(deskHL.opacity(0.45)), lineWidth: 0.6)

        // ── 唱盘 platter（铜/银盘，凹槽一圈）
        let platterRX = rNow * 1.08
        let platterRY = rNow * aspect * 1.08
        let platterRect = CGRect(x: cx - platterRX, y: cy - platterRY,
                                  width: platterRX * 2, height: platterRY * 2)
        context.fill(Path(ellipseIn: platterRect),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color(red: 88/255, green: 72/255, blue: 50/255),
                                  location: 0),
                            .init(color: Color(red: 54/255, green: 42/255, blue: 28/255),
                                  location: 0.85),
                            .init(color: Color(red: 30/255, green: 22/255, blue: 14/255),
                                  location: 1)
                        ]),
                        center: CGPoint(x: cx - platterRX * 0.2, y: cy - platterRY * 0.2),
                        startRadius: 0, endRadius: platterRX * 1.1
                     ))
        // platter 边圈
        context.stroke(Path(ellipseIn: platterRect),
                       with: .color(brassDark.opacity(0.7)), lineWidth: 1.1)

        // ── 黑胶（椭圆）
        let vinylRect = CGRect(x: cx - rNow, y: cy - rNow * aspect,
                                width: rNow * 2, height: rNow * aspect * 2)
        context.fill(Path(ellipseIn: vinylRect),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: vinylRim,                     location: 0),
                            .init(color: vinylBlack,                   location: 0.3),
                            .init(color: Color(red: 6/255, green: 6/255, blue: 8/255),
                                  location: 1)
                        ]),
                        center: CGPoint(x: cx - rNow * 0.3, y: cy - rNow * aspect * 0.3),
                        startRadius: 0, endRadius: rNow * 1.2
                     ))
        // 黑胶边圈
        context.stroke(Path(ellipseIn: vinylRect),
                       with: .color(Color.black.opacity(0.7)), lineWidth: 0.8)

        // ── 唱纹：N 圈同心环（每圈绑定一个频谱 bin）
        // 签名映射：圈越外 = bin 越高频。亮度 = mag。
        let grooveCount = 24
        let startR: CGFloat = rNow * 0.30
        let endR:   CGFloat = rNow * 0.96
        let baseAngle = Double(t) * 0.42 // 唱盘常转
        for i in 0..<grooveCount {
            let tRing = CGFloat(i) / CGFloat(grooveCount - 1)
            let gr = startR + (endR - startR) * tRing
            let grY = gr * aspect
            let binIdx = Int(Double(i) * Double(spectrumData.count) / Double(grooveCount))
                .clamped(to: 0...(spectrumData.count - 1))
            let mag = CGFloat(spectrumData[binIdx]) * (1 - CGFloat(idleBlend))
                     + 0.08 * CGFloat(idleBlend)
            // 基础槽色（暗）
            let grooveRect = CGRect(x: cx - gr, y: cy - grY,
                                     width: gr * 2, height: grY * 2)
            context.stroke(Path(ellipseIn: grooveRect),
                           with: .color(Color.black.opacity(0.6)),
                           lineWidth: 0.4)
            // 高光环（随 mag 发亮）
            if mag > 0.05 {
                context.stroke(Path(ellipseIn: grooveRect),
                               with: .color(Color(red: 180/255, green: 180/255, blue: 186/255)
                                             .opacity(Double(mag) * 0.55)),
                               lineWidth: 0.6 + mag * 0.8)
            }
        }

        // ── 旋转高光弧（沿着唱盘绕圈走，模拟侧光反射）
        // 用"扇形"alpha 渐变
        let arcAlpha = 0.28 + Double(midCG) * 0.35
        context.drawLayer { ctx in
            ctx.opacity = arcAlpha
            var arc = Path()
            let arcAStart = baseAngle - .pi / 4
            let arcAEnd = baseAngle + .pi / 6
            arc.move(to: CGPoint(x: cx, y: cy))
            let steps = 24
            for s in 0...steps {
                let a = arcAStart + (arcAEnd - arcAStart) * Double(s) / Double(steps)
                let x = cx + CGFloat(cos(a)) * rNow * 0.92
                let y = cy + CGFloat(sin(a)) * rNow * aspect * 0.92
                arc.addLine(to: CGPoint(x: x, y: y))
            }
            arc.closeSubpath()
            ctx.fill(arc, with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.25),
                    Color.white.opacity(0.0)
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: rNow * 0.5, endRadius: rNow * 1.05
            ))
        }

        // ── 中心贴纸（红 + 金）
        let labelR = rNow * 0.26
        let labelRY = labelR * aspect
        let labelRect = CGRect(x: cx - labelR, y: cy - labelRY,
                                width: labelR * 2, height: labelRY * 2)
        // 贴纸呼吸（bass）
        let labelScale = 1.0 + bassCG * 0.06
        let scaledLabelR = labelR * labelScale
        let scaledLabelRY = labelRY * labelScale
        let scaledLabelRect = CGRect(x: cx - scaledLabelR, y: cy - scaledLabelRY,
                                      width: scaledLabelR * 2, height: scaledLabelRY * 2)
        context.fill(Path(ellipseIn: scaledLabelRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            labelRed.opacity(0.96),
                            Color(red: 100/255, green: 28/255, blue: 32/255)
                        ]),
                        center: CGPoint(x: cx - scaledLabelR * 0.3,
                                         y: cy - scaledLabelRY * 0.3),
                        startRadius: 0, endRadius: scaledLabelR * 1.1
                     ))
        // 贴纸金圈
        context.stroke(Path(ellipseIn: scaledLabelRect),
                       with: .color(labelGold.opacity(0.75)), lineWidth: 0.8)
        // 贴纸内小圈
        let innerLabelR = scaledLabelR * 0.42
        let innerLabelRY = scaledLabelRY * 0.42
        let innerLabelRect = CGRect(x: cx - innerLabelR, y: cy - innerLabelRY,
                                     width: innerLabelR * 2, height: innerLabelRY * 2)
        context.stroke(Path(ellipseIn: innerLabelRect),
                       with: .color(labelGold.opacity(0.55)), lineWidth: 0.5)
        // 贴纸金色小字感（两个圆点）
        for s in 0..<2 {
            let a = Double(s) * .pi - .pi / 2
            let tx = cx + CGFloat(cos(a)) * scaledLabelR * 0.55
            let ty = cy + CGFloat(sin(a)) * scaledLabelRY * 0.55
            let tr: CGFloat = 1.3
            context.fill(Path(ellipseIn: CGRect(x: tx - tr, y: ty - tr,
                                                 width: tr * 2, height: tr * 2)),
                         with: .color(labelGold.opacity(0.85)))
        }

        // ── 中心主轴（银色小钉）
        let spindleR: CGFloat = 3
        context.fill(Path(ellipseIn: CGRect(x: cx - spindleR, y: cy - spindleR * aspect,
                                             width: spindleR * 2, height: spindleR * 2 * aspect)),
                     with: .color(Color(red: 200/255, green: 200/255, blue: 206/255)))
        context.stroke(Path(ellipseIn: CGRect(x: cx - spindleR, y: cy - spindleR * aspect,
                                                width: spindleR * 2, height: spindleR * 2 * aspect)),
                       with: .color(Color.black.opacity(0.6)), lineWidth: 0.5)

        // ── 铜 tonearm（从右上角伸进来）
        // 枢轴（右后）
        let pivotX = cx + rNow * 1.35
        let pivotY = cy - rNow * aspect * 0.55
        let pivotR: CGFloat = 8 + e * 2
        // 枢轴底座
        context.fill(Path(ellipseIn: CGRect(x: pivotX - pivotR, y: pivotY - pivotR * aspect,
                                              width: pivotR * 2, height: pivotR * 2 * aspect)),
                     with: .radialGradient(
                        Gradient(colors: [brassLit, brass, brassDark]),
                        center: CGPoint(x: pivotX - pivotR * 0.3, y: pivotY - pivotR * 0.3),
                        startRadius: 0, endRadius: pivotR
                     ))
        context.stroke(Path(ellipseIn: CGRect(x: pivotX - pivotR, y: pivotY - pivotR * aspect,
                                                width: pivotR * 2, height: pivotR * 2 * aspect)),
                       with: .color(brassDark), lineWidth: 0.6)
        // 臂 —— 从 pivot 指向唱片 0.78r 处
        let armAngle: Double = .pi + (.pi * 0.22) + Double(midCG) * 0.02
        let headX = cx + CGFloat(cos(armAngle)) * rNow * 0.78
        let headY = cy + CGFloat(sin(armAngle)) * rNow * aspect * 0.78
        var arm = Path()
        arm.move(to: CGPoint(x: pivotX, y: pivotY))
        arm.addLine(to: CGPoint(x: headX, y: headY))
        context.stroke(arm, with: .linearGradient(
            Gradient(colors: [brassLit, brassDark]),
            startPoint: CGPoint(x: pivotX, y: pivotY),
            endPoint: CGPoint(x: headX, y: headY)
        ), lineWidth: 3.5)
        // 臂高光
        context.stroke(arm, with: .color(Color.white.opacity(0.4)), lineWidth: 1.0)
        // 针头（小黑盒）
        let cartRect = CGRect(x: headX - 5, y: headY - 3,
                               width: 10, height: 6)
        context.fill(Path(roundedRect: cartRect, cornerRadius: 1),
                     with: .color(Color(red: 22/255, green: 20/255, blue: 22/255)))
        context.stroke(Path(roundedRect: cartRect, cornerRadius: 1),
                       with: .color(brassDark), lineWidth: 0.4)

        // ── LED 指示灯（plinth 右下角，高频闪）
        let ledX = plinthTopRect.maxX - 12
        let ledY = plinthTopRect.maxY - 8
        let ledR: CGFloat = 2.2
        let ledBrightness = 0.55 + Double(trebleCG) * 0.9 + Double(sin(Double(t) * 4)) * 0.1
        context.fill(Path(ellipseIn: CGRect(x: ledX - ledR, y: ledY - ledR,
                                              width: ledR * 2, height: ledR * 2)),
                     with: .radialGradient(
                        Gradient(colors: [
                            labelRed.opacity(min(1.0, ledBrightness)),
                            labelRed.opacity(0)
                        ]),
                        center: CGPoint(x: ledX, y: ledY),
                        startRadius: 0, endRadius: ledR * 3
                     ))
        context.fill(Path(ellipseIn: CGRect(x: ledX - ledR * 0.5, y: ledY - ledR * 0.5,
                                              width: ledR, height: ledR)),
                     with: .color(Color.white.opacity(0.8)))

        // ── 黑胶封套（大图：右侧靠墙 3 只）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let baseY = h * 0.85
                for i in 0..<3 {
                    let sx = w * (0.72 + CGFloat(i) * 0.06)
                    let sleeveW = w * 0.14
                    let sleeveH = h * 0.28
                    let tilt: CGFloat = -0.10 + CGFloat(i) * 0.04
                    let cosR = cos(tilt), sinR = sin(tilt)
                    let ccx = sx
                    let ccy = baseY - sleeveH / 2
                    func tr(_ p: CGPoint) -> CGPoint {
                        let dx = p.x - ccx, dy = p.y - ccy
                        return CGPoint(x: ccx + dx * cosR - dy * sinR,
                                       y: ccy + dx * sinR + dy * cosR)
                    }
                    let c = [
                        tr(CGPoint(x: ccx - sleeveW / 2, y: ccy - sleeveH / 2)),
                        tr(CGPoint(x: ccx + sleeveW / 2, y: ccy - sleeveH / 2)),
                        tr(CGPoint(x: ccx + sleeveW / 2, y: ccy + sleeveH / 2)),
                        tr(CGPoint(x: ccx - sleeveW / 2, y: ccy + sleeveH / 2))
                    ]
                    var sl = Path()
                    sl.move(to: c[0])
                    for p in c.dropFirst() { sl.addLine(to: p) }
                    sl.closeSubpath()
                    let tone = sleeveTones[i]
                    ctx.fill(sl,
                             with: .linearGradient(
                                Gradient(colors: [tone, tone.opacity(0.55)]),
                                startPoint: c[0], endPoint: c[2]
                             ))
                    ctx.stroke(sl, with: .color(Color.black.opacity(0.75)), lineWidth: 0.9)
                    // 封套里黑胶露头（顶部圆弧）
                    let discR = sleeveW * 0.38
                    let discC = tr(CGPoint(x: ccx, y: ccy - sleeveH / 2 + discR * 0.4))
                    ctx.fill(Path(ellipseIn: CGRect(x: discC.x - discR, y: discC.y - discR,
                                                       width: discR * 2, height: discR * 2)),
                             with: .color(vinylBlack))
                    // 黑胶中心贴纸
                    let lR = discR * 0.35
                    ctx.fill(Path(ellipseIn: CGRect(x: discC.x - lR, y: discC.y - lR,
                                                       width: lR * 2, height: lR * 2)),
                             with: .color(labelRed))
                }
            }
        }

        // ── 铜台灯（大图：右上角，温暖散光）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let lampX = w * 0.88
                let lampBaseY = h * 0.60
                // 灯杆
                var pole = Path()
                pole.move(to: CGPoint(x: lampX, y: lampBaseY))
                pole.addLine(to: CGPoint(x: lampX - 18, y: lampBaseY - h * 0.24))
                ctx.stroke(pole, with: .color(brassDark), lineWidth: 2.0)
                // 臂
                var lampArm = Path()
                lampArm.move(to: CGPoint(x: lampX - 18, y: lampBaseY - h * 0.24))
                lampArm.addLine(to: CGPoint(x: lampX - 50, y: lampBaseY - h * 0.27))
                ctx.stroke(lampArm, with: .color(brassDark), lineWidth: 1.8)
                // 灯罩
                let shadeX = lampX - 50
                let shadeY = lampBaseY - h * 0.27
                var shade = Path()
                shade.move(to: CGPoint(x: shadeX - 14, y: shadeY - 6))
                shade.addLine(to: CGPoint(x: shadeX + 14, y: shadeY - 6))
                shade.addLine(to: CGPoint(x: shadeX + 8,  y: shadeY + 12))
                shade.addLine(to: CGPoint(x: shadeX - 8,  y: shadeY + 12))
                shade.closeSubpath()
                ctx.fill(shade,
                         with: .linearGradient(
                            Gradient(colors: [brassLit, brass, brassDark]),
                            startPoint: CGPoint(x: shadeX - 14, y: shadeY - 6),
                            endPoint: CGPoint(x: shadeX + 8, y: shadeY + 12)
                         ))
                ctx.stroke(shade, with: .color(brassDark), lineWidth: 0.5)
                // 底座
                ctx.fill(Path(ellipseIn: CGRect(x: lampX - 14, y: lampBaseY - 5,
                                                  width: 28, height: 8)),
                         with: .color(brassDark))
                // 灯光晕
                let glowR: CGFloat = 70 + midCG * 30
                ctx.fill(Path(ellipseIn: CGRect(x: shadeX - glowR, y: shadeY + 4,
                                                  width: glowR * 2, height: glowR * 1.5)),
                         with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 240/255, green: 198/255, blue: 130/255).opacity(0.22),
                                Color.clear
                            ]),
                            center: CGPoint(x: shadeX, y: shadeY + 10),
                            startRadius: 0, endRadius: glowR
                         ))
            }
        }

        // ── 灰尘粒子
        if treble > 0.06 {
            let dustCount = min(Int(treble * 80), 24)
            for i in 0..<dustCount {
                let s = Double(i) * 11.31
                let xRand = (sin(Double(t) * 0.25 + s) * 0.5 + 0.5)
                let yRand = (cos(Double(t) * 0.19 + s * 1.3) * 0.5 + 0.5)
                let x = CGFloat(xRand) * w
                let y = CGFloat(yRand) * h * 0.55
                let alpha = 0.25 + Double(treble) * 0.45
                let dotR: CGFloat = 0.7 + CGFloat(treble) * 0.8
                context.fill(Path(ellipseIn: CGRect(x: x, y: y,
                                                       width: dotR * 2, height: dotR * 2)),
                             with: .color(brassLit.opacity(alpha * 0.45)))
            }
        }
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

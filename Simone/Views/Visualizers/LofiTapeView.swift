import SwiftUI

// Lo-fi visualizer — Cassette Tape "90 Minutes".
//
// Object: 一盒 TDK 风格卡带，微微倾斜放在桌上，盖板透出两只磁芯，在中间
// 拉着一条下坠的磁带。bass 驱动磁芯转动速度，mid 驱动磁带下坠弧度，
// treble 在 label 区域撒 hiss 噪点。
//
// Palette（OKLCH → sRGB 近似）:
//   shell       oklch(0.88 0.05 85) → rgb(246, 232, 200)
//   label       oklch(0.93 0.04 85) → rgb(252, 240, 214)
//   labelLine   oklch(0.65 0.06 70) → rgb(186, 162, 120)
//   window      oklch(0.22 0.03 55) → rgb( 58,  42,  32)
//   hub         oklch(0.35 0.04 55) → rgb( 98,  76,  58)
//   hubRing     oklch(0.50 0.08 60) → rgb(148, 108,  72)
//   tape        oklch(0.18 0.02 55) → rgb( 36,  28,  22)
//   accent      oklch(0.65 0.11 55) → rgb(188, 126,  72)  铜色
struct LofiTapeView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderTape(context: context, size: size, binCount: binCount)
        }
    }

    private func renderTape(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let isBig = density > 1

        let shell     = Color(red: 246/255, green: 232/255, blue: 200/255)
        let label     = Color(red: 252/255, green: 240/255, blue: 214/255)
        let labelLine = Color(red: 186/255, green: 162/255, blue: 120/255)
        let window    = Color(red:  58/255, green:  42/255, blue:  32/255)
        let hub       = Color(red:  98/255, green:  76/255, blue:  58/255)
        let hubRing   = Color(red: 148/255, green: 108/255, blue:  72/255)
        let tape      = Color(red:  36/255, green:  28/255, blue:  22/255)
        let accent    = Color(red: 188/255, green: 126/255, blue:  72/255)

        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)
        let bassCG  = CGFloat(bass * (1 - idleBlend) + 0.30 * idleBlend)
        let midCG   = CGFloat(mid  * (1 - idleBlend) + 0.28 * idleBlend)
        let trebCG  = CGFloat(treble * (1 - idleBlend))

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // 大图有桌面暖光，小图透明漂在 immersive 底上
        if isBig {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: Color(red: 58/255, green: 42/255, blue: 32/255).opacity(0.55), location: 0),
                                .init(color: Color(red: 24/255, green: 18/255, blue: 14/255), location: 0.75),
                                .init(color: Color(red: 24/255, green: 18/255, blue: 14/255), location: 1)
                            ]),
                            center: CGPoint(x: w * 0.78, y: h * 0.18),
                            startRadius: 0, endRadius: max(w, h) * 0.95
                         ))
        }

        let bodyW: CGFloat = w * (isBig ? 0.58 : 0.76)
        let bodyH: CGFloat = bodyW * 0.60
        let cx: CGFloat = w * 0.5
        let cy: CGFloat = h * (isBig ? 0.55 : 0.5)
        let tilt: CGFloat = -0.04

        // 阴影（仅大图）
        if isBig {
            let shWidth: CGFloat = bodyW * 1.15
            let shHeight: CGFloat = bodyH * 0.22
            let shRect = CGRect(
                x: cx - shWidth / 2,
                y: cy + bodyH * 0.46,
                width: shWidth,
                height: shHeight
            )
            context.fill(Path(ellipseIn: shRect),
                         with: .radialGradient(
                            Gradient(colors: [
                                Color.black.opacity(0.5),
                                Color.black.opacity(0)
                            ]),
                            center: CGPoint(x: cx, y: cy + bodyH * 0.55),
                            startRadius: 0,
                            endRadius: bodyW * 0.55
                         ))
        }

        // 卡带本体 — 用 drawLayer 做倾斜
        context.drawLayer { layer in
            layer.translateBy(x: cx, y: cy)
            layer.rotate(by: .radians(tilt))

            let halfW = bodyW / 2
            let halfH = bodyH / 2
            let bodyRect = CGRect(x: -halfW, y: -halfH, width: bodyW, height: bodyH)

            // 外壳
            let shellPath = Path(roundedRect: bodyRect, cornerRadius: bodyW * 0.025)
            layer.fill(shellPath, with: .color(shell))

            // 外壳高光（顶部一条）
            var topHL = Path()
            topHL.move(to: CGPoint(x: -halfW + bodyW * 0.06, y: -halfH + 3))
            topHL.addLine(to: CGPoint(x: halfW - bodyW * 0.06, y: -halfH + 3))
            layer.stroke(topHL, with: .color(Color.white.opacity(0.28)), lineWidth: 0.8)

            // label 区（上半）
            let labelTop = -halfH + bodyH * 0.08
            let labelH = bodyH * 0.34
            let labelRect = CGRect(
                x: -halfW + bodyW * 0.05,
                y: labelTop,
                width: bodyW * 0.90,
                height: labelH
            )
            layer.fill(Path(roundedRect: labelRect, cornerRadius: bodyW * 0.008),
                       with: .color(label))
            layer.stroke(Path(roundedRect: labelRect, cornerRadius: bodyW * 0.008),
                         with: .color(labelLine.opacity(0.35)), lineWidth: 0.5)

            // 铜色徽条
            let accentRect = CGRect(
                x: labelRect.minX + bodyW * 0.035,
                y: labelRect.minY + bodyH * 0.03,
                width: bodyW * 0.14,
                height: bodyH * 0.035
            )
            layer.fill(Path(accentRect), with: .color(accent.opacity(0.85)))

            // label 线（3 条写字线）
            for i in 0..<3 {
                let lineY = labelRect.minY + labelH * (0.42 + CGFloat(i) * 0.18)
                var line = Path()
                line.move(to: CGPoint(x: labelRect.minX + bodyW * 0.04, y: lineY))
                line.addLine(to: CGPoint(x: labelRect.maxX - bodyW * 0.04, y: lineY))
                layer.stroke(line, with: .color(labelLine.opacity(0.40)), lineWidth: 0.5)
            }

            // hiss 噪点 — label 上的磁粉颗粒，treble 驱动密度
            if trebCG > 0.02 {
                let count = min(Int(trebCG * 180), 36)
                for i in 0..<count {
                    let seed = sin(Double(i) * 13.37 + Double(t) * 7.7)
                    let frx = seed - floor(seed)
                    let seed2 = sin(Double(i) * 39.1 + Double(t) * 4.3)
                    let fry = seed2 - floor(seed2)
                    let rx = labelRect.minX + CGFloat(frx) * labelRect.width
                    let ry = labelRect.minY + CGFloat(fry) * labelRect.height
                    let dotRect = CGRect(x: rx, y: ry, width: 0.9, height: 0.9)
                    layer.fill(Path(ellipseIn: dotRect),
                               with: .color(labelLine.opacity(Double(trebCG) * 0.55)))
                }
            }

            // 下半：磁芯窗口
            let winW = bodyW * 0.74
            let winH = bodyH * 0.30
            let winY = bodyH * 0.08
            let winRect = CGRect(x: -winW / 2, y: winY, width: winW, height: winH)
            layer.fill(Path(roundedRect: winRect, cornerRadius: 3),
                       with: .color(window))
            layer.stroke(Path(roundedRect: winRect, cornerRadius: 3),
                         with: .color(Color.black.opacity(0.4)), lineWidth: 0.6)

            // 磁带（catenary curve between hubs）
            let hubR: CGFloat = bodyH * 0.12
            let hubSep: CGFloat = winW * 0.30
            let hubYCoord: CGFloat = winY + winH / 2
            let leftHubX: CGFloat = -hubSep
            let rightHubX: CGFloat = hubSep

            let sagBase: CGFloat = winH * 0.15
            let sagSpec: CGFloat = winH * 0.32 * midCG
            let sag: CGFloat = sagBase + sagSpec + CGFloat(sinf(t * 0.7)) * winH * 0.04

            var tapePath = Path()
            tapePath.move(to: CGPoint(x: leftHubX + hubR * 0.55, y: hubYCoord - 1))
            tapePath.addQuadCurve(
                to: CGPoint(x: rightHubX - hubR * 0.55, y: hubYCoord - 1),
                control: CGPoint(x: 0, y: hubYCoord + sag)
            )
            layer.stroke(tapePath, with: .color(tape), lineWidth: 2.2)
            layer.stroke(tapePath, with: .color(accent.opacity(0.25)), lineWidth: 0.6)

            // 两个磁芯（左右转向相反，速度随 bass 加成）
            let omega: Float = 0.35 + Float(bassCG) * 1.1
            let angleLeft = CGFloat(t * omega)
            let angleRight = -CGFloat(t * omega * 1.03)

            drawHub(on: layer, center: CGPoint(x: leftHubX, y: hubYCoord),
                    radius: hubR, angle: angleLeft, hub: hub, ring: hubRing)
            drawHub(on: layer, center: CGPoint(x: rightHubX, y: hubYCoord),
                    radius: hubR, angle: angleRight, hub: hub, ring: hubRing)

            // 底部 5 个 drive hole（小槽）
            let holeY: CGFloat = bodyH * 0.43
            for i in 0..<5 {
                let hxRatio: CGFloat = -0.32 + CGFloat(i) * 0.16
                let hx: CGFloat = bodyW * hxRatio
                let holeRect = CGRect(x: hx - 2, y: holeY, width: 4, height: 2)
                layer.fill(Path(roundedRect: holeRect, cornerRadius: 1),
                           with: .color(window.opacity(0.75)))
            }

            // A/B 面标识（小字仅大图）
            if isBig {
                let capRect = CGRect(
                    x: halfW - bodyW * 0.06,
                    y: halfH - bodyH * 0.12,
                    width: bodyW * 0.035,
                    height: bodyH * 0.06
                )
                layer.fill(Path(roundedRect: capRect, cornerRadius: 1),
                           with: .color(labelLine.opacity(0.45)))
            }
        }
    }

    private func drawHub(on ctx: GraphicsContext, center: CGPoint, radius: CGFloat,
                         angle: CGFloat, hub: Color, ring: Color) {
        // 外圈齿轮
        let ringRect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: ringRect), with: .color(ring))

        // 内盘
        let innerR = radius * 0.76
        let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR,
                               width: innerR * 2, height: innerR * 2)
        ctx.fill(Path(ellipseIn: innerRect), with: .color(hub))

        // 6 根辐条
        let spokeOuter = innerR * 0.90
        let spokeInner = innerR * 0.28
        for i in 0..<6 {
            let a = angle + CGFloat(i) * .pi / 3
            let cosA = cos(a)
            let sinA = sin(a)
            var spoke = Path()
            spoke.move(to: CGPoint(x: center.x + spokeInner * cosA,
                                   y: center.y + spokeInner * sinA))
            spoke.addLine(to: CGPoint(x: center.x + spokeOuter * cosA,
                                      y: center.y + spokeOuter * sinA))
            ctx.stroke(spoke, with: .color(hub.opacity(0.45)), lineWidth: 1.0)
        }

        // 中心轴
        let pinR = innerR * 0.14
        let pinRect = CGRect(x: center.x - pinR, y: center.y - pinR,
                             width: pinR * 2, height: pinR * 2)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(ring.opacity(0.95)))
    }
}

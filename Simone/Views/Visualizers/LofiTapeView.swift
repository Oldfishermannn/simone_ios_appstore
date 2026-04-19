import SwiftUI

// Lo-fi visualizer — Cassette Tape "90 Minutes".
//
// Object: 一盒 TDK 风格卡带，微微倾斜放在桌上，盖板透出两只磁芯。
// 磁带本身是 spectrum waveform（cassette literally stores waveforms——
// 叙事一致），hub 外缘绑 8 bins 做圆形频谱环，label 分 3 频段撒 hiss。
// 大图加完整场景：桌面木纹 + 侧光束 + 长影 + 背景唱片沟纹 + 飘尘。
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
//   woodLit     oklch(0.32 0.04 55) → rgb( 78,  50,  34)  桌面亮色
//   woodDark    oklch(0.18 0.02 50) → rgb( 38,  26,  20)  桌面暗色
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
        let woodLit   = Color(red:  78/255, green:  50/255, blue:  34/255)
        let woodDark  = Color(red:  38/255, green:  26/255, blue:  20/255)

        // Frequency bands
        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0, treble: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
        bass /= Float(thirds); mid /= Float(thirds)
        treble /= Float(binCount - 2 * thirds)
        let bassCG = CGFloat(bass * (1 - idleBlend) + 0.30 * idleBlend)
        let midCG  = CGFloat(mid  * (1 - idleBlend) + 0.28 * idleBlend)
        let trebCG = CGFloat(treble * (1 - idleBlend))

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ─── Big-mode scene (beneath the tape) ──────────────────────────
        if isBig {
            // 1. 暖色 vignette 底
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: Color(red: 58/255, green: 42/255, blue: 32/255).opacity(0.55), location: 0),
                                .init(color: Color(red: 24/255, green: 18/255, blue: 14/255), location: 0.7),
                                .init(color: Color(red: 16/255, green: 12/255, blue: 10/255), location: 1)
                            ]),
                            center: CGPoint(x: w * 0.82, y: h * 0.18),
                            startRadius: 0, endRadius: max(w, h) * 0.98
                         ))

            // 2. 背景唱片沟纹（左上，mid 推着微扩）
            let grooveCenter = CGPoint(x: w * 0.08, y: h * 0.12)
            let grooveBase: CGFloat = min(w, h) * 0.38 + midCG * 6
            for i in 0..<5 {
                let r = grooveBase + CGFloat(i) * 10
                let gr = CGRect(x: grooveCenter.x - r, y: grooveCenter.y - r,
                                width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: gr),
                               with: .color(accent.opacity(0.09 - Double(i) * 0.015)),
                               lineWidth: 0.5)
            }

            // 3. 桌面木纹（下半）
            let deskY: CGFloat = h * 0.62
            let deskRect = CGRect(x: 0, y: deskY, width: w, height: h - deskY)
            context.fill(Path(deskRect),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: woodLit.opacity(0.92), location: 0),
                                .init(color: woodDark, location: 1)
                            ]),
                            startPoint: CGPoint(x: w * 0.5, y: deskY),
                            endPoint: CGPoint(x: w * 0.5, y: h)
                         ))
            // 桌面横纹（木理）
            for i in 0..<8 {
                let ty = deskY + CGFloat(i) * ((h - deskY) / 8) + CGFloat(sinf(Float(i) * 2.3)) * 1.2
                var line = Path()
                line.move(to: CGPoint(x: 0, y: ty))
                line.addLine(to: CGPoint(x: w, y: ty))
                context.stroke(line, with: .color(woodDark.opacity(0.45)), lineWidth: 0.4)
            }

            // 4. 侧光束（从右上斜切，低 alpha）
            var beam = Path()
            let beamTR = CGPoint(x: w * 1.02, y: h * 0.02)
            let beamTL = CGPoint(x: w * 0.70, y: h * -0.04)
            let beamBL = CGPoint(x: w * 0.10, y: h * 0.78)
            let beamBR = CGPoint(x: w * 0.42, y: h * 0.86)
            beam.move(to: beamTL)
            beam.addLine(to: beamTR)
            beam.addLine(to: beamBR)
            beam.addLine(to: beamBL)
            beam.closeSubpath()
            context.fill(beam,
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: accent.opacity(0.00), location: 0),
                                .init(color: accent.opacity(0.16), location: 0.5),
                                .init(color: accent.opacity(0.00), location: 1)
                            ]),
                            startPoint: CGPoint(x: w * 0.80, y: 0),
                            endPoint: CGPoint(x: w * 0.26, y: h * 0.82)
                         ))

            // 5. 飘尘（12 颗，随 t 慢漂）
            for i in 0..<12 {
                let sx = sin(Double(i) * 11.3 + Double(t) * 0.06)
                let sy = sin(Double(i) * 7.7 + 3.1 + Double(t) * 0.04)
                let fx = (sx + 1) * 0.5
                let fy = (sy + 1) * 0.5
                let dx = CGFloat(fx) * w
                let dy = CGFloat(fy) * h * 0.60
                let ds: CGFloat = 0.7 + CGFloat(abs(sin(Double(i) * 5.1))) * 0.6
                let dustRect = CGRect(x: dx, y: dy, width: ds, height: ds)
                context.fill(Path(ellipseIn: dustRect),
                             with: .color(Color.white.opacity(0.30)))
            }
        }

        let bodyW: CGFloat = w * (isBig ? 0.64 : 0.78)
        let bodyH: CGFloat = bodyW * 0.60
        let cx: CGFloat = w * 0.5
        let cy: CGFloat = h * (isBig ? 0.48 : 0.5)
        let tilt: CGFloat = -0.04

        // 卡带长影（大图 only，向左下倾斜）
        if isBig {
            var shadow = Path()
            let shTopY = cy + bodyH * 0.45
            let shBotY = cy + bodyH * 0.48 + bodyH * 0.28
            let shTopXL = cx - bodyW * 0.54
            let shTopXR = cx + bodyW * 0.54
            let shBotXL = shTopXL - bodyW * 0.22  // skew 向左
            let shBotXR = shTopXR - bodyW * 0.22
            shadow.move(to: CGPoint(x: shTopXL, y: shTopY))
            shadow.addLine(to: CGPoint(x: shTopXR, y: shTopY))
            shadow.addLine(to: CGPoint(x: shBotXR, y: shBotY))
            shadow.addLine(to: CGPoint(x: shBotXL, y: shBotY))
            shadow.closeSubpath()
            context.fill(shadow,
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Color.black.opacity(0.55), location: 0),
                                .init(color: Color.black.opacity(0.05), location: 1)
                            ]),
                            startPoint: CGPoint(x: cx, y: shTopY),
                            endPoint: CGPoint(x: cx - bodyW * 0.22, y: shBotY)
                         ))
        }

        // 卡带本体
        context.drawLayer { layer in
            layer.translateBy(x: cx, y: cy)
            layer.rotate(by: .radians(tilt))

            let halfW = bodyW / 2
            let halfH = bodyH / 2
            let bodyRect = CGRect(x: -halfW, y: -halfH, width: bodyW, height: bodyH)

            // Shell
            layer.fill(Path(roundedRect: bodyRect, cornerRadius: bodyW * 0.025),
                       with: .color(shell))
            // Shell top edge highlight
            var topHL = Path()
            topHL.move(to: CGPoint(x: -halfW + bodyW * 0.06, y: -halfH + 3))
            topHL.addLine(to: CGPoint(x: halfW - bodyW * 0.06, y: -halfH + 3))
            layer.stroke(topHL, with: .color(Color.white.opacity(0.28)), lineWidth: 0.8)

            // Label panel
            let labelTop = -halfH + bodyH * 0.08
            let labelH = bodyH * 0.34
            let labelRect = CGRect(x: -halfW + bodyW * 0.05, y: labelTop,
                                   width: bodyW * 0.90, height: labelH)
            layer.fill(Path(roundedRect: labelRect, cornerRadius: bodyW * 0.008),
                       with: .color(label))
            layer.stroke(Path(roundedRect: labelRect, cornerRadius: bodyW * 0.008),
                         with: .color(labelLine.opacity(0.35)), lineWidth: 0.5)

            // Bronze accent bar
            let accentRect = CGRect(
                x: labelRect.minX + bodyW * 0.035,
                y: labelRect.minY + bodyH * 0.03,
                width: bodyW * 0.14,
                height: bodyH * 0.035
            )
            layer.fill(Path(accentRect), with: .color(accent.opacity(0.85)))

            // Writing lines (3)
            for i in 0..<3 {
                let lineY = labelRect.minY + labelH * (0.42 + CGFloat(i) * 0.18)
                var line = Path()
                line.move(to: CGPoint(x: labelRect.minX + bodyW * 0.04, y: lineY))
                line.addLine(to: CGPoint(x: labelRect.maxX - bodyW * 0.04, y: lineY))
                layer.stroke(line, with: .color(labelLine.opacity(0.40)), lineWidth: 0.5)
            }

            // Hiss — 3 horizontal bands (low/mid/high), dot size & density per band
            let zoneH = labelH / 3
            let bandsEnergy: [CGFloat] = [bassCG, midCG, trebCG]
            let bandDotSize: [CGFloat] = [1.4, 0.9, 0.55]  // 低频大点 → 高频细颗粒
            for zone in 0..<3 {
                let energy = bandsEnergy[zone]
                guard energy > 0.015 else { continue }
                let zoneTop = labelRect.minY + CGFloat(zone) * zoneH
                let count = min(Int(Double(energy) * 80), 26)
                for i in 0..<count {
                    let sx = sin(Double(zone * 200 + i) * 13.37 + Double(t) * 6.8)
                    let sy = sin(Double(zone * 200 + i) * 39.1 + Double(t) * 4.3)
                    let frx = sx - floor(sx)
                    let fry = sy - floor(sy)
                    let rx = labelRect.minX + CGFloat(frx) * labelRect.width
                    let ry = zoneTop + CGFloat(fry) * zoneH
                    let ds = bandDotSize[zone]
                    let dotRect = CGRect(x: rx, y: ry, width: ds, height: ds)
                    layer.fill(Path(ellipseIn: dotRect),
                               with: .color(labelLine.opacity(Double(energy) * 0.70)))
                }
            }

            // Window
            let winW = bodyW * 0.74
            let winH = bodyH * 0.30
            let winY = bodyH * 0.08
            let winRect = CGRect(x: -winW / 2, y: winY, width: winW, height: winH)
            layer.fill(Path(roundedRect: winRect, cornerRadius: 3),
                       with: .color(window))
            layer.stroke(Path(roundedRect: winRect, cornerRadius: 3),
                         with: .color(Color.black.opacity(0.4)), lineWidth: 0.6)

            // === Tape as spectrum waveform ===
            let hubR: CGFloat = bodyH * 0.12
            let hubSep: CGFloat = winW * 0.30
            let hubYCoord: CGFloat = winY + winH / 2
            let leftHubX: CGFloat = -hubSep
            let rightHubX: CGFloat = hubSep

            let sagBase: CGFloat = winH * 0.10
            let sagSpec: CGFloat = winH * 0.14 * midCG
            let sag: CGFloat = sagBase + sagSpec + CGFloat(sinf(t * 0.7)) * winH * 0.015

            // Sample N bins along the visible tape span
            let N = 18
            let tapeStart = CGPoint(x: leftHubX + hubR * 0.55, y: hubYCoord - 0.5)
            let tapeEnd = CGPoint(x: rightHubX - hubR * 0.55, y: hubYCoord - 0.5)
            let tapeLen = tapeEnd.x - tapeStart.x
            let waveAmp: CGFloat = winH * 0.28 * (1 - CGFloat(idleBlend) * 0.7)

            var pts: [CGPoint] = []
            for i in 0..<N {
                let u: CGFloat = CGFloat(i) / CGFloat(N - 1)
                let parab = 4 * u * (1 - u)           // 0 at ends, 1 at middle
                let baseY = hubYCoord + sag * parab
                let binF = Float(i) / Float(N - 1) * Float(binCount - 1)
                let binIdx = min(binCount - 1, max(0, Int(binF)))
                let binVal = CGFloat(spectrumData[binIdx])
                let sign: CGFloat = (i % 2 == 0) ? 1 : -1
                let env = sin(CGFloat.pi * u)         // endpoints snap to hub
                let yOff = sign * binVal * waveAmp * env
                let x = tapeStart.x + u * tapeLen
                pts.append(CGPoint(x: x, y: baseY + yOff))
            }

            // Smooth path via midpoint-quad
            var tapePath = Path()
            tapePath.move(to: tapeStart)
            for i in 0..<(pts.count - 1) {
                let mid = CGPoint(x: (pts[i].x + pts[i+1].x) / 2,
                                  y: (pts[i].y + pts[i+1].y) / 2)
                tapePath.addQuadCurve(to: mid, control: pts[i])
            }
            tapePath.addQuadCurve(to: tapeEnd, control: pts.last!)
            layer.stroke(tapePath, with: .color(tape), lineWidth: 2.4)
            layer.stroke(tapePath, with: .color(accent.opacity(0.28)), lineWidth: 0.7)

            // Hubs — spin + bin-bound rim dots
            let omega: Float = 0.35 + Float(bassCG) * 1.1
            let angleLeft = CGFloat(t * omega)
            let angleRight = -CGFloat(t * omega * 1.03)

            // 左 hub: 前 8 bins（低频）
            let leftBins: [CGFloat] = (0..<8).map { i in
                CGFloat(spectrumData[min(i, binCount - 1)])
            }
            // 右 hub: 后 8 bins（高频）
            let rightBins: [CGFloat] = (0..<8).map { i in
                let idx = max(0, binCount - 8 + i)
                return CGFloat(spectrumData[min(idx, binCount - 1)])
            }

            drawHub(on: layer, center: CGPoint(x: leftHubX, y: hubYCoord),
                    radius: hubR, angle: angleLeft, hub: hub, ring: hubRing,
                    accent: accent, rimBins: leftBins)
            drawHub(on: layer, center: CGPoint(x: rightHubX, y: hubYCoord),
                    radius: hubR, angle: angleRight, hub: hub, ring: hubRing,
                    accent: accent, rimBins: rightBins)

            // 5 drive holes
            let holeY: CGFloat = bodyH * 0.43
            for i in 0..<5 {
                let hxRatio: CGFloat = -0.32 + CGFloat(i) * 0.16
                let hx: CGFloat = bodyW * hxRatio
                let holeRect = CGRect(x: hx - 2, y: holeY, width: 4, height: 2)
                layer.fill(Path(roundedRect: holeRect, cornerRadius: 1),
                           with: .color(window.opacity(0.75)))
            }

            // A/B cap (big only)
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
                         angle: CGFloat, hub: Color, ring: Color, accent: Color,
                         rimBins: [CGFloat]) {
        // 外圈
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
            let cosA = cos(a), sinA = sin(a)
            var spoke = Path()
            spoke.move(to: CGPoint(x: center.x + spokeInner * cosA,
                                   y: center.y + spokeInner * sinA))
            spoke.addLine(to: CGPoint(x: center.x + spokeOuter * cosA,
                                      y: center.y + spokeOuter * sinA))
            ctx.stroke(spoke, with: .color(hub.opacity(0.45)), lineWidth: 1.0)
        }

        // Rim bins — 8 radial dots on the outer rim, each bin a copper LED
        let rimR: CGFloat = radius * 1.05
        let rimCount = rimBins.count
        for i in 0..<rimCount {
            let a = angle + CGFloat(i) * (.pi * 2 / CGFloat(rimCount))
            let cosA = cos(a), sinA = sin(a)
            let binVal = rimBins[i]
            // dot pushed further out by binVal → visible "frequency petal"
            let distance = rimR + binVal * radius * 0.80
            let dx = center.x + distance * cosA
            let dy = center.y + distance * sinA
            let dotSize: CGFloat = 1.5 + binVal * 2.0
            let dotRect = CGRect(x: dx - dotSize / 2, y: dy - dotSize / 2,
                                 width: dotSize, height: dotSize)
            ctx.fill(Path(ellipseIn: dotRect),
                     with: .color(accent.opacity(0.45 + Double(binVal) * 0.55)))
        }

        // 中心轴
        let pinR = innerR * 0.14
        let pinRect = CGRect(x: center.x - pinR, y: center.y - pinR,
                             width: pinR * 2, height: pinR * 2)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(ring.opacity(0.95)))
    }
}

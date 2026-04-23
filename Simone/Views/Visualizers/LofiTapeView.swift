import SwiftUI

// Lo-fi visualizer — Cassette Tape "90 Minutes".
//
// 小图：一盒卡带 tilt=-0.04 随意放着，漂在 immersive 底上。
// 大图：卡带正插在 hi-fi cassette deck 里播放——deck 占下半屏，bay 凹
// 陷咬住卡带底部 34%，两侧有 capstan 转轮同步旋转，红色 PLAY LED 随
// bass 脉动。Cassette 端无缝衔接小图一致的频谱耦合。
//
// Spectrum coupling (both modes):
// - 磁带本身=18 bins waveform（磁带存的就是声波）
// - 每个 hub 外缘 8 颗铜 LED=8 bins（左 hub 低频 / 右 hub 高频）
// - Label hiss 分 3 频段（低点大/中点中/高点细）
// - Big mode only: PLAY LED 随 bass 脉冲，capstan 旋转速度随 bass
//
// Palette (OKLCH → sRGB)：
//   shell     (246, 232, 200)  label     (252, 240, 214)  labelLine (186, 162, 120)
//   window    ( 58,  42,  32)  hub       ( 98,  76,  58)  hubRing   (148, 108,  72)
//   tape      ( 36,  28,  22)  accent    (188, 126,  72)
//   deckMetal ( 62,  66,  74)  deckDark  ( 28,  30,  36)  deckDarker( 12,  14,  18)
//   playLed   (230, 100,  70)  powerLed  ( 90, 180, 230)
struct LofiTapeView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small pose (single cassette), 1 = big pose (cassette in deck).
    /// Smoothly interpolated for the body-to-body morph ImmersiveView drives.
    var expansion: CGFloat = 1.0
    /// v1.4a Signature: draw a VU LED spectrum panel on the deck's empty
    /// metal area. Only visible in big pose (gated by deckAlpha).
    var signatureVU: Bool = false
    /// Signature Evolve drift: scales VU brightness slightly around 1.0.
    var signatureDensityScale: CGFloat = 1.0
    /// Signature Evolve drift: scales VU bar height slightly around 1.0.
    var signatureOmegaScale: CGFloat = 1.0

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderTape(context: context, size: size, binCount: binCount)
        }
    }

    private func renderTape(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let e: CGFloat = max(0, min(1, expansion))
        // Deck scene stays hidden until 30% morph; fully opaque by 88%.
        // Smoothstep gives C1 continuity at both ends so the fade-in never pops.
        let deckAlpha: Double = smoothstep(0.30, 0.88, Double(e))

        let shell     = Color(red: 246/255, green: 232/255, blue: 200/255)
        let label     = Color(red: 252/255, green: 240/255, blue: 214/255)
        let labelLine = Color(red: 186/255, green: 162/255, blue: 120/255)
        let window    = Color(red:  58/255, green:  42/255, blue:  32/255)
        let hub       = Color(red:  98/255, green:  76/255, blue:  58/255)
        let hubRing   = Color(red: 148/255, green: 108/255, blue:  72/255)
        let tape      = Color(red:  36/255, green:  28/255, blue:  22/255)
        let accent    = Color(red: 188/255, green: 126/255, blue:  72/255)
        let deckMetal = Color(red:  62/255, green:  66/255, blue:  74/255)
        let deckDark  = Color(red:  28/255, green:  30/255, blue:  36/255)
        let deckDarker = Color(red: 12/255, green:  14/255, blue:  18/255)
        let playLed   = Color(red: 230/255, green: 100/255, blue:  70/255)
        let powerLed  = Color(red:  90/255, green: 180/255, blue: 230/255)

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

        // 卡带尺寸/位置 — 连续插值：
        // - bodyW: 0.60*w → 0.46*w（小盒子略收紧给 deck 让位）
        // - cy: h*0.50 → h*0.40（上移进 deck bay 位）
        // - tilt: -0.04 → 0（摆正准备插入）
        // 目的：expansion 0→1 时用户看到的是**同一盒卡带**在连续变形，
        // 而不是两个 canvas 的 crossfade。
        let bodyW: CGFloat = w * (0.60 - 0.14 * e)
        let bodyH: CGFloat = bodyW * 0.60
        let cx: CGFloat = w * 0.5
        let cy: CGFloat = h * (0.50 - 0.10 * e)
        let tilt: CGFloat = 0

        // ─── DECK（按 deckAlpha 连续 fade-in；e=0 完全不画）───────
        let deckTopY: CGFloat = h * 0.42

        if deckAlpha > 0.01 {
            // Wrapping the entire deck scene in a drawLayer lets us apply a
            // single opacity multiplier — all gradients, strokes, radial
            // halos, and sub-draws (capstans) fade in lockstep.
            context.drawLayer { ctx in
                ctx.opacity = deckAlpha

                // 顶部暖色 vignette — 模拟桌面灯从上方打
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .radialGradient(
                                Gradient(stops: [
                                    .init(color: Color(red: 52/255, green: 38/255, blue: 28/255).opacity(0.45), location: 0),
                                    .init(color: Color(red: 16/255, green: 14/255, blue: 12/255), location: 0.65),
                                    .init(color: Color(red: 10/255, green: 10/255, blue: 12/255), location: 1)
                                ]),
                                center: CGPoint(x: w * 0.82, y: h * 0.08),
                                startRadius: 0, endRadius: max(w, h) * 1.05
                             ))

                // Deck 主体
                let deckRect = CGRect(x: 0, y: deckTopY, width: w, height: h - deckTopY)
                ctx.fill(Path(deckRect),
                             with: .linearGradient(
                                Gradient(stops: [
                                    .init(color: deckMetal, location: 0),
                                    .init(color: deckDark, location: 0.55),
                                    .init(color: deckDarker, location: 1)
                                ]),
                                startPoint: CGPoint(x: w * 0.5, y: deckTopY),
                                endPoint: CGPoint(x: w * 0.5, y: h)
                             ))

                // 拉丝纹理
                for i in 0..<28 {
                    let ly = deckTopY + 4 + CGFloat(i) * ((h - deckTopY - 8) / 28)
                    var ll = Path()
                    ll.move(to: CGPoint(x: 0, y: ly))
                    ll.addLine(to: CGPoint(x: w, y: ly))
                    ctx.stroke(ll, with: .color(Color.black.opacity(0.10)), lineWidth: 0.3)
                }

                // Deck 顶边高光（白色极细一条）
                var topEdge = Path()
                topEdge.move(to: CGPoint(x: 0, y: deckTopY))
                topEdge.addLine(to: CGPoint(x: w, y: deckTopY))
                ctx.stroke(topEdge, with: .color(Color.white.opacity(0.18)), lineWidth: 0.6)

                // Cassette bay — deck 顶上的凹陷 slot
                let bayW = bodyW * 1.08
                let bayH: CGFloat = h * 0.054
                let bayRect = CGRect(x: cx - bayW / 2, y: deckTopY, width: bayW, height: bayH)
                ctx.fill(Path(roundedRect: bayRect, cornerRadius: 2),
                             with: .color(deckDarker))
                // bay 顶部内阴影
                var bayRim = Path()
                bayRim.move(to: CGPoint(x: bayRect.minX, y: bayRect.minY))
                bayRim.addLine(to: CGPoint(x: bayRect.maxX, y: bayRect.minY))
                ctx.stroke(bayRim, with: .color(Color.black.opacity(0.85)), lineWidth: 1.2)

                // Capstan 转轮（bay 两侧，跟 hub 同步转）
                let omega: Float = 0.35 + Float(bassCG) * 1.1
                let capstanY: CGFloat = bayRect.midY
                let capstanR: CGFloat = bayH * 0.32
                let capstanLeftX: CGFloat = bayRect.minX - capstanR * 1.4
                let capstanRightX: CGFloat = bayRect.maxX + capstanR * 1.4
                drawCapstan(on: ctx, center: CGPoint(x: capstanLeftX, y: capstanY),
                            radius: capstanR, angle: CGFloat(t * omega),
                            metal: deckMetal, dark: deckDark)
                drawCapstan(on: ctx, center: CGPoint(x: capstanRightX, y: capstanY),
                            radius: capstanR, angle: -CGFloat(t * omega),
                            metal: deckMetal, dark: deckDark)

                // Classic-only deck controls (hidden in Signature to give the
                // spectrum window the full lower deck real-estate).
                if !signatureVU {
                    // PLAY LED（红，bass 脉动）
                    let ledRowY: CGFloat = deckTopY + h * 0.11
                    let playX: CGFloat = w * 0.18
                    let playPulse: Double = 0.45 + Double(bassCG) * 0.55
                    let playHalo: CGFloat = 16 + bassCG * 8
                    ctx.fill(Path(ellipseIn: CGRect(
                        x: playX - playHalo, y: ledRowY - playHalo,
                        width: playHalo * 2, height: playHalo * 2
                    )), with: .radialGradient(
                        Gradient(colors: [playLed.opacity(playPulse * 0.55), Color.clear]),
                        center: CGPoint(x: playX, y: ledRowY),
                        startRadius: 0, endRadius: playHalo
                    ))
                    ctx.fill(Path(ellipseIn: CGRect(
                        x: playX - 3.2, y: ledRowY - 3.2, width: 6.4, height: 6.4
                    )), with: .color(playLed.opacity(0.92)))

                    // Power LED（蓝，恒亮小点）
                    let powerX: CGFloat = playX + 18
                    ctx.fill(Path(ellipseIn: CGRect(
                        x: powerX - 9, y: ledRowY - 9, width: 18, height: 18
                    )), with: .radialGradient(
                        Gradient(colors: [powerLed.opacity(0.30), Color.clear]),
                        center: CGPoint(x: powerX, y: ledRowY),
                        startRadius: 0, endRadius: 9
                    ))
                    ctx.fill(Path(ellipseIn: CGRect(
                        x: powerX - 2.2, y: ledRowY - 2.2, width: 4.4, height: 4.4
                    )), with: .color(powerLed.opacity(0.88)))

                    // 右侧：3 个机械按键（PLAY / FF / STOP 圆钮）
                    let btnY: CGFloat = ledRowY
                    let btnR: CGFloat = 7.5
                    let btnGap: CGFloat = 24
                    let btnStartX: CGFloat = w - w * 0.16 - btnGap * 2
                    for i in 0..<3 {
                        let bx = btnStartX + CGFloat(i) * btnGap
                        let outerR: CGFloat = btnR + 2
                        ctx.fill(Path(ellipseIn: CGRect(
                            x: bx - outerR, y: btnY - outerR,
                            width: outerR * 2, height: outerR * 2
                        )), with: .color(deckDarker))
                        ctx.fill(Path(ellipseIn: CGRect(
                            x: bx - btnR, y: btnY - btnR,
                            width: btnR * 2, height: btnR * 2
                        )), with: .radialGradient(
                            Gradient(colors: [deckMetal.opacity(0.95), deckDark]),
                            center: CGPoint(x: bx - 1.5, y: btnY - 2),
                            startRadius: 0, endRadius: btnR
                        ))
                        var hl = Path()
                        hl.addArc(center: CGPoint(x: bx, y: btnY), radius: btnR - 1,
                                  startAngle: .radians(.pi * 1.15),
                                  endAngle: .radians(.pi * 1.85),
                                  clockwise: false)
                        ctx.stroke(hl, with: .color(Color.white.opacity(0.22)), lineWidth: 0.6)
                    }

                    // Tape counter window
                    let counterW: CGFloat = bayW * 0.18
                    let counterH: CGFloat = h * 0.022
                    let counterRect = CGRect(
                        x: cx - counterW / 2,
                        y: deckTopY + bayH + h * 0.025,
                        width: counterW, height: counterH
                    )
                    ctx.fill(Path(roundedRect: counterRect, cornerRadius: 1.5),
                                 with: .color(deckDarker))
                    ctx.stroke(Path(roundedRect: counterRect, cornerRadius: 1.5),
                                   with: .color(Color.black.opacity(0.5)), lineWidth: 0.5)
                    for i in 1..<4 {
                        let sx = counterRect.minX + counterRect.width * CGFloat(i) / 4
                        var sep = Path()
                        sep.move(to: CGPoint(x: sx, y: counterRect.minY + 2))
                        sep.addLine(to: CGPoint(x: sx, y: counterRect.maxY - 2))
                        ctx.stroke(sep, with: .color(Color.white.opacity(0.10)), lineWidth: 0.4)
                    }
                    ctx.draw(
                        Text("0000")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.32)),
                        at: CGPoint(x: counterRect.midX, y: counterRect.midY)
                    )
                }

                // v1.4a Signature: ridge spectrum panel sitting above the title.
                if signatureVU {
                    drawVUPanel(
                        on: ctx,
                        size: size,
                        deckTopY: deckTopY,
                        binCount: binCount,
                        amber: accent,
                        window: deckDarker,
                        t: t
                    )
                }
            }
        }

        // ─── CASSETTE（两种模式都画；大图会自然"插"进 deck bay）─────
        context.drawLayer { layer in
            layer.translateBy(x: cx, y: cy)
            layer.rotate(by: .radians(tilt))

            let halfW = bodyW / 2
            let halfH = bodyH / 2
            let bodyRect = CGRect(x: -halfW, y: -halfH, width: bodyW, height: bodyH)

            // Shell
            layer.fill(Path(roundedRect: bodyRect, cornerRadius: bodyW * 0.025),
                       with: .color(shell))
            // Shell 顶沿高光
            var topHL = Path()
            topHL.move(to: CGPoint(x: -halfW + bodyW * 0.06, y: -halfH + 3))
            topHL.addLine(to: CGPoint(x: halfW - bodyW * 0.06, y: -halfH + 3))
            layer.stroke(topHL, with: .color(Color.white.opacity(0.28)), lineWidth: 0.8)

            // Label
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

            // 写字线
            for i in 0..<3 {
                let lineY = labelRect.minY + labelH * (0.42 + CGFloat(i) * 0.18)
                var line = Path()
                line.move(to: CGPoint(x: labelRect.minX + bodyW * 0.04, y: lineY))
                line.addLine(to: CGPoint(x: labelRect.maxX - bodyW * 0.04, y: lineY))
                layer.stroke(line, with: .color(labelLine.opacity(0.40)), lineWidth: 0.5)
            }

            // 3 频段 hiss
            let zoneH = labelH / 3
            let bandsEnergy: [CGFloat] = [bassCG, midCG, trebCG]
            let bandDotSize: [CGFloat] = [1.4, 0.9, 0.55]
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

            // 磁芯窗口
            let winW = bodyW * 0.74
            let winH = bodyH * 0.30
            let winY = bodyH * 0.08
            let winRect = CGRect(x: -winW / 2, y: winY, width: winW, height: winH)
            layer.fill(Path(roundedRect: winRect, cornerRadius: 3),
                       with: .color(window))
            layer.stroke(Path(roundedRect: winRect, cornerRadius: 3),
                         with: .color(Color.black.opacity(0.4)), lineWidth: 0.6)

            // 磁带 as spectrum waveform
            let hubR: CGFloat = bodyH * 0.12
            let hubSep: CGFloat = winW * 0.30
            let hubYCoord: CGFloat = winY + winH / 2
            let leftHubX: CGFloat = -hubSep
            let rightHubX: CGFloat = hubSep

            let sagBase: CGFloat = winH * 0.10
            let sagSpec: CGFloat = winH * 0.14 * midCG
            let sag: CGFloat = sagBase + sagSpec + CGFloat(sinf(t * 0.7)) * winH * 0.015

            let N = 18
            let tapeStart = CGPoint(x: leftHubX + hubR * 0.55, y: hubYCoord - 0.5)
            let tapeEnd = CGPoint(x: rightHubX - hubR * 0.55, y: hubYCoord - 0.5)
            let tapeLen = tapeEnd.x - tapeStart.x
            let waveAmp: CGFloat = winH * 0.28 * (1 - CGFloat(idleBlend) * 0.7)

            var pts: [CGPoint] = []
            for i in 0..<N {
                let u: CGFloat = CGFloat(i) / CGFloat(N - 1)
                let parab = 4 * u * (1 - u)
                let baseY = hubYCoord + sag * parab
                let binF = Float(i) / Float(N - 1) * Float(binCount - 1)
                let binIdx = min(binCount - 1, max(0, Int(binF)))
                let binVal = CGFloat(spectrumData[binIdx])
                let sign: CGFloat = (i % 2 == 0) ? 1 : -1
                let env = sin(CGFloat.pi * u)
                pts.append(CGPoint(x: tapeStart.x + u * tapeLen,
                                   y: baseY + sign * binVal * waveAmp * env))
            }

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

            // Hubs + rim bins
            let omega: Float = 0.35 + Float(bassCG) * 1.1
            let angleLeft = CGFloat(t * omega)
            let angleRight = -CGFloat(t * omega * 1.03)
            let leftBins: [CGFloat] = (0..<8).map { i in
                CGFloat(spectrumData[min(i, binCount - 1)])
            }
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

            // A/B cap — only shows in big pose; rides the deckAlpha fade so
            // its arrival is synced with the deck scene.
            if deckAlpha > 0.01 {
                layer.drawLayer { sub in
                    sub.opacity = deckAlpha
                    let capRect = CGRect(
                        x: halfW - bodyW * 0.06,
                        y: halfH - bodyH * 0.12,
                        width: bodyW * 0.035,
                        height: bodyH * 0.06
                    )
                    sub.fill(Path(roundedRect: capRect, cornerRadius: 1),
                             with: .color(labelLine.opacity(0.45)))
                }
            }
        }

        // Bay 前嘴唇阴影 — 压在 cassette 底部强化"插入"感，跟 deck 一起淡入
        if deckAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = deckAlpha
                let lipY: CGFloat = cy + bodyH * 0.35
                let lipRect = CGRect(x: cx - bodyW * 0.52, y: lipY,
                                     width: bodyW * 1.04, height: bodyH * 0.12)
                ctx.fill(Path(lipRect),
                             with: .linearGradient(
                                Gradient(stops: [
                                    .init(color: Color.black.opacity(0.00), location: 0),
                                    .init(color: Color.black.opacity(0.75), location: 1)
                                ]),
                                startPoint: CGPoint(x: cx, y: lipRect.minY),
                                endPoint: CGPoint(x: cx, y: lipRect.maxY)
                             ))
            }
        }
    }

    // MARK: - Math helpers

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    // MARK: - Hub

    private func drawHub(on ctx: GraphicsContext, center: CGPoint, radius: CGFloat,
                         angle: CGFloat, hub: Color, ring: Color, accent: Color,
                         rimBins: [CGFloat]) {
        let ringRect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: ringRect), with: .color(ring))

        let innerR = radius * 0.76
        let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR,
                               width: innerR * 2, height: innerR * 2)
        ctx.fill(Path(ellipseIn: innerRect), with: .color(hub))

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

        let rimR: CGFloat = radius * 1.05
        let rimCount = rimBins.count
        for i in 0..<rimCount {
            let a = angle + CGFloat(i) * (.pi * 2 / CGFloat(rimCount))
            let cosA = cos(a), sinA = sin(a)
            let binVal = rimBins[i]
            let distance = rimR + binVal * radius * 0.80
            let dx = center.x + distance * cosA
            let dy = center.y + distance * sinA
            let dotSize: CGFloat = 1.5 + binVal * 2.0
            let dotRect = CGRect(x: dx - dotSize / 2, y: dy - dotSize / 2,
                                 width: dotSize, height: dotSize)
            ctx.fill(Path(ellipseIn: dotRect),
                     with: .color(accent.opacity(0.45 + Double(binVal) * 0.55)))
        }

        let pinR = innerR * 0.14
        let pinRect = CGRect(x: center.x - pinR, y: center.y - pinR,
                             width: pinR * 2, height: pinR * 2)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(ring.opacity(0.95)))
    }

    // MARK: - Ridge Spectrum Panel (v1.4a Signature)
    //
    // A wide dark window sitting above the track title, showing 3 stacked
    // ridgeline layers driven by spectrumData — same "peaks" language used
    // across the house (HorizonView etc). Framed LCD-style window, contrast
    // dialed down so the ridges sit on the deck rather than shout off it.
    private func drawVUPanel(
        on ctx: GraphicsContext,
        size: CGSize,
        deckTopY: CGFloat,
        binCount: Int,
        amber: Color,
        window: Color,
        t: Float
    ) {
        let w = size.width, h = size.height
        let vuRect = CGRect(
            x: w * 0.06,
            y: h * 0.49,
            width: w * 0.88,
            height: h * 0.21
        )

        // Sunken LCD-style window — softened edges so the frame reads as
        // quiet instrumentation rather than a hard-outlined panel.
        let windowPath = Path(roundedRect: vuRect, cornerRadius: 4)
        ctx.fill(windowPath, with: .color(window))
        var innerShadow = Path()
        innerShadow.move(to: CGPoint(x: vuRect.minX + 3, y: vuRect.minY + 1))
        innerShadow.addLine(to: CGPoint(x: vuRect.maxX - 3, y: vuRect.minY + 1))
        ctx.stroke(innerShadow, with: .color(Color.black.opacity(0.45)), lineWidth: 0.6)
        ctx.stroke(windowPath, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)

        // Small mono label — dimmed
        ctx.draw(
            Text("SPECTRUM")
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.16)),
            at: CGPoint(x: vuRect.minX + 32, y: vuRect.minY + 8)
        )

        // Inner drawing region
        let padX: CGFloat = vuRect.width * 0.04
        let padTop: CGFloat = vuRect.height * 0.22
        let padBottom: CGFloat = vuRect.height * 0.08
        let innerX = vuRect.minX + padX
        let innerW = vuRect.width - padX * 2
        let innerTop = vuRect.minY + padTop
        let innerBottom = vuRect.maxY - padBottom
        let innerH = innerBottom - innerTop

        // Warm amber palette (original framed version).
        let amberHot = Color(red: 242/255, green: 168/255, blue: 90/255)
        let copper   = Color(red: 150/255, green:  92/255, blue:  56/255)
        let rust     = Color(red: 102/255, green:  62/255, blue:  38/255)

        let brightScale = max(0.80, min(1.20, Double(signatureDensityScale)))
        let heightScale = max(0.85, min(1.15, Double(signatureOmegaScale)))

        // 3 stacked ridges — contrast lowered vs original (0.85 → 0.55 stroke,
        // 0.05 → 0.03 fill) so the panel hums instead of glows.
        let layers: [(color: Color, baseNorm: CGFloat, ampNorm: CGFloat, binOffset: Int, width: CGFloat)] = [
            (amberHot, 0.86, 0.38, 0,  1.4),
            (copper,   0.72, 0.32, 3,  1.2),
            (rust,     0.58, 0.26, 6,  1.0),
        ]

        let N = 64
        for layer in layers {
            let baseY = innerTop + innerH * layer.baseNorm
            let amp = innerH * layer.ampNorm * CGFloat(heightScale)

            var pts: [CGPoint] = []
            for i in 0...N {
                let u = CGFloat(i) / CGFloat(N)
                let binF = Float(u) * Float(binCount - 1) + Float(layer.binOffset)
                let binIdx = max(0, min(binCount - 1, Int(binF)))
                var v = CGFloat(spectrumData[binIdx])
                let wobble = CGFloat(sinf(t * 0.9 + Float(i) * 0.22 + Float(layer.binOffset))) * 0.04
                v = max(0, min(1, v * 1.2 + wobble))
                let envelope = sin(CGFloat.pi * u)
                let y = baseY - amp * v * envelope
                pts.append(CGPoint(x: innerX + u * innerW, y: y))
            }

            var ridge = Path()
            ridge.move(to: pts[0])
            for i in 1..<pts.count - 1 {
                let mid = CGPoint(x: (pts[i].x + pts[i+1].x) / 2,
                                  y: (pts[i].y + pts[i+1].y) / 2)
                ridge.addQuadCurve(to: mid, control: pts[i])
            }
            ridge.addLine(to: pts.last!)

            var fillPath = ridge
            fillPath.addLine(to: CGPoint(x: innerX + innerW, y: innerBottom))
            fillPath.addLine(to: CGPoint(x: innerX, y: innerBottom))
            fillPath.closeSubpath()
            ctx.fill(fillPath, with: .color(layer.color.opacity(0.03 * brightScale)))

            ctx.stroke(ridge,
                       with: .color(layer.color.opacity(0.55 * brightScale)),
                       lineWidth: layer.width)
        }
    }

    // MARK: - Capstan (deck 上的金属旋轮，6 齿铜圈 + 深灰中心)

    private func drawCapstan(on ctx: GraphicsContext, center: CGPoint, radius: CGFloat,
                             angle: CGFloat, metal: Color, dark: Color) {
        let ringRect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: ringRect), with: .color(metal))

        let innerR = radius * 0.68
        let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR,
                               width: innerR * 2, height: innerR * 2)
        ctx.fill(Path(ellipseIn: innerRect), with: .color(dark))

        for i in 0..<6 {
            let a = angle + CGFloat(i) * .pi / 3
            let cosA = cos(a), sinA = sin(a)
            var spoke = Path()
            spoke.move(to: CGPoint(x: center.x + innerR * 0.3 * cosA,
                                   y: center.y + innerR * 0.3 * sinA))
            spoke.addLine(to: CGPoint(x: center.x + innerR * 0.82 * cosA,
                                      y: center.y + innerR * 0.82 * sinA))
            ctx.stroke(spoke, with: .color(metal.opacity(0.5)), lineWidth: 0.8)
        }

        let pinR = radius * 0.12
        let pinRect = CGRect(x: center.x - pinR, y: center.y - pinR,
                             width: pinR * 2, height: pinR * 2)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(metal))
    }
}

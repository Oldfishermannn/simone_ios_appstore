import SwiftUI

// Favorites visualizer — Firefly Jar.
//
// 小图 (expansion=0): 单个玻璃罐居中，8 只萤火虫在罐内漂。
// 大图 (expansion=1): 主罐缩小右移到窗台，左右各多一只辅罐，窗外雾都 silhouette + 窗台木纹淡入。
//
// Object: 雾蓝夜里的窗台玻璃罐。铜盖 + 冷玻璃壁。每只萤火虫是"被留下的一刻"。
// Spectrum mapping:
//  - 低频 → 萤火虫漂移速度（整体游走）
//  - 中频 → 闪烁呼吸
//  - 高频 → 偶发强闪（flicker 脉冲）
struct FireflyJarView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0

    private struct Jar {
        let cx: CGFloat
        let cyBase: CGFloat
        let width: CGFloat
        let height: CGFloat
        let fireflyCount: Int
        let seed: Double
        let opacity: Double
    }

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

        // Palette（Fog City Nocturne 冷底 + 暖点缀）
        let bg         = Color(red: 20/255,  green: 24/255,  blue: 30/255)
        let fogMid     = Color(red: 30/255,  green: 36/255,  blue: 46/255)
        let citySil    = Color(red: 12/255,  green: 16/255,  blue: 22/255)
        let cityLight  = Color(red: 220/255, green: 180/255, blue: 100/255)
        let sillWood   = Color(red: 42/255,  green: 32/255,  blue: 24/255)
        let sillHL     = Color(red: 84/255,  green: 64/255,  blue: 46/255)
        let glass      = Color(red: 150/255, green: 168/255, blue: 186/255)
        let glassInt   = Color(red: 32/255,  green: 38/255,  blue: 48/255)
        let brass      = Color(red: 188/255, green: 152/255, blue: 96/255)
        let brassDark  = Color(red: 118/255, green: 92/255,  blue: 58/255)
        let emberCore  = Color(red: 252/255, green: 222/255, blue: 124/255)
        let emberHalo  = Color(red: 232/255, green: 160/255, blue: 72/255)

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

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // ── 背景：雾都 silhouette + 窗台（仅大图淡入）──────────
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: fogMid.opacity(0.75), location: 0),
                                .init(color: bg, location: 0.55),
                                .init(color: bg, location: 1)
                            ]),
                            startPoint: CGPoint(x: w * 0.5, y: 0),
                            endPoint: CGPoint(x: w * 0.5, y: h)
                         ))

                // 远处楼 silhouette（阶梯式起伏）
                let skyY = h * 0.54
                var sk = Path()
                sk.move(to: CGPoint(x: 0, y: skyY))
                let heights: [CGFloat] = [0.08, 0.14, 0.06, 0.20, 0.11, 0.18, 0.09, 0.22, 0.13, 0.07, 0.16]
                let segW = w / CGFloat(heights.count)
                for (idx, heightR) in heights.enumerated() {
                    let xStart = CGFloat(idx) * segW
                    let xEnd = CGFloat(idx + 1) * segW
                    sk.addLine(to: CGPoint(x: xStart, y: skyY - h * heightR))
                    sk.addLine(to: CGPoint(x: xEnd, y: skyY - h * heightR))
                }
                sk.addLine(to: CGPoint(x: w, y: skyY))
                sk.closeSubpath()
                ctx.fill(sk, with: .color(citySil.opacity(0.92)))

                // 楼里零星窗口亮点（只放 4-5 个，低调）
                let windowPoints: [(CGFloat, CGFloat, Double)] = [
                    (0.15, 0.44, 0.45),
                    (0.28, 0.48, 0.30),
                    (0.48, 0.42, 0.55),
                    (0.72, 0.46, 0.38),
                    (0.88, 0.40, 0.48)
                ]
                for (rx, ry, a) in windowPoints {
                    let wr = CGRect(x: w * rx - 1.0, y: h * ry - 1.4, width: 2, height: 2.8)
                    ctx.fill(Path(wr), with: .color(cityLight.opacity(a)))
                }

                // 窗台木面（下半高光 + 上沿边缘）
                let sillY = h * 0.74
                let sillRect = CGRect(x: 0, y: sillY, width: w, height: h - sillY)
                ctx.fill(Path(sillRect),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: sillHL.opacity(0.85), location: 0),
                                .init(color: sillWood, location: 0.22),
                                .init(color: sillWood.opacity(0.8), location: 1)
                            ]),
                            startPoint: CGPoint(x: 0, y: sillY),
                            endPoint: CGPoint(x: 0, y: h)
                         ))
                // Woodgrain 拉线
                for i in 0..<9 {
                    let ly = sillY + 3 + CGFloat(i) * ((h - sillY - 6) / 9)
                    var ln = Path()
                    ln.move(to: CGPoint(x: 0, y: ly))
                    ln.addLine(to: CGPoint(x: w, y: ly))
                    ctx.stroke(ln, with: .color(Color.black.opacity(0.10)), lineWidth: 0.3)
                }
                // 上沿一条细高光 — 侧光从右前来
                var topEdge = Path()
                topEdge.move(to: CGPoint(x: 0, y: sillY))
                topEdge.addLine(to: CGPoint(x: w, y: sillY))
                ctx.stroke(topEdge, with: .color(sillHL.opacity(0.9)), lineWidth: 1.2)
            }
        }

        // ── 主罐（连续 morph）────────────────────────────────
        // 小图: cx=0.50, cyBase=0.62, width=0.38, height=0.52
        // 大图: cx=0.64, cyBase=0.80, width=0.22, height=0.32
        let mainJar = Jar(
            cx: 0.50 + (0.64 - 0.50) * e,
            cyBase: 0.62 + (0.80 - 0.62) * e,
            width: 0.38 + (0.22 - 0.38) * e,
            height: 0.52 + (0.32 - 0.52) * e,
            fireflyCount: 8,
            seed: 0.0,
            opacity: 1.0
        )
        drawJar(context: context, w: w, h: h, jar: mainJar,
                glass: glass, glassInt: glassInt, brass: brass, brassDark: brassDark,
                emberCore: emberCore, emberHalo: emberHalo,
                spectrum: spectrumData, binCount: binCount,
                bass: bass, mid: mid, treble: treble,
                idleBlend: idleBlend, t: t)

        // ── 辅罐（大图淡入）────────────────────────────────
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                let leftJar = Jar(cx: 0.22, cyBase: 0.78, width: 0.16, height: 0.26,
                                  fireflyCount: 4, seed: 3.14, opacity: 0.85)
                let leftFrontJar = Jar(cx: 0.40, cyBase: 0.82, width: 0.12, height: 0.20,
                                       fireflyCount: 3, seed: 5.71, opacity: 0.78)
                drawJar(context: ctx, w: w, h: h, jar: leftJar,
                        glass: glass, glassInt: glassInt, brass: brass, brassDark: brassDark,
                        emberCore: emberCore, emberHalo: emberHalo,
                        spectrum: spectrumData, binCount: binCount,
                        bass: bass, mid: mid, treble: treble,
                        idleBlend: idleBlend, t: t)
                drawJar(context: ctx, w: w, h: h, jar: leftFrontJar,
                        glass: glass, glassInt: glassInt, brass: brass, brassDark: brassDark,
                        emberCore: emberCore, emberHalo: emberHalo,
                        spectrum: spectrumData, binCount: binCount,
                        bass: bass, mid: mid, treble: treble,
                        idleBlend: idleBlend, t: t)
            }
        }
    }

    private func drawJar(context: GraphicsContext, w: CGFloat, h: CGFloat, jar j: Jar,
                         glass: Color, glassInt: Color, brass: Color, brassDark: Color,
                         emberCore: Color, emberHalo: Color,
                         spectrum: [Float], binCount: Int,
                         bass: Float, mid: Float, treble: Float,
                         idleBlend: Float, t: Float) {
        let cx = j.cx * w
        let cyBase = j.cyBase * h
        let jw = j.width * w
        let jh = j.height * h

        let bodyTop = cyBase - jh
        let bodyBot = cyBase
        let lidH = jh * 0.15
        let shoulder = lidH * 0.7

        // 玻璃罐 body path (rounded rect with subtle shoulder taper)
        var glassBody = Path()
        glassBody.move(to: CGPoint(x: cx - jw * 0.48, y: bodyBot))
        glassBody.addLine(to: CGPoint(x: cx - jw * 0.48, y: bodyTop + lidH + shoulder))
        glassBody.addQuadCurve(
            to: CGPoint(x: cx - jw * 0.44, y: bodyTop + lidH),
            control: CGPoint(x: cx - jw * 0.48, y: bodyTop + lidH)
        )
        glassBody.addLine(to: CGPoint(x: cx + jw * 0.44, y: bodyTop + lidH))
        glassBody.addQuadCurve(
            to: CGPoint(x: cx + jw * 0.48, y: bodyTop + lidH + shoulder),
            control: CGPoint(x: cx + jw * 0.48, y: bodyTop + lidH)
        )
        glassBody.addLine(to: CGPoint(x: cx + jw * 0.48, y: bodyBot))
        glassBody.closeSubpath()

        // 罐内深色（冷玻璃内部）
        context.fill(glassBody,
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: glassInt.opacity(0.55 * j.opacity), location: 0),
                            .init(color: glassInt.opacity(0.85 * j.opacity), location: 1)
                        ]),
                        startPoint: CGPoint(x: cx, y: bodyTop),
                        endPoint: CGPoint(x: cx, y: bodyBot)
                     ))

        // 罐壁边缘高光（右侧，侧光来源）
        context.stroke(glassBody, with: .color(glass.opacity(0.32 * j.opacity)), lineWidth: 1.0)

        // 左侧竖向高光（反射条）
        var leftHL = Path()
        leftHL.move(to: CGPoint(x: cx - jw * 0.34, y: bodyTop + lidH + jh * 0.12))
        leftHL.addLine(to: CGPoint(x: cx - jw * 0.34, y: bodyBot - jh * 0.12))
        context.stroke(leftHL, with: .color(glass.opacity(0.20 * j.opacity)), lineWidth: 0.7)

        // 底部暗影（收口）
        var bottomEdge = Path()
        bottomEdge.move(to: CGPoint(x: cx - jw * 0.46, y: bodyBot))
        bottomEdge.addLine(to: CGPoint(x: cx + jw * 0.46, y: bodyBot))
        context.stroke(bottomEdge, with: .color(Color.black.opacity(0.55 * j.opacity)), lineWidth: 1.4)

        // 铜盖
        let lidRect = CGRect(x: cx - jw * 0.50, y: bodyTop,
                             width: jw, height: lidH)
        context.fill(Path(roundedRect: lidRect, cornerRadius: lidH * 0.28),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: brass.opacity(0.95 * j.opacity), location: 0),
                            .init(color: brassDark.opacity(0.92 * j.opacity), location: 1)
                        ]),
                        startPoint: CGPoint(x: cx, y: lidRect.minY),
                        endPoint: CGPoint(x: cx, y: lidRect.maxY)
                     ))
        // Lid 侧环刻线
        let rimY = bodyTop + lidH * 0.62
        var rim = Path()
        rim.move(to: CGPoint(x: cx - jw * 0.46, y: rimY))
        rim.addLine(to: CGPoint(x: cx + jw * 0.46, y: rimY))
        context.stroke(rim, with: .color(brassDark.opacity(0.75 * j.opacity)), lineWidth: 0.8)
        // Lid 顶高光（极细）
        var lidHL = Path()
        lidHL.move(to: CGPoint(x: cx - jw * 0.40, y: bodyTop + 1.5))
        lidHL.addLine(to: CGPoint(x: cx + jw * 0.40, y: bodyTop + 1.5))
        context.stroke(lidHL, with: .color(Color.white.opacity(0.22 * j.opacity)), lineWidth: 0.6)

        // ── 萤火虫 ────────────────────────────────
        let interiorTop = bodyTop + lidH + jh * 0.06
        let interiorBot = bodyBot - jh * 0.06
        let interiorW = jw * 0.78
        let interiorH = interiorBot - interiorTop

        let bassDrive = Double(bass * (1 - idleBlend) + 0.15 * idleBlend)
        let midDrive = Double(mid * (1 - idleBlend) + 0.15 * idleBlend)
        let trebleDrive = Double(treble * (1 - idleBlend))

        for i in 0..<j.fireflyCount {
            let s = j.seed + Double(i) * 7.919

            // 慢速游走 — 低频推动
            let walkT = Double(t) * (0.12 + bassDrive * 0.40) + s
            let drx = sin(walkT * 0.6 + s * 1.3)
            let dry = sin(walkT * 0.82 + s * 2.1)
            let px = cx + CGFloat(drx) * interiorW * 0.44
            let py = interiorTop + interiorH * 0.5 + CGFloat(dry) * interiorH * 0.40

            // 每只萤火虫绑到一个 bin（让"每只=一份收藏"的映射成立）
            let binSeed = sin(s * 19.3) - floor(sin(s * 19.3))
            let binIdx = min(binCount - 1, max(0, Int(binSeed * Double(binCount - 1))))
            let binVal = CGFloat(spectrum[binIdx])

            // 亮度 = 基础呼吸(中频) + bin 能量 + 偶发强闪(高频)
            let breathe = 0.30 + 0.30 * sin(Double(t) * (1.15 + midDrive * 1.6) + s * 2.7)
            let flicker = pow(max(0, sin(Double(t) * 3.8 + s * 5.1)), 10) * trebleDrive * 1.8
            let brightness = min(1.0, max(0.08,
                breathe + flicker + Double(binVal) * 0.55
            ))

            let coreR: CGFloat = 1.3 + CGFloat(brightness) * 1.8
            let haloR: CGFloat = coreR * 5.5

            // Halo
            let haloRect = CGRect(x: px - haloR, y: py - haloR,
                                  width: haloR * 2, height: haloR * 2)
            context.fill(Path(ellipseIn: haloRect),
                         with: .radialGradient(
                            Gradient(colors: [
                                emberHalo.opacity(brightness * 0.55 * j.opacity),
                                emberHalo.opacity(0)
                            ]),
                            center: CGPoint(x: px, y: py),
                            startRadius: 0, endRadius: haloR
                         ))
            // Core
            let coreRect = CGRect(x: px - coreR, y: py - coreR,
                                  width: coreR * 2, height: coreR * 2)
            context.fill(Path(ellipseIn: coreRect),
                         with: .color(emberCore.opacity(min(1.0, brightness + 0.1) * j.opacity)))
        }
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

import SwiftUI

// Favorites visualizer — Night Window (fog city apartment window).
//
// 小图 (expansion=0): 单扇竖条分格窗居中，窗内暖橘灯光，玻璃上雨痕随音乐延伸。
// 大图 (expansion=1): 镜头拉远，三扇窗并排嵌在砖墙里，窗内颜色各异（冷/暖/灰），
//                     窗外隐约远景楼宇 silhouette + 街灯 bokeh。
//
// Object: Fog City 夜晚雾气里的公寓窗。黄铜窗框竖条 mullion，玻璃带雨痕，
//         窗台上有一支蜡烛。每道雨痕是一条"被听见的情绪"。
// Spectrum mapping:
//   - 低频 → 雨滴下落速度 + 窗内灯光呼吸
//   - 中频 → 雾浓度 + 蜡烛火苗晃动
//   - 高频 → 雨滴水平漂移 + 窗内灯光闪烁
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

        // Palette — 雾都夜
        let skyDark     = Color(red: 10/255,  green: 14/255,  blue: 22/255)
        let skyMid      = Color(red: 20/255,  green: 26/255,  blue: 38/255)
        let fogTone     = Color(red: 60/255,  green: 68/255,  blue: 88/255)
        let brickDark   = Color(red: 36/255,  green: 28/255,  blue: 26/255)
        let brickMid    = Color(red: 58/255,  green: 42/255,  blue: 36/255)
        let brickHL     = Color(red: 84/255,  green: 60/255,  blue: 48/255)
        let mortar      = Color(red: 22/255,  green: 18/255,  blue: 18/255)
        let mullion     = Color(red: 36/255,  green: 28/255,  blue: 20/255)
        let mullionHL   = Color(red: 82/255,  green: 64/255,  blue: 40/255)
        let glassCold   = Color(red: 40/255,  green: 52/255,  blue: 76/255)
        let warmLamp    = Color(red: 228/255, green: 176/255, blue: 108/255)
        let coolLamp    = Color(red: 146/255, green: 178/255, blue: 206/255)
        let greyLamp    = Color(red: 160/255, green: 160/255, blue: 164/255)
        let candleFlame = Color(red: 248/255, green: 196/255, blue: 120/255)

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

        // ── 背景：夜空 + 远处城市雾
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: skyDark, location: 0),
                            .init(color: skyMid,  location: 0.65),
                            .init(color: brickDark, location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                     ))

        // ── 大图：砖墙 + 远景楼宇 + 雾气
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                // 砖墙（左右）
                drawBrickWall(ctx: ctx, rect: CGRect(x: 0, y: h * 0.12,
                                                      width: w, height: h * 0.76),
                              brickDark: brickDark, brickMid: brickMid,
                              brickHL: brickHL, mortar: mortar)
                // 远景楼宇 silhouette（稍微透出）
                var cityPath = Path()
                cityPath.move(to: CGPoint(x: 0, y: h * 0.58))
                var cursor: CGFloat = 0
                while cursor < w {
                    let bw = CGFloat(36 + Int(sin(Double(cursor)) * 20 + 20))
                    let bh = CGFloat(35 + Int(cos(Double(cursor) * 0.7) * 25 + 28))
                    cityPath.addLine(to: CGPoint(x: cursor, y: h * 0.58 - bh))
                    cityPath.addLine(to: CGPoint(x: cursor + bw, y: h * 0.58 - bh))
                    cursor += bw
                }
                cityPath.addLine(to: CGPoint(x: w, y: h * 0.58))
                cityPath.closeSubpath()
                ctx.fill(cityPath, with: .color(skyDark.opacity(0.8)))
                // 远楼零星窗灯
                for i in 0..<18 {
                    let s = Double(i) * 7.13
                    let lx = CGFloat(s.truncatingRemainder(dividingBy: 1.0)) * w
                    let ly = h * 0.50 + CGFloat((cos(s * 1.3) * 0.5 + 0.5)) * h * 0.08
                    let lr: CGFloat = 1.1
                    ctx.fill(Path(ellipseIn: CGRect(x: lx, y: ly, width: lr * 2, height: lr * 2)),
                             with: .color(warmLamp.opacity(0.55)))
                }
                // 雾气 band
                let fogAlpha = 0.25 + Double(midCG) * 0.35
                ctx.fill(Path(CGRect(x: 0, y: h * 0.52, width: w, height: h * 0.18)),
                         with: .linearGradient(
                            Gradient(colors: [
                                fogTone.opacity(0),
                                fogTone.opacity(fogAlpha),
                                fogTone.opacity(0)
                            ]),
                            startPoint: CGPoint(x: 0, y: h * 0.52),
                            endPoint: CGPoint(x: 0, y: h * 0.70)
                         ))
            }
        }

        // ── 窗户几何
        // 小图：单扇居中大窗（0.62w × 0.70h）
        // 大图：三扇并排，每扇 0.24w × 0.42h
        struct WindowFrame { let rect: CGRect; let lampColor: Color; let scale: CGFloat }
        var windows: [WindowFrame] = []

        // 主窗目标（两种 pose）
        let smallRect = CGRect(x: w * 0.19, y: h * 0.15,
                                width: w * 0.62, height: h * 0.70)
        let bigMainRect = CGRect(x: w * 0.38, y: h * 0.28,
                                  width: w * 0.24, height: h * 0.42)
        let mainRect = CGRect(
            x: smallRect.minX + (bigMainRect.minX - smallRect.minX) * e,
            y: smallRect.minY + (bigMainRect.minY - smallRect.minY) * e,
            width: smallRect.width + (bigMainRect.width - smallRect.width) * e,
            height: smallRect.height + (bigMainRect.height - smallRect.height) * e
        )
        windows.append(WindowFrame(rect: mainRect, lampColor: warmLamp, scale: 1.0))

        // 左/右邻窗（大图才出现）
        if sceneAlpha > 0.01 {
            let leftRect = CGRect(x: w * 0.08, y: h * 0.30,
                                   width: w * 0.22, height: h * 0.38)
            let rightRect = CGRect(x: w * 0.70, y: h * 0.30,
                                    width: w * 0.22, height: h * 0.38)
            windows.append(WindowFrame(rect: leftRect, lampColor: coolLamp, scale: 0.85))
            windows.append(WindowFrame(rect: rightRect, lampColor: greyLamp, scale: 0.82))
        }

        // 绘制所有窗（邻窗淡入）
        for (idx, win) in windows.enumerated() {
            let alpha: Double = idx == 0 ? 1.0 : sceneAlpha
            context.drawLayer { ctx in
                ctx.opacity = alpha
                drawWindow(ctx: ctx, frame: win.rect, lampColor: win.lampColor,
                           scale: win.scale,
                           mullion: mullion, mullionHL: mullionHL,
                           glassCold: glassCold, warmLamp: warmLamp,
                           bassCG: bassCG, midCG: midCG, trebleCG: trebleCG,
                           t: t, isMain: idx == 0,
                           spectrumData: spectrumData)
            }
        }

        // ── 主窗下方窗台 + 蜡烛
        // 窗台（伸出窗下一小块）
        let sillH: CGFloat = 8 + 4 * (1 - e)
        let sillRect = CGRect(x: mainRect.minX - 6, y: mainRect.maxY,
                               width: mainRect.width + 12, height: sillH)
        context.fill(Path(sillRect),
                     with: .linearGradient(
                        Gradient(colors: [mullionHL, mullion]),
                        startPoint: CGPoint(x: 0, y: sillRect.minY),
                        endPoint: CGPoint(x: 0, y: sillRect.maxY)
                     ))
        // 窗台投影
        var sillSh = Path()
        sillSh.move(to: CGPoint(x: sillRect.minX + 2, y: sillRect.maxY + 1.5))
        sillSh.addLine(to: CGPoint(x: sillRect.maxX - 2, y: sillRect.maxY + 1.5))
        context.stroke(sillSh, with: .color(Color.black.opacity(0.55)), lineWidth: 0.8)

        // 蜡烛（窗台左侧，火苗随 mid 颤抖）
        let candleX = mainRect.minX + mainRect.width * 0.18
        let candleBaseY = sillRect.minY
        let candleH: CGFloat = 14 + 6 * (1 - e)
        let candleW: CGFloat = 5
        let candleRect = CGRect(x: candleX - candleW / 2, y: candleBaseY - candleH,
                                 width: candleW, height: candleH)
        context.fill(Path(candleRect),
                     with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 230/255, green: 220/255, blue: 200/255),
                            Color(red: 180/255, green: 160/255, blue: 130/255)
                        ]),
                        startPoint: CGPoint(x: candleRect.minX, y: candleRect.minY),
                        endPoint: CGPoint(x: candleRect.maxX, y: candleRect.maxY)
                     ))
        // 火苗（跳动）
        let flameJitter = CGFloat(sin(Double(t) * 6)) * (0.5 + midCG * 2.5)
        let flameH: CGFloat = 8 + midCG * 6
        let flameW: CGFloat = 4 + midCG * 1.5
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
        // 火苗光晕
        let glowR: CGFloat = 18 + midCG * 14
        context.fill(Path(ellipseIn: CGRect(x: flameCX - glowR, y: flameCY - glowR,
                                             width: glowR * 2, height: glowR * 2)),
                     with: .radialGradient(
                        Gradient(colors: [
                            warmLamp.opacity(0.35),
                            warmLamp.opacity(0)
                        ]),
                        center: CGPoint(x: flameCX, y: flameCY),
                        startRadius: 0, endRadius: glowR
                     ))
    }

    // MARK: - Window

    private func drawWindow(ctx: GraphicsContext, frame: CGRect, lampColor: Color,
                             scale: CGFloat,
                             mullion: Color, mullionHL: Color,
                             glassCold: Color, warmLamp: Color,
                             bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat,
                             t: Float, isMain: Bool,
                             spectrumData: [Float]) {
        // 窗框外圈
        let frameOuter = frame.insetBy(dx: -3 * scale, dy: -3 * scale)
        ctx.fill(Path(roundedRect: frameOuter, cornerRadius: 2),
                 with: .linearGradient(
                    Gradient(colors: [mullionHL, mullion]),
                    startPoint: CGPoint(x: frameOuter.minX, y: frameOuter.minY),
                    endPoint: CGPoint(x: frameOuter.maxX, y: frameOuter.maxY)
                 ))

        // 玻璃底色（冷蓝）+ 室内暖光（从里向外渗）
        let lampIntensity = 0.55 + Double(bassCG) * 0.35 + Double(sin(Double(t) * 2.1)) * 0.04
        ctx.fill(Path(frame),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: lampColor.opacity(lampIntensity),   location: 0),
                        .init(color: lampColor.opacity(lampIntensity * 0.45), location: 0.55),
                        .init(color: glassCold.opacity(0.85),             location: 1)
                    ]),
                    center: CGPoint(x: frame.midX, y: frame.midY + frame.height * 0.12),
                    startRadius: 0, endRadius: max(frame.width, frame.height) * 0.75
                 ))

        // 玻璃的斜冷反光（对角线 sheen）
        var sheen = Path()
        sheen.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * 0.2))
        sheen.addLine(to: CGPoint(x: frame.minX + frame.width * 0.35, y: frame.minY))
        sheen.addLine(to: CGPoint(x: frame.minX + frame.width * 0.55, y: frame.minY))
        sheen.addLine(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * 0.5))
        sheen.closeSubpath()
        ctx.fill(sheen, with: .color(Color.white.opacity(0.06)))

        // 室内剪影（一张椅子 + 一盏台灯，仅主窗可见）
        if isMain {
            let interiorAlpha = 0.42 + Double(bassCG) * 0.25
            // 椅背
            let chairBackRect = CGRect(x: frame.minX + frame.width * 0.55,
                                         y: frame.minY + frame.height * 0.40,
                                         width: frame.width * 0.18,
                                         height: frame.height * 0.38)
            ctx.fill(Path(roundedRect: chairBackRect, cornerRadius: 2),
                     with: .color(Color.black.opacity(interiorAlpha)))
            // 台灯杆 + 灯罩
            let lampX = frame.minX + frame.width * 0.22
            let lampBaseY = frame.minY + frame.height * 0.72
            var lampPole = Path()
            lampPole.move(to: CGPoint(x: lampX, y: lampBaseY))
            lampPole.addLine(to: CGPoint(x: lampX, y: lampBaseY - frame.height * 0.32))
            ctx.stroke(lampPole, with: .color(Color.black.opacity(interiorAlpha)),
                       lineWidth: 1.6)
            // 灯罩三角
            let shadeW: CGFloat = frame.width * 0.14
            let shadeH: CGFloat = frame.height * 0.10
            var shade = Path()
            shade.move(to: CGPoint(x: lampX - shadeW / 2,
                                    y: lampBaseY - frame.height * 0.32))
            shade.addLine(to: CGPoint(x: lampX + shadeW / 2,
                                       y: lampBaseY - frame.height * 0.32))
            shade.addLine(to: CGPoint(x: lampX + shadeW * 0.32,
                                       y: lampBaseY - frame.height * 0.32 - shadeH))
            shade.addLine(to: CGPoint(x: lampX - shadeW * 0.32,
                                       y: lampBaseY - frame.height * 0.32 - shadeH))
            shade.closeSubpath()
            ctx.fill(shade, with: .color(Color.black.opacity(interiorAlpha)))
            // 灯泡（暖）
            let bulbR: CGFloat = 3
            let bulbY = lampBaseY - frame.height * 0.30
            ctx.fill(Path(ellipseIn: CGRect(x: lampX - bulbR, y: bulbY - bulbR,
                                             width: bulbR * 2, height: bulbR * 2)),
                     with: .color(warmLamp.opacity(0.9)))
        }

        // 窗格 mullion：2 cols x 3 rows（竖 3 条，横 2 条）
        let colsW: CGFloat = 1.8 * scale
        for c in 1..<2 {
            let mx = frame.minX + frame.width * CGFloat(c) / 2
            let mr = CGRect(x: mx - colsW / 2, y: frame.minY,
                             width: colsW, height: frame.height)
            ctx.fill(Path(mr), with: .color(mullion))
            var hl = Path()
            hl.move(to: CGPoint(x: mr.minX + 0.3, y: mr.minY + 2))
            hl.addLine(to: CGPoint(x: mr.minX + 0.3, y: mr.maxY - 2))
            ctx.stroke(hl, with: .color(mullionHL.opacity(0.55)), lineWidth: 0.4)
        }
        for r in 1..<3 {
            let my = frame.minY + frame.height * CGFloat(r) / 3
            let mr = CGRect(x: frame.minX, y: my - colsW / 2,
                             width: frame.width, height: colsW)
            ctx.fill(Path(mr), with: .color(mullion))
            var hl = Path()
            hl.move(to: CGPoint(x: mr.minX + 2, y: mr.minY + 0.3))
            hl.addLine(to: CGPoint(x: mr.maxX - 2, y: mr.minY + 0.3))
            ctx.stroke(hl, with: .color(mullionHL.opacity(0.55)), lineWidth: 0.4)
        }

        // 雨痕 —— 签名动效：每条雨痕的长度 = 对应频谱 bin 的强度
        // 主窗用较多条（32），邻窗用较少（16）简化
        let rainCount = isMain ? min(32, spectrumData.count) : 12
        for i in 0..<rainCount {
            // 横向分布（稳定 seed）
            let s = Double(i) * 9.71 + (isMain ? 0 : 37.2)
            let xRand = s.truncatingRemainder(dividingBy: 1.0)
            let xJ = CGFloat(sin(Double(t) * 0.12 + s * 2)) * 0.5 + 0.5
            let x = frame.minX + (CGFloat(xRand) * 0.85 + CGFloat(xJ) * 0.12) * frame.width

            // bin 强度
            let binIdx = Int(Double(i) * Double(spectrumData.count) / Double(rainCount))
                .clamped(to: 0...(spectrumData.count - 1))
            let bin = spectrumData[binIdx]
            let magnitude = CGFloat(bin) * (1 - CGFloat(idleBlend(spectrumData)))
                           + 0.08 * CGFloat(idleBlend(spectrumData))

            // 雨痕长度 = 5 + magnitude * 雨痕最大长度
            let maxLen = frame.height * 0.38
            let streakLen = 4 + magnitude * maxLen

            // 下滑速度 = bass
            let fallSpeed = 0.15 + Double(bassCG) * 1.4
            let yCycle = (Double(t) * fallSpeed + s * 3.3).truncatingRemainder(dividingBy: 1.0)
            let y0 = frame.minY + CGFloat(yCycle) * frame.height

            // 横向漂移（treble）
            let drift = CGFloat(sin(Double(t) * 1.7 + s)) * trebleCG * 6

            // 雨痕是斜线（稍微倾斜）
            var streak = Path()
            streak.move(to: CGPoint(x: x + drift, y: y0))
            streak.addLine(to: CGPoint(x: x + drift - 1.2, y: y0 + streakLen))
            let alpha = 0.25 + Double(magnitude) * 0.55
            ctx.stroke(streak,
                       with: .color(Color.white.opacity(alpha * (isMain ? 0.85 : 0.55))),
                       lineWidth: isMain ? 0.9 : 0.6)

            // 水珠（落到下沿时）
            if yCycle > 0.92 && isMain {
                let drop = CGRect(x: x + drift - 1.2, y: y0 + streakLen - 1,
                                    width: 2.4, height: 2.4)
                ctx.fill(Path(ellipseIn: drop),
                         with: .color(Color.white.opacity(alpha * 0.9)))
            }
        }

        // 窗框内缘暗阴影
        var innerShadow = Path()
        innerShadow.addRect(frame)
        ctx.stroke(innerShadow, with: .color(Color.black.opacity(0.55)),
                   lineWidth: 1.0)
    }

    private func idleBlend(_ spectrumData: [Float]) -> Float {
        let maxValue = spectrumData.max() ?? 0
        return max(Float(0), 1 - maxValue * 4)
    }

    // MARK: - Brick wall

    private func drawBrickWall(ctx: GraphicsContext, rect: CGRect,
                                brickDark: Color, brickMid: Color,
                                brickHL: Color, mortar: Color) {
        // 砖高 + 灰缝
        let brickH: CGFloat = 14
        let mortarH: CGFloat = 2
        let brickW: CGFloat = 32
        var row = 0
        var y = rect.minY
        // 底色灰缝
        ctx.fill(Path(rect), with: .color(mortar))
        while y < rect.maxY {
            let offset: CGFloat = (row % 2 == 0) ? 0 : brickW / 2
            var x = rect.minX - offset
            while x < rect.maxX {
                let br = CGRect(x: x, y: y, width: brickW - mortarH, height: brickH)
                // 伪随机选色
                let seed = Int((x + y).truncatingRemainder(dividingBy: 97))
                let tone: Color = (seed % 3 == 0) ? brickHL
                                  : (seed % 2 == 0) ? brickMid : brickDark
                if br.intersects(rect) {
                    ctx.fill(Path(br), with: .color(tone))
                }
                x += brickW
            }
            row += 1
            y += brickH + mortarH
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

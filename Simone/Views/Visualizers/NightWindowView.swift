import SwiftUI

// Favorites visualizer — Night Window.
//
// 小图 (expansion≈0): 单扇窗大特写，玻璃占画面 60%+，mullion 十字，雨痕滑下。
// 大图 (expansion=1): 三套方案评审中 — glass / room / street，由 AppState.nightWindowBigStyle 决定。
//   - glass  :「Depth Through Glass」  — 窗仍占满，玻璃变透明，后面透出雨夜街灯+雾中远楼
//   - room   :「The Room Behind You」  — 窗缩到中上，前景桌面/台灯/蒸汽剪影，有"坐在屋里"感
//   - street :「Seen From The Street」  — 窗缩到中上偏仰，前景湿地面 4 格倒影+墙面
//
// Impeccable 原则落实（三套共同）：
//   - 物件感：窗是一件真物；三套大图都建立"场所"，不是图表
//   - 侧光：每套都有明确单侧主光（冷月光束 / 暖桌灯 / 窗光本身）
//   - 动而非跳：雨丝/蒸汽/倒影 bezier，幅度克制
//   - 60-30-10：冷底占主导，暖点克制，第三色只在少数元素
//   - 延续感：大图不和小图断裂——小图「看着这扇窗」，大图是"继续看/退后看/回头看"

enum NightWindowBigStyle: String, CaseIterable {
    case glass, room, street

    static let userDefaultsKey = "nightWindowBigStyle"

    static var preference: NightWindowBigStyle {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey)
            ?? NightWindowBigStyle.glass.rawValue
        return NightWindowBigStyle(rawValue: raw) ?? .glass
    }

    var displayName: String {
        switch self {
        case .glass:  return "Glass"
        case .room:   return "Room"
        case .street: return "Street"
        }
    }
}

struct NightWindowView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0
    var bigStyle: NightWindowBigStyle = .glass

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

        // ── Palette (Fog City Nocturne)
        let nightDeep     = Color(red: 10/255,  green: 12/255,  blue: 20/255)
        let nightMid      = Color(red: 18/255,  green: 22/255,  blue: 34/255)
        let fogTint       = Color(red: 44/255,  green: 54/255,  blue: 76/255)
        let cityFar       = Color(red: 18/255,  green: 22/255,  blue: 32/255)
        let cityNear      = Color(red: 30/255,  green: 36/255,  blue: 48/255)
        let mullion       = Color(red: 32/255,  green: 26/255,  blue: 22/255)
        let mullionHL     = Color(red: 78/255,  green: 62/255,  blue: 42/255)
        let glassCold     = Color(red: 36/255,  green: 48/255,  blue: 72/255)
        let glassCoolHL   = Color(red: 180/255, green: 196/255, blue: 220/255)
        let warmLamp      = Color(red: 232/255, green: 178/255, blue: 108/255)
        let candleFlame   = Color(red: 250/255, green: 200/255, blue: 122/255)
        let moonBeam      = Color(red: 196/255, green: 210/255, blue: 228/255)
        let streetAmber   = Color(red: 246/255, green: 158/255, blue: 82/255)
        let woodDark      = Color(red: 38/255,  green: 28/255,  blue: 20/255)
        let woodMid       = Color(red: 66/255,  green: 48/255,  blue: 34/255)
        let wallDim       = Color(red: 26/255,  green: 28/255,  blue: 36/255)

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

        // ── 背景（通用冷夜渐变，room 方案会被前景桌面盖掉大部分）
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

        // ── 大图背景（在主窗之后/之前绘制取决于方案）
        //    glass  : 先画背景（透过玻璃看到）→ 再画主窗（半透明玻璃）
        //    room   : 只画窗外夜景（很淡）→ 主窗 → 前景桌面+灯（盖住窗下半部分）
        //    street : 墙面+地砖基底 → 主窗（居中上仰角）→ 地砖上的窗光倒影
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                switch bigStyle {
                case .glass:
                    drawGlassBG(ctx: ctx, w: w, h: h,
                                  cityFar: cityFar, cityNear: cityNear, fogTint: fogTint,
                                  streetAmber: streetAmber, glassCoolHL: glassCoolHL,
                                  t: t, bassCG: bassCG, midCG: midCG, trebleCG: trebleCG)
                case .room:
                    drawRoomBG(ctx: ctx, w: w, h: h,
                                 glassCoolHL: glassCoolHL,
                                 t: t, trebleCG: trebleCG, midCG: midCG)
                case .street:
                    drawStreetBG(ctx: ctx, w: w, h: h,
                                   wallDim: wallDim, fogTint: fogTint,
                                   t: t, midCG: midCG)
                }
            }
        }

        // ── 主窗矩形 —— 三套方案位置/尺寸不同
        let mainSmall = CGRect(x: w * 0.18, y: h * 0.16,
                                width: w * 0.64, height: h * 0.68)
        let mainTarget = mainTargetRect(for: bigStyle, w: w, h: h)
        let mainRect = CGRect(
            x: mainSmall.minX + (mainTarget.minX - mainSmall.minX) * e,
            y: mainSmall.minY + (mainTarget.minY - mainSmall.minY) * e,
            width: mainSmall.width + (mainTarget.width - mainSmall.width) * e,
            height: mainSmall.height + (mainTarget.height - mainSmall.height) * e
        )

        // ── 主窗绘制
        //    glass 方案：玻璃大图时变透明（glassTransparency 从 0 → 0.6），让 BG 透出
        let glassTransparency: Double = {
            if bigStyle == .glass { return 0.60 * sceneAlpha }
            return 0
        }()
        context.drawLayer { ctx in
            drawWindow(
                ctx: ctx, frame: mainRect, lampColor: warmLamp,
                mullion: mullion, mullionHL: mullionHL,
                glassCold: glassCold, glassCoolHL: glassCoolHL,
                warmLamp: warmLamp, candleFlame: candleFlame,
                bassCG: bassCG, midCG: midCG, trebleCG: trebleCG,
                t: t, isMain: true,
                spectrumData: spectrumData,
                sceneAlpha: sceneAlpha,
                glassTransparency: glassTransparency
            )
        }

        // ── 大图前景（仅 room/street 有）
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                switch bigStyle {
                case .glass:
                    break  // 玻璃反光已在 drawWindow 内处理
                case .room:
                    drawRoomFG(ctx: ctx, w: w, h: h,
                                 windowRect: mainRect,
                                 woodDark: woodDark, woodMid: woodMid,
                                 warmLamp: warmLamp, candleFlame: candleFlame,
                                 t: t, bassCG: bassCG, midCG: midCG)
                case .street:
                    drawStreetFG(ctx: ctx, w: w, h: h,
                                   windowRect: mainRect,
                                   warmLamp: warmLamp, glassCoolHL: glassCoolHL,
                                   t: t, bassCG: bassCG, midCG: midCG, trebleCG: trebleCG)
                }
            }
        }

        // ── 左上斜冷光束（主光方向，所有方案保留，但 room 模式下淡化——桌灯才是主光）
        let beamBoost = (bigStyle == .room) ? 0.3 : 1.0
        let beamIntensity = (0.12 + Double(bassCG) * 0.22 + sceneAlpha * 0.06) * beamBoost
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

    // MARK: - Main window target rect per big style

    private func mainTargetRect(for style: NightWindowBigStyle,
                                 w: CGFloat, h: CGFloat) -> CGRect {
        switch style {
        case .glass:
            // 不缩小 — 玻璃变透明让后景透出
            return CGRect(x: w * 0.18, y: h * 0.16,
                          width: w * 0.64, height: h * 0.68)
        case .room:
            // 居中偏上 约 48% x 44%
            return CGRect(x: w * 0.26, y: h * 0.12,
                          width: w * 0.48, height: h * 0.42)
        case .street:
            // 中上偏仰 30% x 36%，视角微仰（上窄下宽会更像仰视，这里保持矩形简化）
            return CGRect(x: w * 0.34, y: h * 0.14,
                          width: w * 0.32, height: h * 0.36)
        }
    }

    // MARK: - [A] Glass BG — 透过窗看到的雨夜街景

    private func drawGlassBG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                              cityFar: Color, cityNear: Color, fogTint: Color,
                              streetAmber: Color, glassCoolHL: Color,
                              t: Float, bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat) {
        // 远楼轮廓 — 只画剪影，无窗格（窗格细节在玻璃后看不清）
        let farBaseY = h * 0.56
        let farSilhouettes: [(x: CGFloat, w: CGFloat, h: CGFloat)] = [
            (w * 0.02, w * 0.18, h * 0.22),
            (w * 0.22, w * 0.14, h * 0.30),
            (w * 0.40, w * 0.16, h * 0.18),
            (w * 0.58, w * 0.20, h * 0.34),
            (w * 0.80, w * 0.20, h * 0.24)
        ]
        for b in farSilhouettes {
            let rect = CGRect(x: b.x, y: farBaseY - b.h, width: b.w, height: b.h)
            ctx.fill(Path(rect), with: .color(cityFar.opacity(0.85)))
        }

        // 雾 band — 让远楼 fade 入夜空
        ctx.fill(Path(CGRect(x: 0, y: farBaseY - h * 0.06, width: w, height: h * 0.18)),
                 with: .linearGradient(
                    Gradient(colors: [
                        fogTint.opacity(0),
                        fogTint.opacity(0.45 + Double(midCG) * 0.30),
                        fogTint.opacity(0)
                    ]),
                    startPoint: CGPoint(x: 0, y: farBaseY - h * 0.06),
                    endPoint: CGPoint(x: 0, y: farBaseY + h * 0.12)
                 ))

        // 中景地面——湿漉漉的反光带
        ctx.fill(Path(CGRect(x: 0, y: farBaseY, width: w, height: h - farBaseY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: cityNear.opacity(0.75), location: 0),
                        .init(color: cityFar.opacity(0.92),   location: 1)
                    ]),
                    startPoint: CGPoint(x: 0, y: farBaseY),
                    endPoint: CGPoint(x: 0, y: h)
                 ))

        // 街灯 bokeh — 随 bass 呼吸
        let lamps: [(x: CGFloat, y: CGFloat, r: CGFloat, alpha: Double)] = [
            (w * 0.12, h * 0.62, 48, 0.32),
            (w * 0.55, h * 0.58, 42, 0.28),
            (w * 0.90, h * 0.68, 58, 0.38)
        ]
        for (idx, lamp) in lamps.enumerated() {
            let breathe = 1.0 + Double(bassCG) * 0.28
                           + sin(Double(t) * 2.8 + Double(idx) * 1.7) * Double(trebleCG) * 0.22
            let r = lamp.r * CGFloat(breathe)
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - r, y: lamp.y - r,
                                               width: r * 2, height: r * 2)),
                     with: .radialGradient(
                        Gradient(stops: [
                            .init(color: streetAmber.opacity(lamp.alpha),       location: 0),
                            .init(color: streetAmber.opacity(lamp.alpha * 0.4), location: 0.45),
                            .init(color: streetAmber.opacity(0),                location: 1)
                        ]),
                        center: CGPoint(x: lamp.x, y: lamp.y),
                        startRadius: 0, endRadius: r
                     ))
            // 街灯在湿地上的拖影
            let puddleH: CGFloat = 40
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - r * 0.7, y: lamp.y + 4,
                                               width: r * 1.4, height: puddleH)),
                     with: .radialGradient(
                        Gradient(colors: [
                            streetAmber.opacity(lamp.alpha * 0.35),
                            streetAmber.opacity(0)
                        ]),
                        center: CGPoint(x: lamp.x, y: lamp.y + 14),
                        startRadius: 0, endRadius: r
                     ))
            // 灯芯
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - 2, y: lamp.y - 2,
                                               width: 4, height: 4)),
                     with: .color(streetAmber.opacity(0.95)))
        }

        // 远处细雨丝（在街灯/楼上下）— bass 加速、treble 加密
        let count = 16 + Int(trebleCG * 26)
        let fallSpeed: Float = 0.55 + Float(bassCG) * 1.8
        for i in 0..<count {
            let s = Float(i) * 0.7131
            let colFrac = (s * 1.618).truncatingRemainder(dividingBy: 1.0)
            let x = CGFloat(colFrac) * w
            let yFrac = (t * fallSpeed + s * 2.37).truncatingRemainder(dividingBy: 1.4)
            let yNorm = yFrac < 0 ? yFrac + 1.4 : yFrac
            let y = CGFloat(yNorm - 0.2) * h
            let streakLen: CGFloat = 6 + CGFloat(i % 3) * 2
            let alpha = 0.14 + Double(trebleCG) * 0.10

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 0.18 * streakLen, y: y + streakLen))
            ctx.stroke(path, with: .color(glassCoolHL.opacity(alpha)), lineWidth: 0.5)
        }
    }

    // MARK: - [B] Room BG — 窗外夜景（极简，窗会盖住大部分）

    private func drawRoomBG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                             glassCoolHL: Color,
                             t: Float, trebleCG: CGFloat, midCG: CGFloat) {
        // Room 方案 BG 非常简：窗外是纯黑蓝夜，几点远处暖灯
        // 这里不画太多，因为窗户会盖住一大部分
        let dots: [(nx: CGFloat, ny: CGFloat, period: Float, phase: Float)] = [
            (0.30, 0.30, 5.0, 0.1), (0.55, 0.22, 6.3, 0.6),
            (0.70, 0.32, 4.1, 0.3), (0.45, 0.38, 7.2, 0.85)
        ]
        let threshold = 0.4 + Double(trebleCG) * 0.2 + Double(midCG) * 0.15
        for d in dots {
            let phaseVal = (t / d.period + d.phase).truncatingRemainder(dividingBy: 1.0)
            let n = phaseVal < 0 ? phaseVal + 1 : phaseVal
            if Double(n) < threshold {
                let alpha = 0.35 * (1 - Double(n) / threshold)
                let x = d.nx * w, y = d.ny * h
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5,
                                                   width: 3, height: 3)),
                         with: .color(Color(red: 220/255, green: 170/255,
                                             blue: 110/255).opacity(alpha)))
            }
        }
    }

    // MARK: - [B] Room FG — 桌面 + 台灯 + 蒸汽 + 地板

    private func drawRoomFG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                             windowRect: CGRect,
                             woodDark: Color, woodMid: Color,
                             warmLamp: Color, candleFlame: Color,
                             t: Float, bassCG: CGFloat, midCG: CGFloat) {
        // 桌面水平带 —— 从 h*0.62 到 h*0.78
        let deskTop = h * 0.62
        let deskBottom = h * 0.80
        ctx.fill(Path(CGRect(x: 0, y: deskTop, width: w, height: deskBottom - deskTop)),
                 with: .linearGradient(
                    Gradient(colors: [woodMid, woodDark]),
                    startPoint: CGPoint(x: 0, y: deskTop),
                    endPoint: CGPoint(x: 0, y: deskBottom)
                 ))

        // 桌面前沿（深色薄条）
        ctx.fill(Path(CGRect(x: 0, y: deskBottom - 2, width: w, height: 2)),
                 with: .color(Color.black.opacity(0.65)))

        // 地板（桌面下方）— 更暗
        ctx.fill(Path(CGRect(x: 0, y: deskBottom, width: w, height: h - deskBottom)),
                 with: .linearGradient(
                    Gradient(colors: [woodDark, Color.black.opacity(0.92)]),
                    startPoint: CGPoint(x: 0, y: deskBottom),
                    endPoint: CGPoint(x: 0, y: h)
                 ))

        // 地板纹理（几根水平暗线）
        for i in 0..<4 {
            let ly = deskBottom + CGFloat(i) * (h - deskBottom) / 4 + 6
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: ly))
                p.addLine(to: CGPoint(x: w, y: ly))
            }, with: .color(Color.black.opacity(0.45)), lineWidth: 0.6)
        }

        // 台灯（左前方）
        //   灯罩：扁梯形，暖色发光
        //   底座：暗剪影
        //   灯芯溢出暖色 radial 照亮周围
        let lampX = w * 0.18
        let lampBaseY = deskTop + 6
        let shadeCX = lampX
        let shadeCY = lampBaseY - 42

        // 灯光呼吸（bass驱动）
        let lampBreath = 1.0 + Double(bassCG) * 0.35 + sin(Double(t) * 1.4) * 0.04
        let lampRadius: CGFloat = 90 * CGFloat(lampBreath)
        ctx.fill(Path(ellipseIn: CGRect(x: shadeCX - lampRadius, y: shadeCY - lampRadius * 0.8,
                                           width: lampRadius * 2, height: lampRadius * 1.6)),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: warmLamp.opacity(0.55), location: 0),
                        .init(color: warmLamp.opacity(0.22), location: 0.4),
                        .init(color: warmLamp.opacity(0),    location: 1)
                    ]),
                    center: CGPoint(x: shadeCX, y: shadeCY),
                    startRadius: 0, endRadius: lampRadius
                 ))

        // 灯罩梯形（暖色实体）
        var shade = Path()
        shade.move(to: CGPoint(x: shadeCX - 14, y: shadeCY - 14))
        shade.addLine(to: CGPoint(x: shadeCX + 14, y: shadeCY - 14))
        shade.addLine(to: CGPoint(x: shadeCX + 20, y: shadeCY + 8))
        shade.addLine(to: CGPoint(x: shadeCX - 20, y: shadeCY + 8))
        shade.closeSubpath()
        ctx.fill(shade, with: .linearGradient(
            Gradient(colors: [
                warmLamp.opacity(0.95),
                Color(red: 188/255, green: 120/255, blue: 60/255).opacity(0.85)
            ]),
            startPoint: CGPoint(x: shadeCX, y: shadeCY - 14),
            endPoint: CGPoint(x: shadeCX, y: shadeCY + 8)
        ))
        // 灯罩下沿微亮（灯芯透光）
        ctx.fill(Path(CGRect(x: shadeCX - 18, y: shadeCY + 6,
                               width: 36, height: 3)),
                 with: .color(candleFlame.opacity(0.95)))

        // 灯杆
        ctx.fill(Path(CGRect(x: shadeCX - 1, y: shadeCY + 9,
                               width: 2, height: 30)),
                 with: .color(Color.black.opacity(0.85)))
        // 灯座
        ctx.fill(Path(ellipseIn: CGRect(x: shadeCX - 12, y: lampBaseY - 8,
                                            width: 24, height: 10)),
                 with: .color(Color.black.opacity(0.85)))

        // 右边一个杯子剪影 + 蒸汽
        let cupX = w * 0.66
        let cupBottomY = deskTop + 28
        let cupTopY = deskTop + 4
        let cupW: CGFloat = 18
        var cup = Path()
        cup.move(to: CGPoint(x: cupX - cupW/2, y: cupTopY))
        cup.addLine(to: CGPoint(x: cupX + cupW/2, y: cupTopY))
        cup.addLine(to: CGPoint(x: cupX + cupW/2 - 2, y: cupBottomY))
        cup.addLine(to: CGPoint(x: cupX - cupW/2 + 2, y: cupBottomY))
        cup.closeSubpath()
        ctx.fill(cup, with: .color(Color.black.opacity(0.82)))
        // 杯把手
        ctx.stroke(Path(ellipseIn: CGRect(x: cupX + cupW/2 - 2, y: cupTopY + 4,
                                              width: 10, height: 12)),
                   with: .color(Color.black.opacity(0.82)), lineWidth: 1.4)
        // 杯口
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: cupX - cupW/2, y: cupTopY))
            p.addLine(to: CGPoint(x: cupX + cupW/2, y: cupTopY))
        }, with: .color(warmLamp.opacity(0.45)), lineWidth: 1.0)

        // 蒸汽 3 根线往上飘（正弦波动，mid 驱动弯曲度）
        for strand in 0..<3 {
            let sx = cupX + CGFloat(strand - 1) * 4
            var path = Path()
            let startY = cupTopY - 2
            path.move(to: CGPoint(x: sx, y: startY))
            var py = startY
            var px = sx
            let steps = 10
            for i in 1...steps {
                let localT = CGFloat(i) / CGFloat(steps)
                py = startY - localT * 40
                let wave = sin(Double(t) * 1.6 + Double(strand) * 1.3
                                + Double(localT) * 5.5) * (1.5 + Double(midCG) * 4.5)
                px = sx + CGFloat(wave) * localT
                path.addLine(to: CGPoint(x: px, y: py))
            }
            let alpha = 0.20 - CGFloat(strand) * 0.05
            ctx.stroke(path, with: .color(Color.white.opacity(Double(alpha))),
                       lineWidth: 0.8)
        }
    }

    // MARK: - [C] Street BG — 墙 + 湿地砖 + 近雨

    private func drawStreetBG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                                wallDim: Color, fogTint: Color,
                                t: Float, midCG: CGFloat) {
        // 整个画面先铺一层冷墙色（比背景稍亮一点）
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .color(wallDim.opacity(0.45)))

        // 地砖（画面下 40%）—— 更暗、湿漉漉
        let groundY = h * 0.62
        ctx.fill(Path(CGRect(x: 0, y: groundY, width: w, height: h - groundY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.black.opacity(0.75), location: 0),
                        .init(color: Color.black.opacity(0.92), location: 1)
                    ]),
                    startPoint: CGPoint(x: 0, y: groundY),
                    endPoint: CGPoint(x: 0, y: h)
                 ))

        // 地砖接缝（水平 + 斜向远景透视简化）
        for i in 0..<5 {
            let ly = groundY + CGFloat(i) * (h - groundY) / 5
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: ly))
                p.addLine(to: CGPoint(x: w, y: ly))
            }, with: .color(Color.black.opacity(0.55)), lineWidth: 0.6)
        }
        // 垂直接缝（随机几条制造地砖块感）
        let verticals: [CGFloat] = [w * 0.14, w * 0.28, w * 0.44, w * 0.58, w * 0.72, w * 0.88]
        for vx in verticals {
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: vx, y: groundY + 6))
                p.addLine(to: CGPoint(x: vx, y: h))
            }, with: .color(Color.black.opacity(0.4)), lineWidth: 0.5)
        }

        // 地平线雾
        ctx.fill(Path(CGRect(x: 0, y: groundY - 14, width: w, height: 40)),
                 with: .linearGradient(
                    Gradient(colors: [
                        fogTint.opacity(0),
                        fogTint.opacity(0.35 + Double(midCG) * 0.25),
                        fogTint.opacity(0)
                    ]),
                    startPoint: CGPoint(x: 0, y: groundY - 14),
                    endPoint: CGPoint(x: 0, y: groundY + 26)
                 ))
    }

    // MARK: - [C] Street FG — 地面上窗光倒影 + 近景雨

    private func drawStreetFG(ctx: GraphicsContext, w: CGFloat, h: CGFloat,
                                windowRect: CGRect,
                                warmLamp: Color, glassCoolHL: Color,
                                t: Float, bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat) {
        // 地面 4 格窗光倒影 —— 从窗正下方往画面底部竖向拉长
        //   4 个暖色柔软矩形，带 bass 呼吸
        let refY0 = h * 0.66
        let refY1 = h * 0.95
        let refH = refY1 - refY0
        let halfW = windowRect.width * 0.5
        let leftX = windowRect.midX - halfW
        let rightX = windowRect.midX + halfW

        // 左列 2 格
        let col1Rect = CGRect(x: leftX, y: refY0,
                               width: halfW * 0.95, height: refH)
        // 右列 2 格
        let col2Rect = CGRect(x: windowRect.midX + halfW * 0.05, y: refY0,
                               width: halfW * 0.95, height: refH)

        // 倒影透明度 + 暖光呼吸
        let reflBreath = 0.38 + Double(bassCG) * 0.30
        for colRect in [col1Rect, col2Rect] {
            ctx.fill(Path(colRect),
                     with: .linearGradient(
                        Gradient(stops: [
                            .init(color: warmLamp.opacity(reflBreath),        location: 0),
                            .init(color: warmLamp.opacity(reflBreath * 0.3), location: 0.7),
                            .init(color: warmLamp.opacity(0),                  location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: colRect.minY),
                        endPoint: CGPoint(x: 0, y: colRect.maxY)
                     ))
        }

        // 倒影中央的 mullion 间隙（稍暗一点的 vertical 黑条）
        let mullionGap: CGFloat = halfW * 0.05
        ctx.fill(Path(CGRect(x: windowRect.midX - mullionGap/2,
                               y: refY0, width: mullionGap, height: refH * 0.6)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0)
                    ]),
                    startPoint: CGPoint(x: 0, y: refY0),
                    endPoint: CGPoint(x: 0, y: refY0 + refH * 0.6)
                 ))

        // 横向 mullion 倒影（淡一道横切）
        ctx.fill(Path(CGRect(x: leftX, y: refY0 + refH * 0.35,
                               width: halfW * 2, height: 2)),
                 with: .color(Color.black.opacity(0.35)))

        // 近景雨丝（画面满，相对密集，bass 加速、treble 加密）
        let count = 28 + Int(trebleCG * 50)
        let fallSpeed: Float = 0.85 + Float(bassCG) * 2.6
        for i in 0..<count {
            let s = Float(i) * 0.731
            let colFrac = (s * 1.618).truncatingRemainder(dividingBy: 1.0)
            let x = CGFloat(colFrac) * w
            let yFrac = (t * fallSpeed + s * 2.37).truncatingRemainder(dividingBy: 1.2)
            let yNorm = yFrac < 0 ? yFrac + 1.2 : yFrac
            let y = CGFloat(yNorm - 0.1) * h
            let streakLen: CGFloat = 10 + CGFloat(i % 4) * 3
            let alpha = 0.18 + Double(trebleCG) * 0.14

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 0.18 * streakLen, y: y + streakLen))
            ctx.stroke(path, with: .color(glassCoolHL.opacity(alpha)), lineWidth: 0.6)
        }

        // 水面涟漪（画面底部 2-3 圈，随 mid 激活）
        if midCG > 0.1 {
            let rippleBase = h * 0.92
            for r in 0..<3 {
                let rx = w * (0.3 + CGFloat(r) * 0.25)
                let phase = (Double(t) * 1.5 + Double(r) * 2.3)
                    .truncatingRemainder(dividingBy: 1.0)
                let scale = 8.0 + phase * 28
                let alpha = 0.22 * (1 - phase)
                ctx.stroke(Path(ellipseIn: CGRect(x: rx - CGFloat(scale)/2,
                                                      y: rippleBase - CGFloat(scale) * 0.15,
                                                      width: CGFloat(scale),
                                                      height: CGFloat(scale) * 0.3)),
                           with: .color(glassCoolHL.opacity(alpha * Double(midCG) * 2)),
                           lineWidth: 0.6)
            }
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
                             sceneAlpha: Double,
                             glassTransparency: Double = 0) {
        // 小窗远景分支 — 保留原有像素窗行为，但 100pt 以下不会触发（大图 3 套都在 100+）
        if frame.width < 100 {
            let breathe = 1.0 + Double(bassCG) * 0.55 + sin(Double(t) * 1.8) * 0.08
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
            let mW: CGFloat = max(0.6, frame.width * 0.018)
            let mxC = frame.minX + frame.width * 0.5
            ctx.fill(Path(CGRect(x: mxC - mW / 2, y: frame.minY,
                                  width: mW, height: frame.height)),
                     with: .color(Color.black.opacity(0.50)))
            let myC = frame.minY + frame.height * 0.5
            ctx.fill(Path(CGRect(x: frame.minX, y: myC - mW / 2,
                                  width: frame.width, height: mW)),
                     with: .color(Color.black.opacity(0.50)))
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

        // 玻璃 + 室内暖光 —— glass 方案大图时整体变透明让后景透出
        //   glassTransparency 0 = 完全不透（默认），0.6 = 玻璃在大图时的透明度
        let lampIntensity = (0.40 + Double(bassCG) * 0.75
                             + Double(sin(Double(t) * 2.1)) * 0.05) * (1 - glassTransparency)
        let interiorCenterX = frame.minX + frame.width * 0.60
        let interiorCenterY = frame.midY + frame.height * 0.10
        let outerGlassAlpha = 0.88 * (1 - glassTransparency)
        ctx.fill(Path(frame),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: lampColor.opacity(lampIntensity),        location: 0),
                        .init(color: lampColor.opacity(lampIntensity * 0.45), location: 0.55),
                        .init(color: glassCold.opacity(outerGlassAlpha),       location: 1)
                    ]),
                    center: CGPoint(x: interiorCenterX, y: interiorCenterY),
                    startRadius: 0, endRadius: max(frame.width, frame.height) * 0.85
                 ))

        // 窗格 mullion —— 十字
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

    // MARK: - Rain on glass

    private func drawRainOnGlass(ctx: GraphicsContext, frame: CGRect,
                                   spectrumData: [Float],
                                   bassCG: CGFloat, midCG: CGFloat, trebleCG: CGFloat,
                                   t: Float, isMain: Bool,
                                   glassCoolHL: Color) {
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
            let magnitude = CGFloat(bin) * (1 - CGFloat(idle)) + 0.08 * CGFloat(idle)

            let maxLen = frame.height * (isMain ? 0.40 : 0.26)
            let streakLen = 8 + magnitude * maxLen * 1.2
            let fallSpeed = 0.30 + Double(bassCG) * 2.5 + Double(magnitude) * 0.4

            let yCycle = (Double(t) * fallSpeed + s * 3.3).truncatingRemainder(dividingBy: 1.0)
            let y0 = frame.minY + CGFloat(yCycle) * frame.height

            let drift = CGFloat(sin(Double(t) * 1.6 + s)) * trebleCG * 12

            let headX = x + drift
            let headY = y0
            let midY = y0 - streakLen * 0.5
            let midX = x + drift + CGFloat(sin(s * 2.1)) * 1.6
            let tailX = x + drift * 0.4 + CGFloat(sin(s * 0.7)) * 1.5
            let tailY = y0 - streakLen

            var trail = Path()
            trail.move(to: CGPoint(x: tailX, y: tailY))
            trail.addQuadCurve(to: CGPoint(x: headX, y: headY),
                                control: CGPoint(x: midX, y: midY))
            let trailAlpha = 0.24 + Double(magnitude) * 0.50
            ctx.stroke(trail,
                       with: .color(glassCoolHL.opacity(trailAlpha
                                                          * (isMain ? 0.88 : 0.55))),
                       lineWidth: isMain ? 0.85 : 0.55)

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

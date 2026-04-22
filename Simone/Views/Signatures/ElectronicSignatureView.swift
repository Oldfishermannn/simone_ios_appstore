import SwiftUI

/// Electronic Signature — "Analog Voyager" · V6 正面视角 (Front Elevation)
///
/// CEO 反馈："还是好丑啊 你能做正面视角吗"
/// 放弃前五版的 3D 斜视角（shear / 真 3D projection / 双层 riser），
/// 回归最干净的正面 elevation view——参考 Moog Subsequent 37 / Prophet
/// 正面摄影：胡桃木端板 + 黑色金属面板（顶部稍微内缩做"倾斜提示"）+
/// 下半部键盘 + 底部金属条，单光从左上来。
///
/// Layout（从上到下）：
///   1. wooden cabinet 外框（左右端板明显，顶部/底部细胡桃木条）
///   2. 黑色金属控制面板（顶部略向后倾的梯形 = 上窄下宽，形成"倾斜"幻觉）
///   3. 金属铭牌条（logo 位置）
///   4. 键盘区（14 白键 + 5 黑键，有 front lip）
///
/// Design principles (来自 .impeccable.md)：
///   物件感 > UI 感 — 这是房间里的一件乐器，不是控制面板 UI
///   侧光 — 单灯从左上 45°，右侧入阴影，胡桃木左亮右暗
///   克制温度 — 胡桃木暖色为主，黑色面板沉稳，LED 红 + CRT 绿为仅有的
///              accent（单灯点缀，不渲染氛围）
///   动而非跳 — CRT 波形（mid）+ LED 呼吸（bass）+ 一个旋钮微动指针
///
/// Palette（保持克制）：
///   roomDeep   ( 10, 10, 14)   背景
///   woodHi     (178,124, 74)   walnut 受光
///   woodFront  (132, 84, 48)   walnut 本色
///   woodShad   ( 68, 38, 18)   walnut 阴影
///   woodEdge   ( 34, 20, 10)   walnut 内缘
///   panelHi    ( 78, 78, 86)   金属面板 bevel
///   panelTop   ( 28, 28, 32)   金属面板（顶部受光）
///   panelBot   ( 14, 14, 18)   金属面板（底部）
///   nameplate  ( 96, 92, 84)   铭牌铜
///   keyWhite   (240,236,224)
///   keyWhiteLo (168,164,154)
///   keyBlack   ( 10,  8, 10)
///   keyBlackHi ( 46, 42, 46)
///   knobChrome (170,172,178)
///   knobBody   ( 18, 18, 22)
///   indicator  (244,240,228)
///   ledRed     (232, 76, 54)
///   scopeGreen (104,222,136)
///
/// Audio reactivity 仅限：
///   · bass → POWER LED 辉度呼吸
///   · mid  → CRT oscilloscope 波形振幅
///   · 其余全部静态（避免乱跳）
struct ElectronicSignatureView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0

    var body: some View {
        let e: CGFloat = max(0, min(1, expansion))
        let deckAlpha = smoothstep(0.30, 0.88, Double(e))

        ZStack {
            // Static scaffold — synth 主体（cabinet + 面板 + 旋钮 + 键盘）。
            // synth 位置随 e 线性插值：小图居中、大图上移到顶部，让出底部空间。
            Canvas { context, size in
                drawStatic(ctx: context, size: size, e: e)
            }
            .drawingGroup()

            // Pedalboard layer — 大图专属（Ambient channel 同款 morph 模式）。
            // 5 块 iconic guitar pedal 排在 synth 下方；deckAlpha 控制 compositor
            // 级别淡入，小图完全不可见。
            Canvas { context, size in
                drawPedalboard(ctx: context, size: size, e: e)
            }
            .drawingGroup()
            .opacity(deckAlpha)
            .allowsHitTesting(false)

            // Dynamic overlay — CRT waveform + POWER LED.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                Canvas { context, size in
                    drawDynamic(ctx: context, size: size, t: ctx.date.timeIntervalSince1970)
                }
            }
        }
    }

    // MARK: - Palette
    private let roomDeep   = Color(red: 0.040, green: 0.040, blue: 0.055)
    private let roomSpill  = Color(red: 0.110, green: 0.082, blue: 0.055)

    private let woodHi     = Color(red: 0.698, green: 0.486, blue: 0.290)
    private let woodFront  = Color(red: 0.518, green: 0.329, blue: 0.188)
    private let woodShad   = Color(red: 0.267, green: 0.149, blue: 0.071)
    private let woodEdge   = Color(red: 0.133, green: 0.078, blue: 0.039)

    private let panelHi    = Color(red: 0.306, green: 0.306, blue: 0.337)
    private let panelTop   = Color(red: 0.110, green: 0.110, blue: 0.125)
    private let panelBot   = Color(red: 0.055, green: 0.055, blue: 0.071)
    private let panelEdge  = Color(red: 0.020, green: 0.020, blue: 0.030)

    private let nameplate  = Color(red: 0.376, green: 0.361, blue: 0.329)
    private let namplateHi = Color(red: 0.580, green: 0.549, blue: 0.486)

    private let keyWhiteTop = Color(red: 0.941, green: 0.925, blue: 0.878)
    private let keyWhiteLo  = Color(red: 0.659, green: 0.643, blue: 0.604)
    private let keyBlackTop = Color(red: 0.180, green: 0.165, blue: 0.180)
    private let keyBlackLo  = Color(red: 0.039, green: 0.031, blue: 0.039)

    private let knobChrome  = Color(red: 0.667, green: 0.675, blue: 0.698)
    private let knobBody    = Color(red: 0.071, green: 0.071, blue: 0.086)
    private let indicator   = Color(red: 0.957, green: 0.941, blue: 0.894)
    private let ledRed      = Color(red: 0.910, green: 0.298, blue: 0.212)
    private let scopeGreen  = Color(red: 0.408, green: 0.871, blue: 0.533)

    // MARK: - Shared layout
    private struct Layout {
        let body: CGRect
        let panel: CGRect
        let strip: CGRect
        let kb: CGRect
        let scope: CGRect
        let ledC: CGPoint
    }

    private func layout(for size: CGSize, expansion e: CGFloat = 0) -> Layout {
        let W = size.width
        let H = size.height
        let synthW = min(W * 0.84, H * 1.55)
        let synthH = synthW * 0.54
        let synthX = (W - synthW) / 2
        // 小图：synth 居中。大图：synth 上移让出底部空间给 pedalboard
        // (~synthH * 0.55，pedalboard 高 ≈ synthH * 0.55，恰好填满)。
        let centerY = (H - synthH) / 2
        let bigY = max(H * 0.10, centerY - synthH * 0.55)
        let synthY = centerY + (bigY - centerY) * max(0, min(1, e))
        let body = CGRect(x: synthX, y: synthY, width: synthW, height: synthH)
        let endW: CGFloat = body.width * 0.052
        let woodV: CGFloat = body.height * 0.045
        let inner = CGRect(
            x: body.minX + endW,
            y: body.minY + woodV,
            width: body.width - endW * 2,
            height: body.height - woodV * 2
        )
        let panelH = inner.height * 0.58
        let stripH = inner.height * 0.040
        let kbH = inner.height - panelH - stripH
        let panel = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: panelH)
        let strip = CGRect(x: inner.minX, y: panel.maxY, width: inner.width, height: stripH)
        let kb = CGRect(x: inner.minX, y: strip.maxY, width: inner.width, height: kbH)
        let pad: CGFloat = panel.width * 0.028
        let scopeW = panel.width * 0.18
        let scopeH = panel.height * 0.38
        let scope = CGRect(x: panel.midX - scopeW / 2, y: panel.minY + pad, width: scopeW, height: scopeH)
        let ledC = CGPoint(x: panel.maxX - pad - 10, y: panel.minY + pad + 6)
        return Layout(body: body, panel: panel, strip: strip, kb: kb, scope: scope, ledC: ledC)
    }

    // MARK: - Static scene (cacheable, drawn once per size)
    private func drawStatic(ctx: GraphicsContext, size: CGSize, e: CGFloat) {
        let L = layout(for: size, expansion: e)

        // 纯黑底色 — 全部环境光已移除，synth 悬浮在深夜房间里。
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(roomDeep))

        drawGroundShadow(ctx: ctx, under: L.body)
        drawCabinet(ctx: ctx, body: L.body)
        drawControlPanelStatic(ctx: ctx, rect: L.panel, scope: L.scope, ledC: L.ledC)
        drawOscilloscopeStatic(ctx: ctx, rect: L.scope)
        drawNameplate(ctx: ctx, rect: L.strip)
        drawKeyboard(ctx: ctx, rect: L.kb)
    }

    // MARK: - Dynamic scene (30 FPS, lightweight: CRT wave + POWER LED only)
    //
    // 环境光已全删：panel lamp wash / 键盘 underglow / 房间 spill 都清掉。
    // 现在 dynamic 层只剩 CRT 波形 + POWER LED 这两处 synth 物件自身的"电"。
    private func drawDynamic(ctx: GraphicsContext, size: CGSize, t: TimeInterval) {
        let e: CGFloat = max(0, min(1, expansion))
        let L = layout(for: size, expansion: e)

        // Audio extraction
        let third = max(1, spectrumData.count / 3)
        var bassSum: Float = 0, midSum: Float = 0
        let bassCount = min(third, spectrumData.count)
        let midEnd = min(third * 2, spectrumData.count)
        for i in 0..<bassCount { bassSum += spectrumData[i] }
        for i in bassCount..<midEnd { midSum += spectrumData[i] }
        let rawBass: CGFloat = bassCount > 0 ? CGFloat(bassSum) / CGFloat(bassCount) : 0
        let rawMid: CGFloat  = (midEnd - bassCount) > 0 ? CGFloat(midSum) / CGFloat(midEnd - bassCount) : 0
        let silence = rawBass + rawMid < 0.02
        let idle = silence ? (0.08 + 0.06 * sin(CGFloat(t) * 0.9)) : 0
        let bassLvl = min(1, max(0, rawBass * 1.4 + idle))
        let midLvl  = min(1, max(0, rawMid  * 1.4))

        let zc = CGFloat(smoothstep(0.30, 0.88, Double(e)))

        drawOscilloscopeDynamic(ctx: ctx, rect: L.scope, t: t, midLvl: midLvl, zc: zc)
        drawPowerLED(ctx: ctx, center: L.ledC, bassLvl: bassLvl)
    }


    // MARK: - Pedalboard (大图专属，参考 Ambient channel small→big morph)
    //
    // 5 块 iconic guitar pedals 排在 synth 下方一排：
    //   TS808 (绿) → Centavo (黄) → RAT (黑) → TimeLine (灰) → BigSky (蓝)
    // synth body 已随 e 上移，pedalboard 紧跟 body.maxY 自然落到底部。
    // 整层由 .opacity(deckAlpha) 在 compositor 层淡入，零 per-frame 成本。
    private func drawPedalboard(ctx: GraphicsContext, size: CGSize, e: CGFloat) {
        let L = layout(for: size, expansion: e)
        let body = L.body

        // 排布顺序（CEO v4.1）：绿 → 黄 → 黑 → 灰 → 蓝
        // TS808(0.58) → Centavo(1.32) → RAT(0.72) → TimeLine(1.42) → BigSky(1.42)
        let ratios: [CGFloat] = [0.58, 1.32, 0.72, 1.42, 1.42]
        let sumR = ratios.reduce(0, +)
        let gapFactor: CGFloat = 0.09
        let gapCount: CGFloat = 4

        let rowW = body.width * 0.92
        let H = rowW / (sumR + gapCount * gapFactor)
        let G = H * gapFactor

        let rowTop = body.maxY + body.height * 0.14
        let rowLeft = body.midX - rowW / 2

        // Shared ground shadow under the whole pedalboard row
        let boardShadow = CGRect(
            x: rowLeft - H * 0.08,
            y: rowTop + H * 0.96,
            width: rowW + H * 0.16,
            height: H * 0.22
        )
        ctx.fill(
            Path(ellipseIn: boardShadow),
            with: .radialGradient(
                Gradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)]),
                center: CGPoint(x: boardShadow.midX, y: boardShadow.midY),
                startRadius: 1,
                endRadius: boardShadow.width * 0.48
            )
        )

        var x = rowLeft
        let w0 = H * ratios[0]
        drawPedalTS808(ctx: ctx, rect: CGRect(x: x, y: rowTop, width: w0, height: H))
        x += w0 + G
        let w1 = H * ratios[1]
        drawPedalCentavo(ctx: ctx, rect: CGRect(x: x, y: rowTop, width: w1, height: H))
        x += w1 + G
        let w2 = H * ratios[2]
        drawPedalRAT(ctx: ctx, rect: CGRect(x: x, y: rowTop, width: w2, height: H))
        x += w2 + G
        let w3 = H * ratios[3]
        drawPedalTimeLine(ctx: ctx, rect: CGRect(x: x, y: rowTop, width: w3, height: H))
        x += w3 + G
        let w4 = H * ratios[4]
        drawPedalBigSky(ctx: ctx, rect: CGRect(x: x, y: rowTop, width: w4, height: H))
    }

    // MARK: - Pedal chassis (shared beveled metal box + 4 corner screws)
    private func drawPedalChassis(ctx: GraphicsContext, rect: CGRect, topColor: Color, botColor: Color) {
        let r: CGFloat = max(1.5, min(rect.width, rect.height) * 0.05)
        let sh = rect.offsetBy(dx: 1.5, dy: 2.5)
        ctx.fill(Path(roundedRect: sh, cornerRadius: r), with: .color(Color.black.opacity(0.45)))
        ctx.fill(
            Path(roundedRect: rect, cornerRadius: r),
            with: .linearGradient(
                Gradient(colors: [topColor, botColor]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        var topHL = Path()
        topHL.move(to: CGPoint(x: rect.minX + r, y: rect.minY + 0.5))
        topHL.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY + 0.5))
        ctx.stroke(topHL, with: .color(Color.white.opacity(0.16)), lineWidth: 0.6)
        var leftHL = Path()
        leftHL.move(to: CGPoint(x: rect.minX + 0.5, y: rect.minY + r))
        leftHL.addLine(to: CGPoint(x: rect.minX + 0.5, y: rect.maxY - r))
        ctx.stroke(leftHL, with: .color(Color.white.opacity(0.08)), lineWidth: 0.6)
        var rightSh = Path()
        rightSh.move(to: CGPoint(x: rect.maxX - 0.5, y: rect.minY + r))
        rightSh.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.maxY - r))
        ctx.stroke(rightSh, with: .color(Color.black.opacity(0.40)), lineWidth: 0.6)
        var botSh = Path()
        botSh.move(to: CGPoint(x: rect.minX + r, y: rect.maxY - 0.5))
        botSh.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY - 0.5))
        ctx.stroke(botSh, with: .color(Color.black.opacity(0.40)), lineWidth: 0.6)
        let screwR: CGFloat = max(0.7, min(rect.width, rect.height) * 0.035)
        let inset: CGFloat = max(2, min(rect.width, rect.height) * 0.075)
        for cx in [rect.minX + inset, rect.maxX - inset] {
            for cy in [rect.minY + inset, rect.maxY - inset] {
                drawPedalScrew(ctx: ctx, center: CGPoint(x: cx, y: cy), radius: screwR)
            }
        }
    }

    private func drawPedalScrew(ctx: GraphicsContext, center: CGPoint, radius r: CGFloat) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.82, green: 0.84, blue: 0.86),
                    Color(red: 0.38, green: 0.40, blue: 0.44)
                ]),
                center: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.3),
                startRadius: 0.1, endRadius: r
            )
        )
        var slot = Path()
        slot.move(to: CGPoint(x: center.x - r * 0.55, y: center.y))
        slot.addLine(to: CGPoint(x: center.x + r * 0.55, y: center.y))
        slot.move(to: CGPoint(x: center.x, y: center.y - r * 0.55))
        slot.addLine(to: CGPoint(x: center.x, y: center.y + r * 0.55))
        ctx.stroke(slot, with: .color(Color.black.opacity(0.55)), lineWidth: max(0.3, r * 0.22))
    }

    private func drawPedalKnob(ctx: GraphicsContext, center: CGPoint, radius r: CGFloat, angle: CGFloat) {
        let shR = CGRect(x: center.x - r + 0.6, y: center.y - r + 1.2, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: shR), with: .color(Color.black.opacity(0.35)))
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.93, green: 0.94, blue: 0.96),
                    Color(red: 0.52, green: 0.54, blue: 0.58),
                    Color(red: 0.18, green: 0.18, blue: 0.20)
                ]),
                center: CGPoint(x: center.x - r * 0.38, y: center.y - r * 0.38),
                startRadius: 0.2, endRadius: r * 1.05
            )
        )
        ctx.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.55)), lineWidth: max(0.3, r * 0.05))
        let tip = CGPoint(
            x: center.x + cos(angle) * r * 0.82,
            y: center.y + sin(angle) * r * 0.82
        )
        var line = Path()
        line.move(to: center)
        line.addLine(to: tip)
        ctx.stroke(line, with: .color(Color.black.opacity(0.88)), lineWidth: max(0.6, r * 0.18))
    }

    private func drawPedalFootswitch(ctx: GraphicsContext, center: CGPoint, radius r: CGFloat) {
        let nutR = r * 1.12
        var hex = Path()
        for i in 0..<6 {
            let ang = .pi / 3 * CGFloat(i) + .pi / 6
            let p = CGPoint(x: center.x + cos(ang) * nutR, y: center.y + sin(ang) * nutR)
            if i == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
        }
        hex.closeSubpath()
        ctx.fill(hex, with: .color(Color(red: 0.28, green: 0.28, blue: 0.30)))
        ctx.stroke(hex, with: .color(Color.black.opacity(0.55)), lineWidth: 0.4)
        let stompRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: stompRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.98),
                    Color(red: 0.60, green: 0.62, blue: 0.66),
                    Color(red: 0.22, green: 0.22, blue: 0.24)
                ]),
                center: CGPoint(x: center.x - r * 0.42, y: center.y - r * 0.42),
                startRadius: 0.2, endRadius: r * 1.1
            )
        )
        ctx.stroke(Path(ellipseIn: stompRect), with: .color(Color.black.opacity(0.45)), lineWidth: max(0.3, r * 0.06))
    }

    private func drawPedalLED(ctx: GraphicsContext, center: CGPoint, radius r: CGFloat, color: Color) {
        let bez = CGRect(x: center.x - r * 1.5, y: center.y - r * 1.5, width: r * 3, height: r * 3)
        ctx.fill(Path(ellipseIn: bez), with: .color(Color(red: 0.14, green: 0.14, blue: 0.16)))
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.92),
                    color,
                    color.opacity(0.5)
                ]),
                center: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.3),
                startRadius: 0.1, endRadius: r
            )
        )
    }

    // MARK: - Individual pedals

    private func drawPedalTS808(ctx: GraphicsContext, rect: CGRect) {
        drawPedalChassis(
            ctx: ctx, rect: rect,
            topColor: Color(red: 0.22, green: 0.62, blue: 0.38),
            botColor: Color(red: 0.12, green: 0.46, blue: 0.26)
        )
        let w = rect.width
        let h = rect.height
        drawPedalLED(
            ctx: ctx,
            center: CGPoint(x: rect.midX, y: rect.minY + h * 0.13),
            radius: max(0.8, w * 0.058),
            color: Color(red: 0.98, green: 0.36, blue: 0.20)
        )
        let knobR = max(1.6, w * 0.12)
        drawPedalKnob(
            ctx: ctx,
            center: CGPoint(x: rect.midX - w * 0.24, y: rect.minY + h * 0.28),
            radius: knobR, angle: .pi * 0.82
        )
        drawPedalKnob(
            ctx: ctx,
            center: CGPoint(x: rect.midX + w * 0.24, y: rect.minY + h * 0.28),
            radius: knobR, angle: .pi * 1.12
        )
        drawPedalKnob(
            ctx: ctx,
            center: CGPoint(x: rect.midX, y: rect.minY + h * 0.46),
            radius: knobR, angle: .pi * 0.70
        )
        let labelSize = max(3.5, w * 0.095)
        let label = Text("TUBE SCREAMER")
            .font(.system(size: labelSize, weight: .bold, design: .serif))
            .foregroundStyle(Color(red: 0.96, green: 0.92, blue: 0.78))
        ctx.draw(label, at: CGPoint(x: rect.midX, y: rect.minY + h * 0.63), anchor: .center)
        drawPedalFootswitch(
            ctx: ctx,
            center: CGPoint(x: rect.midX, y: rect.minY + h * 0.82),
            radius: max(2.2, w * 0.18)
        )
    }

    private func drawPedalBigSky(ctx: GraphicsContext, rect: CGRect) {
        drawStrymonChassis(
            ctx: ctx, rect: rect,
            topColor: Color(red: 0.36, green: 0.76, blue: 0.88),
            botColor: Color(red: 0.20, green: 0.56, blue: 0.72),
            script: "BigSky",
            scriptColor: Color(red: 0.98, green: 0.98, blue: 0.98)
        )
    }

    private func drawPedalTimeLine(ctx: GraphicsContext, rect: CGRect) {
        drawStrymonChassis(
            ctx: ctx, rect: rect,
            topColor: Color(red: 0.32, green: 0.34, blue: 0.36),
            botColor: Color(red: 0.16, green: 0.18, blue: 0.20),
            script: "TIMELINE",
            scriptColor: Color(red: 0.94, green: 0.94, blue: 0.92)
        )
    }

    private func drawStrymonChassis(
        ctx: GraphicsContext, rect: CGRect,
        topColor: Color, botColor: Color,
        script: String, scriptColor: Color
    ) {
        drawPedalChassis(ctx: ctx, rect: rect, topColor: topColor, botColor: botColor)
        let w = rect.width
        let h = rect.height
        let disp = CGRect(
            x: rect.minX + w * 0.10,
            y: rect.minY + h * 0.14,
            width: w * 0.30,
            height: h * 0.18
        )
        ctx.fill(
            Path(roundedRect: disp, cornerRadius: 1.2),
            with: .color(Color(red: 0.03, green: 0.03, blue: 0.05))
        )
        for i in 0..<3 {
            let cx = disp.minX + disp.width * (0.2 + CGFloat(i) * 0.3)
            let segH = max(2, disp.height * 0.52)
            let segW = max(0.8, w * 0.018)
            let seg = CGRect(
                x: cx - segW / 2,
                y: disp.midY - segH / 2,
                width: segW,
                height: segH
            )
            ctx.fill(
                Path(roundedRect: seg, cornerRadius: 0.4),
                with: .color(Color(red: 0.55, green: 0.88, blue: 1.0).opacity(0.80))
            )
        }
        let encC = CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.22)
        let encR = max(2.0, h * 0.085)
        let ringR = encR * 1.75
        for i in 0..<12 {
            let a = .pi * 2 / 12 * CGFloat(i) - .pi / 2
            let dotR: CGFloat = max(0.3, encR * 0.12)
            let p = CGPoint(x: encC.x + cos(a) * ringR, y: encC.y + sin(a) * ringR)
            let isLit = i < 7
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(
                    isLit
                        ? Color(red: 0.72, green: 0.94, blue: 1.0).opacity(0.85)
                        : Color.black.opacity(0.40)
                )
            )
        }
        drawPedalKnob(ctx: ctx, center: encC, radius: encR, angle: .pi * 0.35)
        let smKR = max(1.2, h * 0.055)
        let midY = rect.minY + h * 0.50
        for i in 0..<5 {
            let cx = rect.minX + w * (0.15 + CGFloat(i) * 0.175)
            drawPedalKnob(
                ctx: ctx,
                center: CGPoint(x: cx, y: midY),
                radius: smKR,
                angle: .pi * (0.65 + Double(i) * 0.11)
            )
        }
        let labelSize = max(3.5, h * 0.12)
        let label = Text(script)
            .font(.system(size: labelSize, weight: .semibold, design: .serif))
            .italic()
            .foregroundStyle(scriptColor)
        ctx.draw(label, at: CGPoint(x: rect.midX, y: rect.minY + h * 0.68), anchor: .center)
        let footR = max(1.8, h * 0.085)
        let footY = rect.minY + h * 0.84
        for i in 0..<3 {
            let cx = rect.minX + w * (0.22 + CGFloat(i) * 0.28)
            drawPedalLED(
                ctx: ctx,
                center: CGPoint(x: cx, y: footY - footR * 2.0),
                radius: max(0.5, footR * 0.22),
                color: i == 1 ? Color(red: 0.98, green: 0.38, blue: 0.18) : Color(red: 0.25, green: 0.25, blue: 0.27)
            )
            drawPedalFootswitch(
                ctx: ctx,
                center: CGPoint(x: cx, y: footY),
                radius: footR
            )
        }
    }

    private func drawPedalRAT(ctx: GraphicsContext, rect: CGRect) {
        drawPedalChassis(
            ctx: ctx, rect: rect,
            topColor: Color(red: 0.11, green: 0.11, blue: 0.12),
            botColor: Color(red: 0.04, green: 0.04, blue: 0.05)
        )
        let w = rect.width
        let h = rect.height
        let knobR = max(1.4, w * 0.10)
        let topY = rect.minY + h * 0.16
        let xs: [CGFloat] = [0.22, 0.50, 0.78]
        let angles: [Double] = [0.75, 0.95, 1.15]
        for i in 0..<3 {
            drawPedalKnob(
                ctx: ctx,
                center: CGPoint(x: rect.minX + w * xs[i], y: topY),
                radius: knobR,
                angle: .pi * CGFloat(angles[i])
            )
        }
        let labels = ["DIST", "FILT", "VOL"]
        let labelSize = max(2.5, w * 0.07)
        for i in 0..<3 {
            let boxW = w * 0.20
            let boxH = h * 0.05
            let boxC = CGPoint(x: rect.minX + w * xs[i], y: topY + knobR + boxH * 0.9)
            let box = CGRect(x: boxC.x - boxW / 2, y: boxC.y - boxH / 2, width: boxW, height: boxH)
            ctx.fill(Path(roundedRect: box, cornerRadius: 0.5), with: .color(Color(red: 0.93, green: 0.92, blue: 0.88)))
            let t = Text(labels[i])
                .font(.system(size: labelSize, weight: .heavy, design: .default))
                .foregroundStyle(Color(red: 0.06, green: 0.06, blue: 0.08))
            ctx.draw(t, at: boxC, anchor: .center)
        }
        drawPedalLED(
            ctx: ctx,
            center: CGPoint(x: rect.midX, y: rect.minY + h * 0.46),
            radius: max(0.6, w * 0.035),
            color: Color(red: 0.95, green: 0.24, blue: 0.18)
        )
        let logoSize = max(7, w * 0.34)
        let logo = Text("RAT")
            .font(.system(size: logoSize, weight: .black, design: .serif))
            .foregroundStyle(Color(red: 0.96, green: 0.96, blue: 0.94))
        ctx.draw(logo, at: CGPoint(x: rect.midX, y: rect.minY + h * 0.60), anchor: .center)
        drawPedalFootswitch(
            ctx: ctx,
            center: CGPoint(x: rect.midX, y: rect.minY + h * 0.82),
            radius: max(2.2, w * 0.18)
        )
    }

    private func drawPedalCentavo(ctx: GraphicsContext, rect: CGRect) {
        drawPedalChassis(
            ctx: ctx, rect: rect,
            topColor: Color(red: 0.90, green: 0.72, blue: 0.26),
            botColor: Color(red: 0.66, green: 0.48, blue: 0.14)
        )
        let w = rect.width
        let h = rect.height
        let knobR = max(1.6, h * 0.105)
        let topY = rect.minY + h * 0.28
        let knobXs: [CGFloat] = [0.15, 0.33, 0.51]
        let knobAngles: [Double] = [0.65, 0.82, 1.00]
        for i in 0..<3 {
            drawPedalKnob(
                ctx: ctx,
                center: CGPoint(x: rect.minX + w * knobXs[i], y: topY),
                radius: knobR,
                angle: .pi * CGFloat(knobAngles[i])
            )
        }
        drawPedalLED(
            ctx: ctx,
            center: CGPoint(x: rect.minX + w * 0.15, y: topY + knobR * 2.0),
            radius: max(0.5, h * 0.030),
            color: Color(red: 1.0, green: 0.72, blue: 0.22)
        )
        drawCentaurSilhouette(
            ctx: ctx,
            rect: CGRect(
                x: rect.minX + w * 0.60,
                y: rect.minY + h * 0.18,
                width: w * 0.34,
                height: h * 0.48
            )
        )
        let labelSize = max(3.5, h * 0.12)
        let label = Text("CENTAVO")
            .font(.system(size: labelSize, weight: .bold, design: .serif))
            .foregroundStyle(Color(red: 0.18, green: 0.12, blue: 0.04))
        ctx.draw(label, at: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.70), anchor: .center)
        drawPedalFootswitch(
            ctx: ctx,
            center: CGPoint(x: rect.midX, y: rect.minY + h * 0.84),
            radius: max(2.2, h * 0.12)
        )
    }

    private func drawCentaurSilhouette(ctx: GraphicsContext, rect: CGRect) {
        let ink = Color(red: 0.14, green: 0.10, blue: 0.03).opacity(0.88)
        let bodyRect = CGRect(
            x: rect.minX + rect.width * 0.12,
            y: rect.midY - rect.height * 0.10,
            width: rect.width * 0.70,
            height: rect.height * 0.38
        )
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(ink))
        let headR = rect.width * 0.13
        let headC = CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.14)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: headC.x - headR, y: headC.y - headR,
                width: headR * 2, height: headR * 2
            )),
            with: .color(ink)
        )
        var neck = Path()
        neck.move(to: CGPoint(x: headC.x + headR * 0.2, y: headC.y + headR * 0.5))
        neck.addLine(to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.15, y: bodyRect.minY + bodyRect.height * 0.30))
        ctx.stroke(neck, with: .color(ink), lineWidth: max(0.8, headR * 0.65))
        for i in 0..<4 {
            let legX = bodyRect.minX + bodyRect.width * (0.22 + CGFloat(i) * 0.20)
            var leg = Path()
            leg.move(to: CGPoint(x: legX, y: bodyRect.maxY - 1))
            leg.addLine(to: CGPoint(x: legX - rect.width * 0.015, y: rect.maxY - 1))
            ctx.stroke(leg, with: .color(ink), lineWidth: max(0.7, rect.width * 0.028))
        }
        var tail = Path()
        tail.move(to: CGPoint(x: bodyRect.maxX - 2, y: bodyRect.midY))
        tail.addQuadCurve(
            to: CGPoint(x: bodyRect.maxX + rect.width * 0.08, y: bodyRect.maxY - 1),
            control: CGPoint(x: bodyRect.maxX + rect.width * 0.12, y: bodyRect.midY + rect.height * 0.10)
        )
        ctx.stroke(tail, with: .color(ink), lineWidth: max(0.7, rect.width * 0.022))
    }

    // MARK: - Cabinet (wooden frame)
    private func drawCabinet(ctx: GraphicsContext, body: CGRect) {
        // Base wood: full-body gradient left-lit, right-shadow
        let path = Path(roundedRect: body, cornerRadius: 4)
        ctx.fill(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: woodHi,    location: 0.00),
                .init(color: woodFront, location: 0.42),
                .init(color: woodShad,  location: 0.82),
                .init(color: woodEdge,  location: 1.00)
            ]),
            startPoint: CGPoint(x: body.minX, y: body.minY),
            endPoint:   CGPoint(x: body.maxX, y: body.maxY + body.height * 0.3)
        ))

        // Vertical wood grain — subtle, only on visible wood margins
        drawWoodGrain(ctx: ctx, rect: body)

        // Top-edge highlight (1px lamp catch)
        var topEdge = Path()
        topEdge.move(to: CGPoint(x: body.minX + 2, y: body.minY + 0.5))
        topEdge.addLine(to: CGPoint(x: body.maxX - 2, y: body.minY + 0.5))
        ctx.stroke(topEdge, with: .color(Color.white.opacity(0.08)), lineWidth: 0.8)

        // Right-edge shadow crease
        var rightEdge = Path()
        rightEdge.move(to: CGPoint(x: body.maxX - 0.5, y: body.minY + 2))
        rightEdge.addLine(to: CGPoint(x: body.maxX - 0.5, y: body.maxY - 2))
        ctx.stroke(rightEdge, with: .color(Color.black.opacity(0.35)), lineWidth: 1)
    }

    private func drawWoodGrain(ctx: GraphicsContext, rect: CGRect) {
        // 纵向 grain（使用预计算表，避免每帧 RNG）
        for g in Self.woodGrainTable {
            let x = rect.minX + g.u * rect.width
            let a = g.alpha
            let j = g.jitter
            var p = Path()
            p.move(to: CGPoint(x: x, y: rect.minY + 2))
            p.addCurve(
                to: CGPoint(x: x + j, y: rect.maxY - 2),
                control1: CGPoint(x: x + j * 2,  y: rect.minY + rect.height * 0.35),
                control2: CGPoint(x: x - j * 1.5, y: rect.minY + rect.height * 0.7)
            )
            let tint: Color = g.u < 0.5
                ? Color.white.opacity(Double(a) * 0.5)
                : Color.black.opacity(Double(a))
            ctx.stroke(p, with: .color(tint), lineWidth: 0.5)
        }

        // 两颗节疤（knot）— 椭圆同心环，实现"真实木头"质感
        let knots: [(u: CGFloat, v: CGFloat, r: CGFloat)] = [
            (u: 0.22, v: 0.68, r: rect.height * 0.11),
            (u: 0.71, v: 0.28, r: rect.height * 0.08)
        ]
        for k in knots {
            let cx = rect.minX + k.u * rect.width
            let cy = rect.minY + k.v * rect.height
            // 4 圈同心椭圆（dark → lighter）
            for i in 0..<4 {
                let ringR = k.r * (1.0 - CGFloat(i) * 0.22)
                let ringRect = CGRect(
                    x: cx - ringR, y: cy - ringR * 0.58,
                    width: ringR * 2, height: ringR * 1.16
                )
                let a = 0.10 - Double(i) * 0.02
                ctx.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(Color.black.opacity(a)),
                    lineWidth: 0.55
                )
            }
            // 中心暗点（节疤核）
            let coreR: CGFloat = k.r * 0.14
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: cx - coreR, y: cy - coreR * 0.6,
                    width: coreR * 2, height: coreR * 1.2
                )),
                with: .color(woodEdge.opacity(0.65))
            )
        }
    }

    // MARK: - Control panel (static parts — base, brushed metal, bevels, knobs,
    // brand, labels, brass screws. No wave, no LED body — those live in dynamic.)
    private func drawControlPanelStatic(ctx: GraphicsContext, rect: CGRect, scope: CGRect, ledC: CGPoint) {
        let panelPath = Path(rect)

        // Base fill
        ctx.fill(panelPath, with: .linearGradient(
            Gradient(stops: [
                .init(color: panelHi.opacity(0.55), location: 0.0),
                .init(color: panelTop,              location: 0.15),
                .init(color: panelBot,              location: 1.0)
            ]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY),
            endPoint:   CGPoint(x: rect.midX, y: rect.maxY)
        ))

        // Brushed metal (precomputed)
        for bm in Self.brushedMetalTable {
            let y = rect.minY + bm.y * rect.height
            var line = Path()
            line.move(to: CGPoint(x: rect.minX + 4, y: y))
            line.addLine(to: CGPoint(x: rect.maxX - 4, y: y))
            ctx.stroke(line, with: .color(Color.white.opacity(Double(bm.alpha))), lineWidth: 0.3)
        }

        // Top bevel
        var topBevel = Path()
        topBevel.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + 0.5))
        topBevel.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + 0.5))
        ctx.stroke(topBevel, with: .color(Color.white.opacity(0.18)), lineWidth: 0.8)

        // Bottom bevel (dark crease into nameplate)
        var botBevel = Path()
        botBevel.move(to: CGPoint(x: rect.minX, y: rect.maxY - 0.5))
        botBevel.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 0.5))
        ctx.stroke(botBevel, with: .color(Color.black.opacity(0.5)), lineWidth: 1)

        let pad: CGFloat = rect.width * 0.028

        // POWER label (LED body drawn dynamically on top)
        drawSmallLabel(ctx: ctx, text: "POWER", at: CGPoint(x: ledC.x - 8, y: ledC.y), anchor: .trailing)

        // Brand text
        drawBrandLogo(
            ctx: ctx,
            at: CGPoint(x: rect.minX + pad + 2, y: rect.minY + pad + 5),
            size: rect.height * 0.10
        )

        // Knobs row 1 — 3 left / 3 right of CRT
        let knobR = min(rect.width * 0.032, rect.height * 0.09)
        let row1Y = scope.midY + 2
        let leftStart = rect.minX + pad + knobR + 4
        let leftEnd = scope.minX - pad
        for i in 0..<3 {
            let u = CGFloat(i) / 2.0
            let x = leftStart + u * (leftEnd - leftStart - knobR * 2) + knobR
            drawKnob(ctx: ctx, center: CGPoint(x: x, y: row1Y), radius: knobR, angle: knobAngle(seed: i))
            drawKnobLabel(ctx: ctx, text: ["GLIDE", "OSC", "MIX"][i], below: CGPoint(x: x, y: row1Y + knobR + 4))
        }
        let rightStart = scope.maxX + pad
        let rightEnd = rect.maxX - pad - knobR - 4
        for i in 0..<3 {
            let u = CGFloat(i) / 2.0
            let x = rightStart + u * (rightEnd - rightStart - knobR * 2) + knobR
            drawKnob(ctx: ctx, center: CGPoint(x: x, y: row1Y), radius: knobR, angle: knobAngle(seed: i + 3))
            drawKnobLabel(ctx: ctx, text: ["MOD", "LFO", "FX"][i], below: CGPoint(x: x, y: row1Y + knobR + 4))
        }

        // Knobs row 2 — 6 across
        let row2Y = rect.maxY - rect.height * 0.20
        let row2Start = rect.minX + pad + knobR + 4
        let row2End = rect.maxX - pad - knobR - 4
        let labels2 = ["CUTOFF", "RESO", "ATTACK", "DECAY", "SUSTAIN", "RELEASE"]
        for i in 0..<6 {
            let u = CGFloat(i) / 5.0
            let x = row2Start + u * (row2End - row2Start)
            drawKnob(ctx: ctx, center: CGPoint(x: x, y: row2Y), radius: knobR, angle: knobAngle(seed: i + 10))
            drawKnobLabel(ctx: ctx, text: labels2[i], below: CGPoint(x: x, y: row2Y + knobR + 4))
        }

        // Brass screws at 4 corners
        let screwInset: CGFloat = rect.width * 0.014
        let screwR: CGFloat = max(1.8, rect.height * 0.012)
        let corners: [CGPoint] = [
            CGPoint(x: rect.minX + screwInset,  y: rect.minY + screwInset),
            CGPoint(x: rect.maxX - screwInset,  y: rect.minY + screwInset),
            CGPoint(x: rect.minX + screwInset,  y: rect.maxY - screwInset),
            CGPoint(x: rect.maxX - screwInset,  y: rect.maxY - screwInset)
        ]
        let slotAngles: [CGFloat] = [0.35, -0.25, 0.18, -0.42]
        for (i, c) in corners.enumerated() {
            drawBrassScrew(ctx: ctx, center: c, radius: screwR, slotAngle: slotAngles[i])
        }
    }

    // MARK: - Brass screw (small, rim + radial gradient + slot)
    private func drawBrassScrew(ctx: GraphicsContext, center: CGPoint, radius r: CGFloat, slotAngle a: CGFloat) {
        // Recessed dark rim (adds depth)
        let outer = CGRect(x: center.x - r - 0.6, y: center.y - r - 0.6, width: (r + 0.6) * 2, height: (r + 0.6) * 2)
        ctx.fill(Path(ellipseIn: outer), with: .color(Color.black.opacity(0.55)))
        // Brass head with upper-left highlight
        let head = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: head),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.78, green: 0.62, blue: 0.32),
                    Color(red: 0.52, green: 0.40, blue: 0.18),
                    Color(red: 0.24, green: 0.18, blue: 0.08)
                ]),
                center: CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.35),
                startRadius: 0.2,
                endRadius: r * 1.15
            )
        )
        // Slot (single line, deterministic angle)
        let sx = cos(a) * r * 0.75
        let sy = sin(a) * r * 0.75
        var slot = Path()
        slot.move(to: CGPoint(x: center.x - sx, y: center.y - sy))
        slot.addLine(to: CGPoint(x: center.x + sx, y: center.y + sy))
        ctx.stroke(slot, with: .color(Color.black.opacity(0.75)), lineWidth: max(0.6, r * 0.22))
    }

    // CRT static parts — bezel, screen bg, grid, outer stroke, 4 bezel screws
    private func drawOscilloscopeStatic(ctx: GraphicsContext, rect: CGRect) {
        let bezel = Path(roundedRect: rect, cornerRadius: 2)
        ctx.fill(bezel, with: .color(panelEdge))
        let screen = rect.insetBy(dx: 2, dy: 2)
        let screenPath = Path(roundedRect: screen, cornerRadius: 1)
        ctx.fill(screenPath, with: .linearGradient(
            Gradient(colors: [Color(red: 0.02, green: 0.06, blue: 0.03),
                              Color(red: 0.01, green: 0.03, blue: 0.015)]),
            startPoint: CGPoint(x: screen.minX, y: screen.minY),
            endPoint:   CGPoint(x: screen.maxX, y: screen.maxY)
        ))

        // Faint grid
        let gridH = 3
        let gridV = 5
        for i in 1..<gridH {
            let y = screen.minY + CGFloat(i) / CGFloat(gridH) * screen.height
            var p = Path()
            p.move(to: CGPoint(x: screen.minX, y: y))
            p.addLine(to: CGPoint(x: screen.maxX, y: y))
            ctx.stroke(p, with: .color(scopeGreen.opacity(0.08)), lineWidth: 0.3)
        }
        for i in 1..<gridV {
            let x = screen.minX + CGFloat(i) / CGFloat(gridV) * screen.width
            var p = Path()
            p.move(to: CGPoint(x: x, y: screen.minY))
            p.addLine(to: CGPoint(x: x, y: screen.maxY))
            ctx.stroke(p, with: .color(scopeGreen.opacity(0.08)), lineWidth: 0.3)
        }

        // Bezel outer stroke
        ctx.stroke(bezel, with: .color(panelHi.opacity(0.4)), lineWidth: 0.8)

        // 4 bezel screws (chrome-style)
        let bsInset: CGFloat = 2.8
        let bsR: CGFloat = max(1.1, rect.height * 0.05)
        let bsCorners: [CGPoint] = [
            CGPoint(x: rect.minX + bsInset, y: rect.minY + bsInset),
            CGPoint(x: rect.maxX - bsInset, y: rect.minY + bsInset),
            CGPoint(x: rect.minX + bsInset, y: rect.maxY - bsInset),
            CGPoint(x: rect.maxX - bsInset, y: rect.maxY - bsInset)
        ]
        let bsAngles: [CGFloat] = [0.28, -0.34, 0.11, -0.22]
        for (i, c) in bsCorners.enumerated() {
            let outer = CGRect(x: c.x - bsR - 0.4, y: c.y - bsR - 0.4, width: (bsR + 0.4) * 2, height: (bsR + 0.4) * 2)
            ctx.fill(Path(ellipseIn: outer), with: .color(Color.black.opacity(0.65)))
            let head = CGRect(x: c.x - bsR, y: c.y - bsR, width: bsR * 2, height: bsR * 2)
            ctx.fill(
                Path(ellipseIn: head),
                with: .radialGradient(
                    Gradient(colors: [knobChrome.opacity(0.9), panelHi, Color.black.opacity(0.7)]),
                    center: CGPoint(x: c.x - bsR * 0.3, y: c.y - bsR * 0.3),
                    startRadius: 0.1, endRadius: bsR * 1.1
                )
            )
            let a = bsAngles[i]
            let sx = cos(a) * bsR * 0.7
            let sy = sin(a) * bsR * 0.7
            var slot = Path()
            slot.move(to: CGPoint(x: c.x - sx, y: c.y - sy))
            slot.addLine(to: CGPoint(x: c.x + sx, y: c.y + sy))
            ctx.stroke(slot, with: .color(Color.black.opacity(0.8)), lineWidth: max(0.4, bsR * 0.25))
        }
    }

    // CRT dynamic — waveform + (大图) scanline + glass specular.
    // Specular sits above phosphor + scanline so it's drawn last.
    private func drawOscilloscopeDynamic(ctx: GraphicsContext, rect: CGRect, t: TimeInterval, midLvl: CGFloat, zc: CGFloat) {
        let screen = rect.insetBy(dx: 2, dy: 2)

        // Waveform — amp=0 when silent → flat centerline
        let amp = screen.height * 0.38 * midLvl
        let steps = 80
        var wave = Path()
        for i in 0...steps {
            let u = CGFloat(i) / CGFloat(steps)
            let x = screen.minX + 1 + u * (screen.width - 2)
            let phase = CGFloat(t) * 2.4 + u * 10
            let y = screen.midY + sin(phase) * amp * (0.55 + 0.45 * sin(phase * 1.73 + 0.7))
            if i == 0 { wave.move(to: CGPoint(x: x, y: y)) }
            else      { wave.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(wave, with: .color(scopeGreen.opacity(0.25)), lineWidth: 3.5)
        ctx.stroke(wave, with: .color(scopeGreen.opacity(0.55)), lineWidth: 1.8)
        ctx.stroke(wave, with: .color(scopeGreen), lineWidth: 0.8)

        // 大图专属：CRT 扫描线（真正的老显像管质感）— 小图屏幕太小看不清所以不做
        if zc > 0.3 {
            let scanCount = 22
            let scanAlpha = 0.14 * Double(zc)
            for i in 0..<scanCount {
                let u = CGFloat(i) / CGFloat(scanCount - 1)
                let y = screen.minY + u * screen.height
                var p = Path()
                p.move(to: CGPoint(x: screen.minX, y: y))
                p.addLine(to: CGPoint(x: screen.maxX, y: y))
                ctx.stroke(p, with: .color(Color.black.opacity(scanAlpha)), lineWidth: 0.4)
            }
        }

        // Diagonal glass specular — top pass so it sits above phosphor + scanline
        ctx.fill(
            Path(screen),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.12), location: 0.0),
                    .init(color: Color.white.opacity(0.04), location: 0.35),
                    .init(color: Color.clear,              location: 0.65)
                ]),
                startPoint: CGPoint(x: screen.minX, y: screen.minY),
                endPoint:   CGPoint(x: screen.maxX, y: screen.maxY)
            )
        )
    }

    private func drawPowerLED(ctx: GraphicsContext, center: CGPoint, bassLvl: CGFloat) {
        let glow = 0.35 + bassLvl * 0.65
        // Halo
        let haloR: CGFloat = 12
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - haloR, y: center.y - haloR, width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [ledRed.opacity(glow * 0.55), ledRed.opacity(0.0)]),
                center: center, startRadius: 0.5, endRadius: haloR
            )
        )
        // Recessed dark socket (adds depth — LED sits in a tiny hole)
        let socketR: CGFloat = 4.2
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - socketR, y: center.y - socketR, width: socketR * 2, height: socketR * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.35)]),
                center: CGPoint(x: center.x + 0.4, y: center.y + 0.4),
                startRadius: 0.2, endRadius: socketR
            )
        )
        // LED body (red dome)
        let r: CGFloat = 2.8
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    ledRed.opacity(1.0),
                    Color(red: 0.75, green: 0.20, blue: 0.15).opacity(0.90 + glow * 0.10),
                    Color(red: 0.40, green: 0.08, blue: 0.06).opacity(0.75)
                ]),
                center: CGPoint(x: center.x + 0.2, y: center.y + 0.2),
                startRadius: 0, endRadius: r * 1.3
            )
        )
        // Glass dome crescent highlight (upper-left, the single-light-source signature)
        let crescentRect = CGRect(x: center.x - r * 0.75, y: center.y - r * 0.75, width: r * 0.55, height: r * 0.55)
        ctx.fill(
            Path(ellipseIn: crescentRect),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.85 + glow * 0.15), Color.white.opacity(0.0)]),
                center: CGPoint(x: crescentRect.midX, y: crescentRect.midY),
                startRadius: 0, endRadius: r * 0.5
            )
        )
        // Bezel ring (chrome rim around socket)
        let ring = Path(ellipseIn: CGRect(x: center.x - r - 1.6, y: center.y - r - 1.6, width: (r + 1.6) * 2, height: (r + 1.6) * 2))
        ctx.stroke(ring, with: .color(knobChrome.opacity(0.55)), lineWidth: 0.6)
        let ringInner = Path(ellipseIn: CGRect(x: center.x - r - 0.8, y: center.y - r - 0.8, width: (r + 0.8) * 2, height: (r + 0.8) * 2))
        ctx.stroke(ringInner, with: .color(Color.black.opacity(0.7)), lineWidth: 0.6)
    }

    private func drawBrandLogo(ctx: GraphicsContext, at origin: CGPoint, size: CGFloat) {
        let text = Text("S I M O N E")
            .font(.system(size: size * 0.70, weight: .medium, design: .serif))
            .kerning(size * 0.25)
            .foregroundColor(namplateHi.opacity(0.7))
        ctx.draw(text, at: origin, anchor: .topLeading)
        let sub = Text("analog voice")
            .font(.system(size: size * 0.40, weight: .regular, design: .serif).italic())
            .foregroundColor(namplateHi.opacity(0.38))
        ctx.draw(sub, at: CGPoint(x: origin.x, y: origin.y + size * 0.85), anchor: .topLeading)
    }

    private func drawSmallLabel(ctx: GraphicsContext, text: String, at point: CGPoint, anchor: UnitPoint) {
        let t = Text(text)
            .font(.system(size: 7, weight: .semibold, design: .default))
            .kerning(0.5)
            .foregroundColor(Color.white.opacity(0.35))
        ctx.draw(t, at: point, anchor: anchor)
    }

    private func drawKnobLabel(ctx: GraphicsContext, text: String, below point: CGPoint) {
        let t = Text(text)
            .font(.system(size: 6, weight: .medium, design: .default))
            .kerning(0.4)
            .foregroundColor(Color.white.opacity(0.30))
        ctx.draw(t, at: point, anchor: .center)
    }

    // MARK: - Nameplate strip
    private func drawNameplate(ctx: GraphicsContext, rect: CGRect) {
        // Base metallic brass band
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [
                .init(color: nameplate.opacity(0.4), location: 0.0),
                .init(color: namplateHi,             location: 0.15),
                .init(color: nameplate,              location: 0.50),
                .init(color: namplateHi.opacity(0.7),location: 0.80),
                .init(color: nameplate.opacity(0.5), location: 1.0)
            ]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint:   CGPoint(x: rect.minX, y: rect.maxY)
        ))
        // Thin dark top/bottom edges (bezel)
        var top = Path()
        top.move(to: CGPoint(x: rect.minX, y: rect.minY + 0.5))
        top.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 0.5))
        ctx.stroke(top, with: .color(Color.black.opacity(0.5)), lineWidth: 0.8)

        var bot = Path()
        bot.move(to: CGPoint(x: rect.minX, y: rect.maxY - 0.5))
        bot.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 0.5))
        ctx.stroke(bot, with: .color(Color.black.opacity(0.55)), lineWidth: 0.8)

        // Model text — engraved effect (highlight offset up + dark text + shadow offset down)
        let labelString = "MODEL  SI-01  ·  ANALOG VOICE"
        let fontSize = rect.height * 0.42
        let kerning = rect.height * 0.10
        // 1) Highlight (one pixel below, very subtle — makes text appear recessed)
        let hl = Text(labelString)
            .font(.system(size: fontSize, weight: .medium, design: .serif))
            .kerning(kerning)
            .foregroundColor(Color.white.opacity(0.25))
        ctx.draw(hl, at: CGPoint(x: rect.midX, y: rect.midY + 0.6), anchor: .center)
        // 2) Engraved dark text (main)
        let label = Text(labelString)
            .font(.system(size: fontSize, weight: .medium, design: .serif))
            .kerning(kerning)
            .foregroundColor(Color.black.opacity(0.72))
        ctx.draw(label, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    // MARK: - Keyboard
    private func drawKeyboard(ctx: GraphicsContext, rect: CGRect) {
        // Dark well behind keys (front lip shadow)
        let wellInset: CGFloat = 1.5
        let well = rect.insetBy(dx: wellInset, dy: 0)
        ctx.fill(Path(well), with: .color(keyBlackLo))

        let whiteCount = 14
        let gap: CGFloat = 0.8
        let totalW = well.width - gap * CGFloat(whiteCount + 1)
        let whiteW = totalW / CGFloat(whiteCount)

        // White keys
        for i in 0..<whiteCount {
            let x = well.minX + gap + CGFloat(i) * (whiteW + gap)
            let keyRect = CGRect(x: x, y: well.minY + 1, width: whiteW, height: well.height - 2)
            let keyPath = Path(roundedRect: keyRect, cornerRadius: 1)
            ctx.fill(keyPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: keyWhiteTop, location: 0.0),
                    .init(color: keyWhiteTop, location: 0.70),
                    .init(color: keyWhiteLo,  location: 1.0)
                ]),
                startPoint: CGPoint(x: keyRect.minX, y: keyRect.minY),
                endPoint:   CGPoint(x: keyRect.minX, y: keyRect.maxY)
            ))
            // right-edge darker seam (key-to-key)
            var seam = Path()
            seam.move(to: CGPoint(x: keyRect.maxX, y: keyRect.minY + 2))
            seam.addLine(to: CGPoint(x: keyRect.maxX, y: keyRect.maxY - 2))
            ctx.stroke(seam, with: .color(Color.black.opacity(0.15)), lineWidth: 0.4)
        }

        // Front lip shadow (top 8% is darker — key shelf coming from inside)
        let lipH = well.height * 0.08
        let lip = CGRect(x: well.minX, y: well.minY, width: well.width, height: lipH)
        ctx.fill(Path(lip), with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)]),
            startPoint: CGPoint(x: 0, y: lip.minY),
            endPoint:   CGPoint(x: 0, y: lip.maxY)
        ))

        // Black keys: in a 7-white-octave, blacks sit after index 0,1,3,4,5
        // Across 14 whites we place blacks at white-index i where (i % 7) ∈ {0,1,3,4,5}
        let blackSet: Set<Int> = [0, 1, 3, 4, 5]
        let blackW = whiteW * 0.58
        let blackH = well.height * 0.62
        for i in 0..<whiteCount {
            guard blackSet.contains(i % 7) else { continue }
            // black key straddles the gap between white i and white i+1
            let xWhite = well.minX + gap + CGFloat(i) * (whiteW + gap)
            let xCenter = xWhite + whiteW + gap / 2
            let kr = CGRect(x: xCenter - blackW / 2, y: well.minY + 1, width: blackW, height: blackH)
            let kp = Path(roundedRect: kr, cornerRadius: 1)
            ctx.fill(kp, with: .linearGradient(
                Gradient(stops: [
                    .init(color: keyBlackTop, location: 0.0),
                    .init(color: keyBlackLo,  location: 0.85),
                    .init(color: keyBlackTop.opacity(0.6), location: 1.0)
                ]),
                startPoint: CGPoint(x: kr.minX, y: kr.minY),
                endPoint:   CGPoint(x: kr.minX, y: kr.maxY)
            ))
            // tiny top highlight
            var hl = Path()
            hl.move(to: CGPoint(x: kr.minX + 1, y: kr.minY + 1.5))
            hl.addLine(to: CGPoint(x: kr.maxX - 1, y: kr.minY + 1.5))
            ctx.stroke(hl, with: .color(Color.white.opacity(0.10)), lineWidth: 0.5)
        }
    }

    // MARK: - Knob drawing (front-elevation, chrome rim + dark body + indicator)
    private func drawKnob(ctx: GraphicsContext, center: CGPoint, radius r: CGFloat, angle: CGFloat) {
        // Outer rim chrome
        let rimRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rimRect), with: .linearGradient(
            Gradient(colors: [
                knobChrome.opacity(0.95),
                knobChrome.opacity(0.55),
                Color.black.opacity(0.5)
            ]),
            startPoint: CGPoint(x: rimRect.minX + r * 0.3, y: rimRect.minY + r * 0.3),
            endPoint:   CGPoint(x: rimRect.maxX, y: rimRect.maxY)
        ))

        // Inner body
        let inR = r * 0.78
        let inRect = CGRect(x: center.x - inR, y: center.y - inR, width: inR * 2, height: inR * 2)
        ctx.fill(Path(ellipseIn: inRect), with: .radialGradient(
            Gradient(colors: [
                Color(red: 0.18, green: 0.18, blue: 0.20),
                knobBody,
                Color(red: 0.02, green: 0.02, blue: 0.03)
            ]),
            center: CGPoint(x: center.x - inR * 0.35, y: center.y - inR * 0.35),
            startRadius: 0.5, endRadius: inR * 1.1
        ))

        // Knurling (24 fine tick marks on rim — luxury feel)
        for i in 0..<24 {
            let a = CGFloat(i) / 24 * 2 * .pi
            let x1 = center.x + cos(a) * r * 0.97
            let y1 = center.y + sin(a) * r * 0.97
            let x2 = center.x + cos(a) * r * 0.85
            let y2 = center.y + sin(a) * r * 0.85
            var p = Path()
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
            ctx.stroke(p, with: .color(Color.black.opacity(0.28)), lineWidth: 0.35)
        }

        // Chrome specular arc: upper-left crescent on rim (single light top-left)
        let rimPath = Path { p in
            let rect = CGRect(x: center.x - r * 0.96, y: center.y - r * 0.96, width: r * 1.92, height: r * 1.92)
            p.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: r * 0.96,
                startAngle: .degrees(195),
                endAngle: .degrees(310),
                clockwise: false
            )
        }
        ctx.stroke(rimPath, with: .color(Color.white.opacity(0.35)), lineWidth: max(0.7, r * 0.08))
        // Secondary soft inner highlight (body top-left)
        let innerHL = Path { p in
            p.addArc(
                center: center,
                radius: r * 0.58,
                startAngle: .degrees(205),
                endAngle: .degrees(285),
                clockwise: false
            )
        }
        ctx.stroke(innerHL, with: .color(Color.white.opacity(0.14)), lineWidth: max(0.6, r * 0.10))

        // Indicator line
        let iStart = r * 0.25
        let iEnd = r * 0.72
        let ax = cos(angle), ay = sin(angle)
        var ind = Path()
        ind.move(to: CGPoint(x: center.x + ax * iStart, y: center.y + ay * iStart))
        ind.addLine(to: CGPoint(x: center.x + ax * iEnd, y: center.y + ay * iEnd))
        ctx.stroke(ind, with: .color(indicator), lineWidth: max(1.2, r * 0.10))

        // Center cap
        let capR = r * 0.12
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - capR, y: center.y - capR, width: capR * 2, height: capR * 2)),
            with: .color(Color.black.opacity(0.6))
        )
    }

    private func knobAngle(seed: Int) -> CGFloat {
        // Deterministic but varied: -135° to +135° (3/4 arc), from the seed
        let steps = [0.15, 0.30, 0.45, 0.55, 0.62, 0.70, 0.80, 0.35, 0.50, 0.65, 0.25, 0.72, 0.40, 0.58, 0.33]
        let u = CGFloat(steps[seed % steps.count])
        let start = CGFloat(Double.pi) * 0.75   // 135°
        let end   = CGFloat(Double.pi) * 2.25   // 405° = 45°
        let a = start + (end - start) * u
        return a
    }

    // MARK: - Ground shadow
    private func drawGroundShadow(ctx: GraphicsContext, under body: CGRect, alpha: CGFloat = 1) {
        guard alpha > 0.001 else { return }
        let sRect = CGRect(
            x: body.minX + body.width * 0.04,
            y: body.maxY + body.height * 0.02,
            width: body.width * 0.92,
            height: body.height * 0.07
        )
        ctx.fill(
            Path(ellipseIn: sRect),
            with: .radialGradient(
                Gradient(colors: [Color.black.opacity(0.55 * Double(alpha)), Color.black.opacity(0.0)]),
                center: CGPoint(x: sRect.midX, y: sRect.midY),
                startRadius: 0,
                endRadius: sRect.width / 2
            )
        )
    }

    // MARK: - smoothstep
    private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    // MARK: - Precomputed tables (deterministic, run once, no per-frame RNG)
    fileprivate static let woodGrainTable: [(u: CGFloat, alpha: CGFloat, jitter: CGFloat)] = {
        var rng = SeededRNG(seed: 0x6D09)
        var arr = [(u: CGFloat, alpha: CGFloat, jitter: CGFloat)]()
        for _ in 0..<48 {
            let u = CGFloat(rng.uniform())
            let alpha = CGFloat(0.03 + rng.uniform() * 0.06)
            let j = CGFloat((rng.uniform() - 0.5) * 2.0)
            arr.append((u: u, alpha: alpha, jitter: j))
        }
        return arr
    }()

    fileprivate static let brushedMetalTable: [(y: CGFloat, alpha: CGFloat)] = {
        var rng = SeededRNG(seed: 0x4E17)
        var arr = [(y: CGFloat, alpha: CGFloat)]()
        for _ in 0..<90 {
            arr.append((
                y: CGFloat(rng.uniform()),
                alpha: CGFloat(0.015 + rng.uniform() * 0.035)
            ))
        }
        return arr
    }()
}

// MARK: - Deterministic RNG (no per-frame jitter)
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state ^= state &<< 13
        state ^= state &>> 7
        state ^= state &<< 17
        return state
    }
    mutating func uniform() -> Double {
        Double(next() & 0xFFFFFF) / Double(0x1000000)
    }
}

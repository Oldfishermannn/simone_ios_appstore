import SwiftUI

// Lo-fi visualizer — Boom Bap Drum Pad.
//
// Object: 一台简化 MPC 采样垫，2×2 橡胶垫阵。bass→kick 垫（左下），snare
// →左上，hi-hat→右上，perc→右下。垫被音击触发时边缘 LED 发光并轻微压扁。
// 底壳 matte 黑，四角黄铜螺丝，BPM 指示灯在顶部。Lo-fi hip-hop 的实体工具。
//
// Palette（OKLCH → sRGB 近似）:
//   bodyDark   oklch(0.18 0.01 55) → rgb( 24,  22,  20)  matte black warm
//   bodyEdge   oklch(0.26 0.02 55) → rgb( 42,  36,  30)
//   padBlank   oklch(0.36 0.02 55) → rgb( 62,  54,  46)  橡胶垫
//   padDepth   oklch(0.20 0.02 55) → rgb( 32,  28,  24)
//   brass      oklch(0.68 0.12 75) → rgb(188, 146,  72)
//   ledKick    oklch(0.76 0.16 60) → rgb(248, 148,  56)  琥珀
//   ledSnare   oklch(0.87 0.07 80) → rgb(240, 214, 142)  淡金
//   ledHat     oklch(0.82 0.06 230)→ rgb(156, 200, 220)  冷青
//   ledPerc    oklch(0.75 0.08 0)  → rgb(218, 166, 180)  薄玫瑰
struct LofiPadView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderPads(context: context, size: size, binCount: binCount)
        }
    }

    private func renderPads(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let isBig = density > 1

        let bodyDark  = Color(red:  24/255, green:  22/255, blue:  20/255)
        let bodyEdge  = Color(red:  42/255, green:  36/255, blue:  30/255)
        let padBlank  = Color(red:  62/255, green:  54/255, blue:  46/255)
        let padDepth  = Color(red:  32/255, green:  28/255, blue:  24/255)
        let brass     = Color(red: 188/255, green: 146/255, blue:  72/255)
        let ledKick   = Color(red: 248/255, green: 148/255, blue:  56/255)
        let ledSnare  = Color(red: 240/255, green: 214/255, blue: 142/255)
        let ledHat    = Color(red: 156/255, green: 200/255, blue: 220/255)
        let ledPerc   = Color(red: 218/255, green: 166/255, blue: 180/255)

        // 频段能量（每个 pad 一段）
        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)

        func energy(start: Double, end: Double) -> Float {
            let s = max(0, Int(start * Double(binCount - 1)))
            let e = min(binCount - 1, Int(end * Double(binCount - 1)))
            guard e > s else { return 0 }
            var sum: Float = 0
            for i in s...e { sum += spectrumData[i] }
            return sum / Float(e - s + 1)
        }
        let eKick  = energy(start: 0.00, end: 0.15)
        let eSnare = energy(start: 0.15, end: 0.35)
        let eHat   = energy(start: 0.55, end: 0.80)
        let ePerc  = energy(start: 0.80, end: 1.00)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // 大图画桌面暖晕，小图透明
        if isBig {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: Color(red: 50/255, green: 36/255, blue: 24/255).opacity(0.55), location: 0),
                                .init(color: Color(red: 22/255, green: 18/255, blue: 14/255), location: 0.7),
                                .init(color: Color(red: 22/255, green: 18/255, blue: 14/255), location: 1)
                            ]),
                            center: CGPoint(x: w * 0.28, y: h * 0.20),
                            startRadius: 0, endRadius: max(w, h) * 0.95
                         ))
        }

        let bodyW: CGFloat = w * (isBig ? 0.50 : 0.78)
        let bodyH: CGFloat = bodyW * 0.88
        let bodyX: CGFloat = (w - bodyW) / 2
        let bodyY: CGFloat = (h - bodyH) / 2
        let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH)

        // 设备底壳（带上下渐变）
        context.fill(Path(roundedRect: bodyRect, cornerRadius: bodyW * 0.04),
                     with: .linearGradient(
                        Gradient(colors: [bodyEdge, bodyDark]),
                        startPoint: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
                        endPoint: CGPoint(x: bodyRect.midX, y: bodyRect.maxY)
                     ))

        // 内缘凹进阴影
        let innerRect = bodyRect.insetBy(dx: 3, dy: 3)
        context.stroke(Path(roundedRect: innerRect, cornerRadius: bodyW * 0.035),
                       with: .color(padDepth), lineWidth: 1)

        // 顶缘极细高光
        var topHL = Path()
        topHL.move(to: CGPoint(x: bodyRect.minX + bodyW * 0.08, y: bodyRect.minY + 2))
        topHL.addLine(to: CGPoint(x: bodyRect.maxX - bodyW * 0.08, y: bodyRect.minY + 2))
        context.stroke(topHL, with: .color(Color.white.opacity(0.06)), lineWidth: 0.6)

        // 四角黄铜螺丝
        let screwInsets: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for (dx, dy) in screwInsets {
            let sx = bodyRect.midX + dx * bodyW * 0.43
            let sy = bodyRect.midY + dy * bodyH * 0.41
            let sr: CGFloat = 2.8
            let sRect = CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)
            context.fill(Path(ellipseIn: sRect),
                         with: .radialGradient(
                            Gradient(colors: [brass.opacity(0.95), brass.opacity(0.55)]),
                            center: CGPoint(x: sx - sr * 0.3, y: sy - sr * 0.3),
                            startRadius: 0, endRadius: sr
                         ))
            var slit = Path()
            slit.move(to: CGPoint(x: sx - sr + 1, y: sy))
            slit.addLine(to: CGPoint(x: sx + sr - 1, y: sy))
            context.stroke(slit, with: .color(bodyDark), lineWidth: 0.7)
        }

        // BPM 指示灯（仅大图）— 顶部 3 颗小黄铜点慢闪
        if isBig {
            let stripY = bodyRect.minY + bodyH * 0.08
            for i in 0..<3 {
                let dotX = bodyRect.midX - 16 + CGFloat(i) * 16
                let pulseRaw = 0.3 + (1 + sinf(t * 1.4 + Float(i) * 0.8)) * 0.25
                let pulse = Double(pulseRaw)
                let r: CGFloat = 2.0
                let dotRect = CGRect(x: dotX - r, y: stripY - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: dotRect),
                             with: .color(brass.opacity(pulse)))
            }
        }

        // Pad 阵（2×2）
        let padArea = bodyRect.insetBy(dx: bodyW * 0.10, dy: bodyH * 0.14)
                              .offsetBy(dx: 0, dy: bodyH * 0.02)
        let padSize: CGFloat = min(padArea.width, padArea.height) * 0.44
        let gap: CGFloat = padArea.width * 0.06
        let totalW: CGFloat = padSize * 2 + gap
        let totalH: CGFloat = padSize * 2 + gap
        let padX0: CGFloat = padArea.midX - totalW / 2
        let padY0: CGFloat = padArea.midY - totalH / 2

        struct PadCell {
            let col: Int
            let row: Int
            let energy: Float
            let color: Color
        }
        let pads: [PadCell] = [
            PadCell(col: 0, row: 0, energy: eSnare, color: ledSnare),
            PadCell(col: 1, row: 0, energy: eHat,   color: ledHat),
            PadCell(col: 0, row: 1, energy: eKick,  color: ledKick),
            PadCell(col: 1, row: 1, energy: ePerc,  color: ledPerc),
        ]

        for pad in pads {
            let px = padX0 + CGFloat(pad.col) * (padSize + gap)
            let py = padY0 + CGFloat(pad.row) * (padSize + gap)
            let padRect = CGRect(x: px, y: py, width: padSize, height: padSize)

            // 触发强度：把 energy 做阈值映射到 0..1
            let triggerRaw = Float(max(0, (pad.energy - 0.04) / 0.22)) * (1 - idleBlend)
            let trigger = CGFloat(min(triggerRaw, 1))

            // 压扁比例（触发越强越压扁 3%）
            let scale: CGFloat = 1 - trigger * 0.03
            let shrinkX: CGFloat = padSize * (1 - scale) / 2
            let shrinkY: CGFloat = padSize * (1 - scale) / 2
            let padDraw = padRect.insetBy(dx: shrinkX, dy: shrinkY)

            // pad 本体
            let padPath = Path(roundedRect: padDraw, cornerRadius: padSize * 0.14)
            let brightness: Double = 0.95 + Double(trigger) * 0.15
            context.fill(padPath,
                         with: .linearGradient(
                            Gradient(colors: [
                                padBlank.opacity(brightness),
                                padDepth
                            ]),
                            startPoint: CGPoint(x: padDraw.midX, y: padDraw.minY),
                            endPoint: CGPoint(x: padDraw.midX, y: padDraw.maxY)
                         ))

            // LED rim（触发强时发光，静默时呼吸）
            let idleBreath: Double = Double(idleBlend) * (0.08 + 0.08 * Double(sinf(t * 0.9 + Float(pad.col + pad.row * 2))))
            let rimAlpha = 0.22 + Double(trigger) * 0.65 + idleBreath
            let rimPath = Path(roundedRect: padDraw.insetBy(dx: 2.2, dy: 2.2),
                               cornerRadius: padSize * 0.12)
            context.stroke(rimPath,
                           with: .color(pad.color.opacity(rimAlpha)),
                           lineWidth: 1.4)

            // 触发光晕（trigger > 0.08 才画）
            if trigger > 0.08 {
                let bloomR: CGFloat = padSize * (0.55 + trigger * 0.55)
                let bloomRect = CGRect(
                    x: padDraw.midX - bloomR,
                    y: padDraw.midY - bloomR,
                    width: bloomR * 2,
                    height: bloomR * 2
                )
                context.fill(Path(ellipseIn: bloomRect),
                             with: .radialGradient(
                                Gradient(colors: [
                                    pad.color.opacity(Double(trigger) * 0.5),
                                    pad.color.opacity(0)
                                ]),
                                center: CGPoint(x: padDraw.midX, y: padDraw.midY),
                                startRadius: padSize * 0.26,
                                endRadius: bloomR
                             ))
            }

            // pad 顶缘极细高光
            var padHL = Path()
            padHL.move(to: CGPoint(x: padDraw.minX + padSize * 0.16, y: padDraw.minY + 3))
            padHL.addLine(to: CGPoint(x: padDraw.maxX - padSize * 0.16, y: padDraw.minY + 3))
            context.stroke(padHL, with: .color(Color.white.opacity(0.07)), lineWidth: 0.6)
        }
    }
}

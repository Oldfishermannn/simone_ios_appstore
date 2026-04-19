import SwiftUI

// Lo-fi visualizer — Venetian Blinds "After-Hours".
//
// Object: 2am 卧室的百叶窗，从里往外看，缝隙透出外面都市雾光。每条缝隙
// 映射一段频谱（顶 = 低频，底 = 高频），缝里漂着冷紫→夜琥珀的城市渐变，
// 中频驱动这渐变的横向慢漂。窗框不画，slat 自然在 canvas 中部停住，上下
// 留透明边，不成框。
//
// Palette（OKLCH → sRGB 近似）:
//   slat        oklch(0.22 0.015 250) → rgb( 28,  30,  38)  冷深灰
//   slatEdge    oklch(0.12 0.010 250) → rgb( 14,  16,  22)
//   slatRim     oklch(0.68 0.10 70)   → rgb(192, 156, 112)  侧光暖鳍
//   cityCool    oklch(0.50 0.08 270)  → rgb( 98, 108, 148)  雾蓝
//   cityMid     oklch(0.44 0.06 310)  → rgb(116, 100, 132)  紫暮
//   cityWarm    oklch(0.74 0.12 65)   → rgb(220, 170, 120)  钠灯琥珀
struct LofiBlindsView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderBlinds(context: context, size: size, binCount: binCount)
        }
    }

    private func renderBlinds(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let isBig = density > 1

        let slat     = Color(red:  28/255, green:  30/255, blue:  38/255)
        let slatEdge = Color(red:  14/255, green:  16/255, blue:  22/255)
        let slatRim  = Color(red: 192/255, green: 156/255, blue: 112/255)
        let cityCool = Color(red:  98/255, green: 108/255, blue: 148/255)
        let cityMid  = Color(red: 116/255, green: 100/255, blue: 132/255)
        let cityWarm = Color(red: 220/255, green: 170/255, blue: 120/255)

        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let thirds = binCount / 3
        var bass: Float = 0, mid: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        for i in thirds..<(2 * thirds) { mid += spectrumData[i] }
        bass /= Float(thirds)
        mid /= Float(thirds)

        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

        // 大图画整幕：窗外城市远景做底（在 slat 之下）
        if isBig {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(stops: [
                                .init(color: cityWarm.opacity(0.18), location: 0),
                                .init(color: cityMid.opacity(0.40),  location: 0.4),
                                .init(color: Color(red: 20/255, green: 22/255, blue: 34/255), location: 1)
                            ]),
                            center: CGPoint(x: w * 0.55, y: h * 0.70),
                            startRadius: 0, endRadius: max(w, h) * 0.9
                         ))
        }

        // 城市横向漂移（mid 驱动）
        let shimmer: CGFloat = CGFloat(sinf(t * 0.22 + mid * 1.8)) * w * 0.05

        // slat 排布：大图 14 片全 span，小图 10 片 span 0.72
        let slatCount = isBig ? 14 : 10
        let slatSpanRatio: CGFloat = isBig ? 0.96 : 0.72
        let slatSpan: CGFloat = h * slatSpanRatio
        let slatTop: CGFloat = (h - slatSpan) / 2
        let pitch: CGFloat = slatSpan / CGFloat(slatCount)
        let slatH: CGFloat = pitch * 0.70
        let gapH: CGFloat = pitch - slatH

        // 微倾角（bass 驱动）— 整排 slat 轻轻倾
        let tiltAmp: CGFloat = CGFloat(bass * (1 - idleBlend)) * 0.018

        for i in 0..<slatCount {
            let rowY: CGFloat = slatTop + CGFloat(i) * pitch
            let slatRect = CGRect(x: 0, y: rowY, width: w, height: slatH)
            let gapY: CGFloat = rowY + slatH
            let gapRect = CGRect(x: 0, y: gapY, width: w, height: gapH)

            // 该缝对应频段（顶行 = 低频）
            let sf: Float = Float(i) / Float(slatCount - 1)
            let binIdx = min(binCount - 1, max(0, Int(sf * Float(binCount - 1))))
            let binVal: CGFloat = CGFloat(spectrumData[binIdx])

            // 缝隙里的城市色：暗静谧 + binVal 触发暖光
            let injectRaw: Float = min(1.0, Float(binVal) * 2.5) * (1 - idleBlend)
            let inject: Double = Double(injectRaw)

            // 线性横向渐变（冷→紫→暖→紫→冷），shimmer 推着走
            let cx: CGFloat = w * 0.5 + shimmer
            let gradStops: [Gradient.Stop] = [
                .init(color: cityCool.opacity(0.30 + inject * 0.25), location: 0.0),
                .init(color: cityMid.opacity (0.52 + inject * 0.30), location: 0.30),
                .init(color: cityWarm.opacity(0.25 + inject * 0.75), location: 0.55),
                .init(color: cityMid.opacity (0.48 + inject * 0.32), location: 0.82),
                .init(color: cityCool.opacity(0.30 + inject * 0.25), location: 1.0),
            ]
            context.fill(Path(gapRect),
                         with: .linearGradient(
                            Gradient(stops: gradStops),
                            startPoint: CGPoint(x: cx - w * 0.55, y: gapRect.midY),
                            endPoint: CGPoint(x: cx + w * 0.55, y: gapRect.midY)
                         ))

            // slat 本体（竖向渐变：上浅下深）
            // 小图边缘（第一条/最后一条）降 alpha，让过渡到透明 canvas 更柔
            var slatAlpha: Double = 1.0
            if !isBig {
                if i == 0 || i == slatCount - 1 {
                    slatAlpha = 0.45
                } else if i == 1 || i == slatCount - 2 {
                    slatAlpha = 0.80
                }
            }
            context.fill(Path(slatRect),
                         with: .linearGradient(
                            Gradient(colors: [
                                slat.opacity(slatAlpha),
                                slatEdge.opacity(slatAlpha)
                            ]),
                            startPoint: CGPoint(x: slatRect.midX, y: slatRect.minY),
                            endPoint: CGPoint(x: slatRect.midX, y: slatRect.maxY)
                         ))

            // slat 下缘暖 rim — binVal 让它更亮（从窗外光反射到 slat 底）
            var rim = Path()
            rim.move(to: CGPoint(x: 0, y: slatRect.maxY - 0.5))
            let rimEndY: CGFloat = slatRect.maxY - 0.5 + tiltAmp * w
            rim.addLine(to: CGPoint(x: w, y: rimEndY))
            let rimAlpha: Double = (0.15 + Double(binVal) * 0.55) * slatAlpha
            context.stroke(rim, with: .color(slatRim.opacity(rimAlpha)), lineWidth: 0.8)
        }

        // 右下 vignette（大图）— 房间内侧阴影压住对比
        if isBig {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                            Gradient(colors: [
                                Color.clear,
                                Color.black.opacity(0.35)
                            ]),
                            center: CGPoint(x: w * 0.5, y: h * 0.55),
                            startRadius: min(w, h) * 0.4,
                            endRadius: max(w, h) * 0.85
                         ))
        }
    }
}

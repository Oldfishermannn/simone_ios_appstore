import SwiftUI

// R&B visualizer — Flora.
//
// 小图：5 朵花 landscape（god's eye）。
// 大图：12 朵野花密排 landscape，小图的直接延展。所有花等响应，没有 tier/大气透视。
// 生机 = 每朵都活 + 左→右一道低频风浪依次扫过花头。
struct FloraView: View {
    let spectrumData: [Float]
    var density: Int = 1

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            if density > 1 {
                renderFieldPOV(context: context, size: size, binCount: binCount)
            } else {
                renderField(context: context, size: size, binCount: binCount)
            }
        }
    }

    // MARK: - Small mode (field landscape — 保留原样)

    private func renderField(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width
        let h = size.height
        let flowerCount = 5

        let maxValue = spectrumData.max() ?? 0
        let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

        for f in 0..<flowerCount {
            let t = Float(f) / Float(flowerCount)
            let bin = min(Int(t * Float(binCount - 1)), binCount - 1)
            let raw = CGFloat(spectrumData[bin])
            let idleVal: CGFloat = 0.32 + 0.18 * CGFloat(sinf(t * .pi * 2 + Float(f) * 0.7))
            let value = raw * (1 - idleBlend) + idleVal * idleBlend

            let fx = w * (0.1 + CGFloat(t) * 0.8)
            let fy = h * 0.85

            let stemHeight = h * 0.15 + value * h * 0.35
            var stem = Path()
            stem.move(to: CGPoint(x: fx, y: fy))
            let sway = sin(Double(f) * 1.5) * 15 * Double(value)
            stem.addQuadCurve(
                to: CGPoint(x: fx + sway, y: fy - stemHeight),
                control: CGPoint(x: fx + sway * 0.7, y: fy - stemHeight * 0.5)
            )
            context.stroke(stem, with: .color(MorandiPalette.sage.opacity(0.2 + Double(value) * 0.3)), lineWidth: 1.5)

            let headX = fx + sway
            let headY = fy - stemHeight
            let petalCount = 5 + (f % 3)
            let petalLength = 6 + value * 18
            let color = MorandiPalette.color(at: f)

            for p in 0..<petalCount {
                let angle = Double(p) / Double(petalCount) * 2 * .pi
                let px = headX + petalLength * cos(angle)
                let py = headY + petalLength * sin(angle) * 0.8

                var petal = Path()
                petal.move(to: CGPoint(x: headX, y: headY))
                let cpDist = petalLength * 0.6
                let cp1x = headX + cpDist * cos(angle + 0.3)
                let cp1y = headY + cpDist * sin(angle + 0.3) * 0.8
                let cp2x = headX + cpDist * cos(angle - 0.3)
                let cp2y = headY + cpDist * sin(angle - 0.3) * 0.8
                petal.addCurve(to: CGPoint(x: px, y: py),
                               control1: CGPoint(x: cp1x, y: cp1y),
                               control2: CGPoint(x: px, y: py))
                petal.addCurve(to: CGPoint(x: headX, y: headY),
                               control1: CGPoint(x: cp2x, y: cp2y),
                               control2: CGPoint(x: headX, y: headY))

                context.fill(petal, with: .color(color.opacity(0.08 + Double(value) * 0.2)))
                context.stroke(petal, with: .color(color.opacity(0.2 + Double(value) * 0.4)), lineWidth: 1)
            }

            let dotR = 3 + value * 4
            let dotRect = CGRect(x: headX - dotR, y: headY - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(MorandiPalette.sand.opacity(0.3 + Double(value) * 0.5)))
        }
    }

    // MARK: - Big mode (dense landscape row)

    private struct FlowerSpec {
        let cx: CGFloat          // 归一化 (相对 w)
        let cyBase: CGFloat      // 茎底 y (归一化相对 h)
        let stemHeight: CGFloat  // 归一化相对 h
        let radius: CGFloat      // 归一化相对 w
        let color: Color
        let stemColor: Color
        let dotColor: Color
        let petalCount: Int
        let seed: Double
    }

    private func renderFieldPOV(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width
        let h = size.height
        let flowerCount = 12

        // 小图同色系（MorandiPalette 五色循环） + 对应 dot 深色
        let petalColors: [Color] = [
            MorandiPalette.rose,
            MorandiPalette.mauve,
            MorandiPalette.sage,
            MorandiPalette.sand,
            MorandiPalette.blue
        ]
        let dotColors: [Color] = [
            Color(red: 0.60, green: 0.48, blue: 0.45),   // rose
            Color(red: 0.51, green: 0.43, blue: 0.51),   // mauve
            Color(red: 0.46, green: 0.50, blue: 0.39),   // sage
            Color(red: 0.60, green: 0.56, blue: 0.47),   // sand
            Color(red: 0.43, green: 0.48, blue: 0.56)    // blue
        ]

        // 12 朵花：均布 + 种子抖动（不机械等距）
        var flowers: [FlowerSpec] = []
        for i in 0..<flowerCount {
            let t = CGFloat(i) / CGFloat(flowerCount - 1)
            let hash1 = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
            let rand1 = hash1 - floor(hash1)         // 0..1
            let hash2 = sin(Double(i) * 39.1 + 17.7) * 3714.9
            let rand2 = hash2 - floor(hash2)         // 0..1

            let jitterX = (CGFloat(rand1) - 0.5) * 0.025
            let cx = 0.04 + t * 0.92 + jitterX
            let stemH = 0.24 + CGFloat(rand2) * 0.26         // 0.24 ~ 0.50 — 高低错落
            let radius = 0.055 + CGFloat(rand1) * 0.025      // 0.055 ~ 0.080
            let petalCount = 5 + i % 3
            flowers.append(FlowerSpec(
                cx: cx,
                cyBase: 0.88,
                stemHeight: stemH,
                radius: radius,
                color: petalColors[i % petalColors.count],
                stemColor: MorandiPalette.sage,
                dotColor: dotColors[i % dotColors.count],
                petalCount: petalCount,
                seed: Double(i) * 1.37 + rand2 * 3.0
            ))
        }

        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)
        let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 120)

        // 低频能量（驱动风浪强度）
        let thirds = binCount / 3
        var bass: Float = 0
        for i in 0..<thirds { bass += spectrumData[i] }
        bass /= Float(thirds)
        let windStrength = bass * (1 - idleBlend) + 0.35 * idleBlend

        // 草地暗示
        drawGroundHint(context: context, w: w, h: h, color: MorandiPalette.sage)

        // 从后往前画（高花先画）— 这样前面的花遮住后面稍合理
        let sorted = flowers.enumerated().sorted { $0.element.stemHeight > $1.element.stemHeight }
        for (idx, spec) in sorted {
            // 每朵自己的 bin 做呼吸
            let binIdx = (Int(spec.seed * 23) + idx * 7) % binCount
            let rawBreath = CGFloat(spectrumData[binIdx])
            let idleBreath = 0.48 + sinf(t * 0.8 + Float(spec.seed)) * 0.32
            let breath = rawBreath * CGFloat(1 - idleBlend) + CGFloat(idleBreath) * CGFloat(idleBlend)

            // 风浪：从左→右传递的低频波
            let windPhase = t * 1.2 - Float(idx) * 0.42
            let windWave = sinf(windPhase)
            let sway = CGFloat(windWave) * (0.35 + CGFloat(windStrength) * 0.8)

            drawFlower(
                context: context, w: w, h: h, spec: spec, flowerIdx: idx, binCount: binCount,
                breath: breath, sway: sway, idleBlend: idleBlend, t: t
            )
        }
    }

    // MARK: - Ground hint

    private func drawGroundHint(context: GraphicsContext, w: CGFloat, h: CGFloat, color: Color) {
        // 不画地平线 — 只是底部 1/3 加一点草地色（上缘柔和过渡，没有 hard edge）
        let rect = CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.38)
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [
                color.opacity(0.0),
                color.opacity(0.08),
                color.opacity(0.14)
            ]),
            startPoint: CGPoint(x: w * 0.5, y: rect.minY),
            endPoint: CGPoint(x: w * 0.5, y: rect.maxY)
        ))
    }

    // MARK: - Single flower

    private func drawFlower(
        context: GraphicsContext, w: CGFloat, h: CGFloat,
        spec: FlowerSpec, flowerIdx: Int, binCount: Int,
        breath: CGFloat, sway: CGFloat,
        idleBlend: Float, t: Float
    ) {
        let stemBottomX = spec.cx * w
        let stemBottomY = spec.cyBase * h
        let r = spec.radius * w
        let stemH = spec.stemHeight * h + breath * h * 0.04   // 响度让茎挺起来一点

        // 花头 = 茎顶 + 风 sway
        let swayPx = sway * r * 0.8
        let headX = stemBottomX + swayPx
        let headY = stemBottomY - stemH

        // 茎：从固定底部弯曲到摇摆花头
        var stem = Path()
        stem.move(to: CGPoint(x: stemBottomX, y: stemBottomY))
        stem.addQuadCurve(
            to: CGPoint(x: headX, y: headY),
            control: CGPoint(
                x: stemBottomX + swayPx * 0.35,
                y: stemBottomY - stemH * 0.5
            )
        )
        context.stroke(stem, with: .color(spec.stemColor.opacity(0.32)), lineWidth: 1.1)

        // 花瓣：每片独立 bin（小图的"不齐开合"）
        let idleBlendCG = CGFloat(idleBlend)
        for p in 0..<spec.petalCount {
            let binIdx = (Int(spec.seed * 19) + p * 11 + flowerIdx * 3) % binCount
            let rawBin = CGFloat(spectrumData[binIdx])
            let idlePetal = 0.48 + CGFloat(sinf(t * 0.9 + Float(p) * 1.3 + Float(spec.seed))) * 0.34
            let petalVal = rawBin * (1 - idleBlendCG) + idlePetal * idleBlendCG

            let wobble = sin(Double(p) * 2.3 + spec.seed)
            let angle = Double(p) / Double(spec.petalCount) * 2 * .pi - .pi / 2 + wobble * 0.06

            // 长度 0.62~1.14 (±26%) — 开合幅度到位
            let lenFactor = 0.62 + petalVal * 0.52
            let len = r * (0.98 + CGFloat(wobble) * 0.08) * lenFactor
            let tipX = headX + cos(angle) * len
            let tipY = headY + sin(angle) * len * 0.85

            let perp = angle + .pi / 2
            let pWidth = len * 0.46 * (0.88 + CGFloat(cos(Double(p) * 1.7)) * 0.08)

            let c1 = CGPoint(
                x: headX + cos(angle) * len * 0.52 + cos(perp) * pWidth,
                y: headY + sin(angle) * len * 0.52 * 0.85 + sin(perp) * pWidth
            )
            let c2 = CGPoint(
                x: headX + cos(angle) * len * 0.52 - cos(perp) * pWidth,
                y: headY + sin(angle) * len * 0.52 * 0.85 - sin(perp) * pWidth
            )

            var petal = Path()
            petal.move(to: CGPoint(x: headX, y: headY))
            petal.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: c1)
            petal.addQuadCurve(to: CGPoint(x: headX, y: headY), control: c2)

            let fillAlpha = 0.55 + petalVal * 0.3
            context.fill(petal, with: .color(spec.color.opacity(fillAlpha)))
            let strokeAlpha = 0.22 + petalVal * 0.26
            context.stroke(petal, with: .color(spec.dotColor.opacity(strokeAlpha)), lineWidth: 0.7)
        }

        // 花芯：大小随总响度呼吸
        let dotR = max(1.2, r * (0.16 + breath * 0.10))
        let dotRect = CGRect(x: headX - dotR, y: headY - dotR * 0.85, width: dotR * 2, height: dotR * 1.7)
        context.fill(Path(ellipseIn: dotRect), with: .color(spec.dotColor))

        // 大花加雄蕊（小花省略避免杂乱）
        if spec.radius > 0.065 {
            let stamenCount = 4
            for s in 0..<stamenCount {
                let a = Double(s) / Double(stamenCount) * 2 * .pi + spec.seed
                let inner = CGPoint(x: headX + cos(a) * dotR * 0.35, y: headY + sin(a) * dotR * 0.35)
                let outer = CGPoint(x: headX + cos(a) * dotR * 1.1, y: headY + sin(a) * dotR * 1.0)
                var stamen = Path()
                stamen.move(to: inner)
                stamen.addLine(to: outer)
                context.stroke(stamen, with: .color(spec.dotColor.opacity(0.6)), lineWidth: 0.5)
            }
        }
    }
}

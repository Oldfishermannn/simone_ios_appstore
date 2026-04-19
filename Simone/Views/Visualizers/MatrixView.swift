import SwiftUI

// Electronic visualizer — Chrome Horizon.
//
// 小图 (expansion=0): 单栋主楼居中满高，占满画面。
// 大图 (expansion=1): 地平线出现在 y=0.79h。
//   - 后景城市剪影（5 栋暗楼错落）
//   - 条纹日（半圆在地平线后面被主楼右侧错开，4 道横向切片）
//   - 地面透视网格（消失点在地平线中央，粉色地面光栅）
//   主楼 morph 到右偏姿态，沿地平线收脚。
//
// 所有场景物件走 sceneAlpha smoothstep(0.30, 0.88) 淡入，保证 morph 期物物流畅。
struct MatrixView: View {
    let spectrumData: [Float]
    var density: Int = 1
    var expansion: CGFloat = 1.0

    private struct Building {
        let xRatio: CGFloat
        let wRatio: CGFloat
        let topRatio: CGFloat
        let baseRatio: CGFloat
        let cols: Int
        let rows: Int
        let binStart: Int
        let binEnd: Int
    }

    /// 主楼：小图占满 → 大图右偏、楼脚上移到地平线。
    private func mainBuilding(e: CGFloat, binCount: Int) -> Building {
        let xRatio    = 0.21 + (0.50 - 0.21) * e
        let wRatio    = 0.58 + (0.22 - 0.58) * e
        let topRatio  = 0.12 + (0.09 - 0.12) * e
        let baseRatio = 0.98 + (0.79 - 0.98) * e
        let binStartF = 0 + (10 - 0) * Double(e)
        let binEndF = Double(binCount - 1) + (30 - Double(binCount - 1)) * Double(e)
        return Building(
            xRatio: xRatio, wRatio: wRatio,
            topRatio: topRatio, baseRatio: baseRatio,
            cols: 6, rows: 16,
            binStart: min(binCount - 1, max(0, Int(binStartF.rounded()))),
            binEnd: min(binCount - 1, max(0, Int(binEndF.rounded())))
        )
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let e: CGFloat = max(0, min(1, expansion))
            let sceneAlpha: Double = smoothstep(0.30, 0.88, Double(e))

            let maxValue = spectrumData.max() ?? 0
            let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

            let thirds = binCount / 3
            var bass: Float = 0
            for i in 0..<thirds { bass += spectrumData[i] }
            bass /= Float(thirds)
            let bassCG = CGFloat(bass) * (1 - idleBlend) + 0.10 * idleBlend

            let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

            let horizonY = h * 0.79

            // ─── 天空底色（大图淡入，极淡暖紫，只给条纹日一点托底）
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    let skyRect = CGRect(x: 0, y: 0, width: w, height: horizonY)
                    let top = Color(red: 0.06, green: 0.06, blue: 0.10)
                    let mid = Color(red: 0.11, green: 0.08, blue: 0.14)
                    ctx.fill(Path(skyRect),
                             with: .linearGradient(
                                Gradient(colors: [top, mid]),
                                startPoint: CGPoint(x: w * 0.5, y: 0),
                                endPoint: CGPoint(x: w * 0.5, y: horizonY)
                             ))
                }
            }

            // ─── 条纹日（在后景楼之前，被主楼遮挡右半）
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha * 0.92
                    drawStripedSun(
                        ctx: ctx, w: w, h: h,
                        center: CGPoint(x: w * 0.38, y: horizonY),
                        radius: min(w, h) * 0.22,
                        bassCG: bassCG, t: t
                    )
                }
            }

            // ─── 后景城市剪影
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    drawBackSkyline(ctx: ctx, w: w, h: h, horizonY: horizonY)
                }
            }

            // ─── 地面底色 + 透视网格
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    let groundRect = CGRect(x: 0, y: horizonY, width: w, height: h - horizonY)
                    let near = Color(red: 0.05, green: 0.04, blue: 0.07)
                    let far  = Color(red: 0.09, green: 0.06, blue: 0.11)
                    ctx.fill(Path(groundRect),
                             with: .linearGradient(
                                Gradient(colors: [far, near]),
                                startPoint: CGPoint(x: w * 0.5, y: horizonY),
                                endPoint: CGPoint(x: w * 0.5, y: h)
                             ))
                    drawPerspectiveGrid(
                        ctx: ctx, w: w, h: h,
                        horizonY: horizonY,
                        vanishX: w * 0.51
                    )
                }
            }

            // ─── 主楼（连续 morph）
            drawBuilding(context: context, w: w, h: h,
                         bldg: mainBuilding(e: e, binCount: binCount),
                         binCount: binCount, idleBlend: idleBlend)
        }
    }

    // MARK: - Main building

    private func drawBuilding(context: GraphicsContext, w: CGFloat, h: CGFloat,
                              bldg: Building, binCount: Int, idleBlend: CGFloat) {
        let bx = w * bldg.xRatio
        let by = h * bldg.topRatio
        let bh = h * (bldg.baseRatio - bldg.topRatio)
        let bw = w * bldg.wRatio

        context.fill(
            Path(CGRect(x: bx, y: by, width: bw, height: bh)),
            with: .color(Color(red: 0.10, green: 0.11, blue: 0.15))
        )

        // 楼左侧竖向高光边（来自地平线粉光的反射，非装饰性描边）
        let edgeRect = CGRect(x: bx, y: by, width: 1.2, height: bh)
        context.fill(
            Path(edgeRect),
            with: .color(Color(red: 1.0, green: 0.50, blue: 0.68).opacity(0.28))
        )

        let cellW = bw / CGFloat(bldg.cols)
        let cellH = bh / CGFloat(bldg.rows)
        let insetX = cellW * 0.18
        let insetY = cellH * 0.22

        for col in 0..<bldg.cols {
            let colT = Float(col) / Float(max(bldg.cols - 1, 1))
            let range = max(1, bldg.binEnd - bldg.binStart)
            let bin = min(binCount - 1, max(0, bldg.binStart + Int(colT * Float(range))))
            let lo = max(0, bin - 1)
            let hi = min(binCount - 1, bin + 1)
            let value = CGFloat((spectrumData[lo] + spectrumData[bin] * 2 + spectrumData[hi]) / 4)

            for row in 0..<bldg.rows {
                let seed = sin(Double(col) * 12.9898 + Double(row) * 78.233)
                let noise = seed - floor(seed)

                let rowFromBottom = bldg.rows - 1 - row
                let rowNorm = CGFloat(rowFromBottom) / CGFloat(max(bldg.rows - 1, 1))
                let threshold = 0.08 + (1 - rowNorm) * 0.55 + CGFloat(noise) * 0.15

                let liveLit: CGFloat = value > threshold ? min(1, (value - threshold) * 3) : 0
                let idleLit: CGFloat = noise > 0.72 ? 0.62 : (noise > 0.55 ? 0.22 : 0)
                let lit = liveLit * (1 - idleBlend) + idleLit * idleBlend

                let x = bx + CGFloat(col) * cellW
                let y = by + CGFloat(row) * cellH
                let winRect = CGRect(
                    x: x + insetX,
                    y: y + insetY,
                    width: cellW - insetX * 2,
                    height: cellH - insetY * 2
                )

                context.fill(
                    Path(winRect),
                    with: .color(Color(red: 0.16, green: 0.18, blue: 0.24).opacity(0.60))
                )

                if lit > 0.02 {
                    let warm = Color(red: 1.0, green: 0.83, blue: 0.45)
                    context.fill(
                        Path(winRect),
                        with: .color(warm.opacity(0.18 + Double(lit) * 0.7))
                    )
                    if lit > 0.5 {
                        let glowRect = winRect.insetBy(dx: -2, dy: -2)
                        context.fill(
                            Path(glowRect),
                            with: .color(warm.opacity(Double(lit - 0.5) * 0.18))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Striped sun

    private func drawStripedSun(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        center: CGPoint, radius: CGFloat,
        bassCG: CGFloat, t: Float
    ) {
        let breath = 1.0 + 0.04 * sin(Double(t) * 0.6) + Double(bassCG) * 0.08
        let r = radius * CGFloat(breath)

        // 日面渐变：上冷珊瑚 → 下深紫玫（不做 purple-to-blue AI slop，是暖 → 玫）
        let top    = Color(red: 0.98, green: 0.52, blue: 0.40)
        let middle = Color(red: 0.92, green: 0.36, blue: 0.50)
        let bottom = Color(red: 0.55, green: 0.18, blue: 0.42)

        // 上半圆日面填渐变
        var upperHalf = Path()
        upperHalf.addArc(center: center, radius: r,
                         startAngle: .degrees(180), endAngle: .degrees(360),
                         clockwise: false)
        upperHalf.closeSubpath()
        ctx.fill(upperHalf,
                 with: .linearGradient(
                    Gradient(colors: [top, middle, bottom]),
                    startPoint: CGPoint(x: center.x, y: center.y - r),
                    endPoint: CGPoint(x: center.x, y: center.y)
                 ))

        // 条纹切片：用弦长公式限制宽度在日面范围内
        let stripeColor = Color(red: 0.06, green: 0.06, blue: 0.10)
        let stripeYs: [CGFloat] = [0.28, 0.48, 0.66, 0.82]
        let stripeHs: [CGFloat] = [r * 0.11, r * 0.085, r * 0.065, r * 0.05]
        for (offsetT, sh) in zip(stripeYs, stripeHs) {
            let cy = center.y - r * (1 - offsetT)
            let dy = center.y - cy
            let halfChord = sqrt(max(0, r * r - dy * dy))
            let rect = CGRect(
                x: center.x - halfChord,
                y: cy - sh / 2,
                width: halfChord * 2,
                height: sh
            )
            ctx.fill(Path(rect), with: .color(stripeColor))
        }

        // 外晕（低调，不铺满）
        let glowR = r * 1.3
        let glowRect = CGRect(
            x: center.x - glowR, y: center.y - glowR,
            width: glowR * 2, height: glowR * 2
        )
        ctx.fill(Path(ellipseIn: glowRect),
                 with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.95, green: 0.40, blue: 0.55).opacity(0.22),
                        Color(red: 0.95, green: 0.40, blue: 0.55).opacity(0)
                    ]),
                    center: center,
                    startRadius: r * 0.8, endRadius: glowR
                 ))
    }

    // MARK: - Back skyline

    private func drawBackSkyline(ctx: GraphicsContext, w: CGFloat, h: CGFloat, horizonY: CGFloat) {
        // 5 栋暗楼剪影，错落在地平线后，避开主楼中段
        let bldgs: [(xN: CGFloat, wN: CGFloat, hN: CGFloat)] = [
            (0.04, 0.08, 0.08),
            (0.13, 0.06, 0.06),
            (0.19, 0.09, 0.11),
            (0.78, 0.07, 0.09),
            (0.86, 0.10, 0.07)
        ]
        for b in bldgs {
            let bw = w * b.wN
            let bh = h * b.hN
            let bx = w * b.xN
            let by = horizonY - bh
            ctx.fill(
                Path(CGRect(x: bx, y: by, width: bw, height: bh)),
                with: .color(Color(red: 0.08, green: 0.09, blue: 0.14))
            )
            // 顶部一行微小暖窗点（3-5 个小亮点，不是网格）
            let dotCount = 3
            for i in 0..<dotCount {
                let dx = bx + bw * (0.2 + 0.6 * CGFloat(i) / CGFloat(dotCount - 1))
                let dy = by + bh * 0.3
                let dotRect = CGRect(x: dx, y: dy, width: 1.1, height: 1.1)
                ctx.fill(Path(dotRect),
                         with: .color(Color(red: 1.0, green: 0.78, blue: 0.42).opacity(0.55)))
            }
        }
    }

    // MARK: - Perspective grid

    private func drawPerspectiveGrid(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        horizonY: CGFloat, vanishX: CGFloat
    ) {
        let groundDepth = h - horizonY
        let pink = Color(red: 1.0, green: 0.42, blue: 0.62)

        // 横向线（4 条，从地平线指数展开到画面底部）
        let horizontalTs: [CGFloat] = [0.18, 0.36, 0.58, 0.82]
        for tH in horizontalTs {
            let y = horizonY + groundDepth * tH
            let alpha = 0.20 + Double(tH) * 0.22
            let rect = CGRect(x: 0, y: y, width: w, height: 0.9)
            ctx.fill(Path(rect), with: .color(pink.opacity(alpha)))
        }

        // 纵向消失线（9 条，左右各 4 条 + 中线；在底边等距，全部收敛到 vanishX）
        let verticalCount = 9
        let halfSpan = w * 0.62   // 底部网格横向覆盖范围
        for i in 0..<verticalCount {
            let tV = CGFloat(i) / CGFloat(verticalCount - 1)  // 0..1
            let bottomX = vanishX - halfSpan + halfSpan * 2 * tV
            let topX = vanishX
            var path = Path()
            path.move(to: CGPoint(x: topX, y: horizonY))
            path.addLine(to: CGPoint(x: bottomX, y: h))
            let alpha = 0.22 + abs(tV - 0.5) * 0.12
            ctx.stroke(path, with: .color(pink.opacity(alpha)), lineWidth: 0.8)
        }
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

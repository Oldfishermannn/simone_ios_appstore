import SwiftUI

// Electronic visualizer — City Window (single tower with street scene).
//
// 小图 (expansion=0): 单栋主楼居中、满高。
// 大图 (expansion=1): 主楼右移缩窄成画面主体，街道地面淡入画面下缘，
// 左下一盏暖白路灯柱，右上一块玫红霓虹圆标（treble 脉动）。
//
// 主楼窗户网格 cols×rows 保持一致（6×16）让 morph 过程中不跳格子；
// 仅几何 xRatio/wRatio/hRatio + bin 映射范围连续插值。
// 其余场景物件（街道/路灯/霓虹）走 sceneAlpha smoothstep(0.30, 0.88) 淡入。
struct MatrixView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small (单楼居中), 1 = big (主楼 + 街景场景)
    var expansion: CGFloat = 1.0

    private struct Building {
        let xRatio: CGFloat
        let wRatio: CGFloat
        let hRatio: CGFloat
        let cols: Int
        let rows: Int
        let binStart: Int
        let binEnd: Int
        let opacity: Double
        let seedOffset: Double
    }

    /// 主楼：几何随 expansion 从小图 pose 连续插到大图中段 pose。
    /// 窗户网格 cols=6 rows=16 固定。
    private func mainBuilding(e: CGFloat, binCount: Int) -> Building {
        let xRatio  = 0.21 + (0.37 - 0.21) * e
        let wRatio  = 0.58 + (0.28 - 0.58) * e
        let hRatio  = 0.86 + (0.80 - 0.86) * e
        // bin 映射：小图用全 spectrum，大图聚焦主楼频段
        let binStartF = 0 + (10 - 0) * Double(e)
        let binEndF = Double(binCount - 1) + (30 - Double(binCount - 1)) * Double(e)
        return Building(
            xRatio: xRatio, wRatio: wRatio, hRatio: hRatio,
            cols: 6, rows: 16,
            binStart: min(binCount - 1, max(0, Int(binStartF.rounded()))),
            binEnd: min(binCount - 1, max(0, Int(binEndF.rounded()))),
            opacity: 1.0,
            seedOffset: 0.0
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
            var treble: Float = 0
            for i in (2 * thirds)..<binCount { treble += spectrumData[i] }
            treble /= Float(binCount - 2 * thirds)
            let trebleCG = CGFloat(treble) * (1 - idleBlend) + 0.14 * idleBlend

            let t = Float(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 240)

            // ─── 街道地面（大图淡入）─────────────────────────
            // 画面下缘一条深色带，表示柏油路。中段一条细暖色 highlight 暗
            // 示路面反光的接缝，和主楼楼脚视觉分隔。
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    let streetY = h * 0.945
                    let streetRect = CGRect(x: 0, y: streetY, width: w, height: h - streetY)
                    let streetDark = Color(red: 0.07, green: 0.08, blue: 0.10)
                    let streetMid  = Color(red: 0.11, green: 0.12, blue: 0.14)
                    ctx.fill(Path(streetRect),
                             with: .linearGradient(
                                Gradient(colors: [streetMid, streetDark]),
                                startPoint: CGPoint(x: w * 0.5, y: streetRect.minY),
                                endPoint: CGPoint(x: w * 0.5, y: streetRect.maxY)
                             ))
                    // 路面一条暖色高光线（远处路灯的反光接缝）
                    let hlRect = CGRect(x: 0, y: streetY + h * 0.012,
                                        width: w, height: 0.8)
                    let warm = Color(red: 1.0, green: 0.83, blue: 0.45)
                    ctx.fill(Path(hlRect),
                             with: .linearGradient(
                                Gradient(colors: [
                                    warm.opacity(0),
                                    warm.opacity(0.18),
                                    warm.opacity(0)
                                ]),
                                startPoint: CGPoint(x: 0, y: hlRect.midY),
                                endPoint: CGPoint(x: w, y: hlRect.midY)
                             ))
                }
            }

            // ─── 主楼（连续 morph）────────────────────────────
            drawBuilding(context: context, w: w, h: h,
                         bldg: mainBuilding(e: e, binCount: binCount),
                         binCount: binCount, idleBlend: idleBlend)

            // ─── 左下路灯柱（大图淡入）──────────────────────
            // 柱身深色 silhouette + 顶端暖白 halo，treble 驱动轻微呼吸。
            // 位置在 0.10w，避开主楼范围。
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    drawStreetLamp(
                        ctx: ctx, w: w, h: h,
                        baseX: w * 0.10, baseY: h * 0.96,
                        poleHeight: h * 0.18,
                        trebleCG: trebleCG, t: t
                    )
                }
            }

            // ─── 右上霓虹圆标（大图淡入）──────────────────────
            // 玫红 neon：圆环 + 中心点，treble 驱动脉动 halo。位置避开主楼。
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    drawNeonSign(
                        ctx: ctx, w: w, h: h,
                        center: CGPoint(x: w * 0.80, y: h * 0.22),
                        radius: min(w, h) * 0.034,
                        trebleCG: trebleCG, t: t
                    )
                }
            }
        }
    }

    // MARK: - Building

    private func drawBuilding(context: GraphicsContext, w: CGFloat, h: CGFloat,
                              bldg: Building, binCount: Int, idleBlend: CGFloat) {
        let bx = w * bldg.xRatio
        let bh = h * bldg.hRatio
        let by = h - bh - h * 0.02
        let bw = w * bldg.wRatio

        context.fill(
            Path(CGRect(x: bx, y: by, width: bw, height: bh)),
            with: .color(Color(red: 0.16, green: 0.19, blue: 0.23).opacity(0.9 * bldg.opacity))
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
                let seed = sin(Double(col) * 12.9898 + Double(row) * 78.233 + bldg.seedOffset)
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
                    with: .color(Color(red: 0.22, green: 0.26, blue: 0.32).opacity(0.55 * bldg.opacity))
                )

                if lit > 0.02 {
                    let warm = Color(red: 1.0, green: 0.83, blue: 0.45)
                    context.fill(
                        Path(winRect),
                        with: .color(warm.opacity((0.18 + Double(lit) * 0.7) * bldg.opacity))
                    )

                    if lit > 0.5 {
                        let glowRect = winRect.insetBy(dx: -2, dy: -2)
                        context.fill(
                            Path(glowRect),
                            with: .color(warm.opacity(Double(lit - 0.5) * 0.18 * bldg.opacity))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Street lamp

    private func drawStreetLamp(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        baseX: CGFloat, baseY: CGFloat,
        poleHeight: CGFloat,
        trebleCG: CGFloat, t: Float
    ) {
        let pole = Color(red: 0.10, green: 0.11, blue: 0.13)
        let warm = Color(red: 1.0, green: 0.83, blue: 0.52)

        let topY = baseY - poleHeight
        let poleW: CGFloat = 1.8

        // 灯柱（深色垂直细条）
        let poleRect = CGRect(x: baseX - poleW / 2, y: topY, width: poleW, height: poleHeight)
        ctx.fill(Path(poleRect), with: .color(pole))

        // 灯柱顶端水平臂（把灯挑出去）
        let armLen: CGFloat = w * 0.035
        let armRect = CGRect(x: baseX, y: topY - 0.6, width: armLen, height: 1.2)
        ctx.fill(Path(armRect), with: .color(pole))

        // 灯头（圆形）
        let headCx = baseX + armLen
        let headCy = topY + 2
        let headR: CGFloat = 2.2

        // 大 halo（暖光洒开）
        let halo = headR * 14 * (1 + trebleCG * 0.25)
        let pulse = 0.6 + 0.15 * sin(Double(t) * 0.8)
        let haloRect = CGRect(
            x: headCx - halo, y: headCy - halo,
            width: halo * 2, height: halo * 2
        )
        ctx.fill(Path(ellipseIn: haloRect),
                 with: .radialGradient(
                    Gradient(colors: [warm.opacity(0.32 * pulse), warm.opacity(0)]),
                    center: CGPoint(x: headCx, y: headCy),
                    startRadius: 0, endRadius: halo
                 ))

        // 灯珠本体
        let headRect = CGRect(
            x: headCx - headR, y: headCy - headR,
            width: headR * 2, height: headR * 2
        )
        ctx.fill(Path(ellipseIn: headRect),
                 with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.95), warm]),
                    center: CGPoint(x: headCx - 0.5, y: headCy - 0.5),
                    startRadius: 0, endRadius: headR
                 ))
    }

    // MARK: - Neon sign

    private func drawNeonSign(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        center: CGPoint, radius: CGFloat,
        trebleCG: CGFloat, t: Float
    ) {
        // 玫红 neon —— 暖底色的对立面，但避开 cyan/purple AI slop 禁区。
        let rose = Color(red: 224/255, green: 96/255, blue: 112/255)

        // 外 halo（treble 驱动 + 呼吸）
        let breath = 0.75 + 0.20 * sin(Double(t) * 1.6) + Double(trebleCG) * 0.45
        let haloR = radius * (3.6 + trebleCG * 0.8)
        let haloRect = CGRect(
            x: center.x - haloR, y: center.y - haloR,
            width: haloR * 2, height: haloR * 2
        )
        ctx.fill(Path(ellipseIn: haloRect),
                 with: .radialGradient(
                    Gradient(colors: [
                        rose.opacity(0.42 * breath),
                        rose.opacity(0)
                    ]),
                    center: center,
                    startRadius: 0, endRadius: haloR
                 ))

        // 玻管外圈（stroke）
        let tubeRect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        ctx.stroke(Path(ellipseIn: tubeRect),
                   with: .color(rose.opacity(0.92 * breath)),
                   lineWidth: 1.8)
        // 内层细高光（让玻管有厚度）
        let innerRect = tubeRect.insetBy(dx: 1.8, dy: 1.8)
        ctx.stroke(Path(ellipseIn: innerRect),
                   with: .color(Color.white.opacity(0.45 * breath)),
                   lineWidth: 0.6)

        // 中心点
        let dotR: CGFloat = radius * 0.18
        let dotRect = CGRect(
            x: center.x - dotR, y: center.y - dotR,
            width: dotR * 2, height: dotR * 2
        )
        ctx.fill(Path(ellipseIn: dotRect),
                 with: .color(rose.opacity(0.95 * breath)))
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

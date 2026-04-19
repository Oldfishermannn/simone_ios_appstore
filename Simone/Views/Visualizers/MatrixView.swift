import SwiftUI

// Electronic visualizer — City Skyline.
//
// 小图 (expansion=0): 单栋主楼居中、满高。
// 大图 (expansion=1): 主楼右移缩窄成天际线中段，三栋辅楼淡入两侧。
//
// 主楼窗户网格 cols×rows 保持一致（6×16）让 morph 过程中不跳格子；
// 仅几何 xRatio/wRatio/hRatio + bin 映射范围连续插值。
struct MatrixView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small (单楼居中), 1 = big (天际线 4 楼)
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
        let xRatio  = 0.21 + (0.26 - 0.21) * e
        let wRatio  = 0.58 + (0.26 - 0.58) * e
        let hRatio  = 0.86 + (0.78 - 0.86) * e
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

    /// 辅楼（仅在大图淡入）
    private func sideBuildings(binCount: Int) -> [Building] {
        [
            Building(xRatio: 0.03, wRatio: 0.20, hRatio: 0.52, cols: 6, rows: 14,
                     binStart: min(0, binCount - 1), binEnd: min(12, binCount - 1),
                     opacity: 0.6,  seedOffset: 7.0),
            Building(xRatio: 0.54, wRatio: 0.22, hRatio: 0.64, cols: 7, rows: 16,
                     binStart: min(26, binCount - 1), binEnd: min(44, binCount - 1),
                     opacity: 0.85, seedOffset: 31.0),
            Building(xRatio: 0.78, wRatio: 0.19, hRatio: 0.56, cols: 6, rows: 14,
                     binStart: min(42, binCount - 1), binEnd: min(60, binCount - 1),
                     opacity: 0.65, seedOffset: 43.0),
        ]
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

            // 主楼（连续 morph）
            drawBuilding(context: context, w: w, h: h, bldg: mainBuilding(e: e, binCount: binCount),
                         binCount: binCount, idleBlend: idleBlend)

            // 辅楼（淡入）
            if sceneAlpha > 0.01 {
                context.drawLayer { ctx in
                    ctx.opacity = sceneAlpha
                    for side in sideBuildings(binCount: binCount) {
                        drawBuilding(context: ctx, w: w, h: h, bldg: side,
                                     binCount: binCount, idleBlend: idleBlend)
                    }
                }
            }
        }
    }

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

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

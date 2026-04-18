import SwiftUI

struct MatrixView: View {
    let spectrumData: [Float]
    var density: Int = 1

    // 单栋建筑的参数
    private struct Building {
        let xRatio: CGFloat     // 左边起点占画布宽比例
        let wRatio: CGFloat     // 宽度占比
        let hRatio: CGFloat     // 高度占画布高比例
        let cols: Int
        let rows: Int
        let binStart: Int
        let binEnd: Int
        let opacity: Double     // 前后景深感
        let seedOffset: Double  // 让每栋楼的窗户 noise 不同
    }

    // 大图：城市天际线（4 栋楼更壮实）
    private var skyline: [Building] {
        [
            Building(xRatio: 0.03, wRatio: 0.20, hRatio: 0.52, cols: 6, rows: 14, binStart: 0,  binEnd: 12, opacity: 0.6,  seedOffset: 7.0),
            Building(xRatio: 0.26, wRatio: 0.26, hRatio: 0.78, cols: 8, rows: 20, binStart: 10, binEnd: 30, opacity: 1.0,  seedOffset: 19.0),
            Building(xRatio: 0.54, wRatio: 0.22, hRatio: 0.64, cols: 7, rows: 16, binStart: 26, binEnd: 44, opacity: 0.85, seedOffset: 31.0),
            Building(xRatio: 0.78, wRatio: 0.19, hRatio: 0.56, cols: 6, rows: 14, binStart: 42, binEnd: 60, opacity: 0.65, seedOffset: 43.0),
        ]
    }

    // 小图：单栋主楼
    private var singleBuilding: Building {
        Building(xRatio: 0.21, wRatio: 0.58, hRatio: 0.86, cols: 6, rows: 16, binStart: 0, binEnd: 0, opacity: 1.0, seedOffset: 0.0)
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let maxValue = spectrumData.max() ?? 0
            let idleBlend = CGFloat(max(0, 1 - maxValue * 4))

            let buildings: [Building]
            if density > 1 {
                buildings = skyline
            } else {
                // 小图：保留单栋楼设计
                buildings = [singleBuilding]
            }

            for bldg in buildings {
                let bx = w * bldg.xRatio
                let bh = h * bldg.hRatio
                let by = h - bh - h * 0.02
                let bw = w * bldg.wRatio

                // 大厦剪影
                context.fill(
                    Path(CGRect(x: bx, y: by, width: bw, height: bh)),
                    with: .color(Color(red: 0.16, green: 0.19, blue: 0.23).opacity(0.9 * bldg.opacity))
                )

                let cellW = bw / CGFloat(bldg.cols)
                let cellH = bh / CGFloat(bldg.rows)
                let insetX = cellW * 0.18
                let insetY = cellH * 0.22

                for col in 0..<bldg.cols {
                    // Bin 映射：小图用整个 spectrum，大图每栋楼用自己的频段
                    let bin: Int
                    if density > 1, bldg.binEnd > bldg.binStart {
                        let colT = Float(col) / Float(max(bldg.cols - 1, 1))
                        let range = Float(bldg.binEnd - bldg.binStart)
                        bin = min(bldg.binStart + Int(colT * range), binCount - 1)
                    } else {
                        let colT = Float(col) / Float(max(bldg.cols - 1, 1))
                        bin = min(Int(colT * Float(binCount - 1)), binCount - 1)
                    }
                    let lo = max(0, bin - 1)
                    let hi = min(binCount - 1, bin + 1)
                    let value = CGFloat((spectrumData[lo] + spectrumData[bin] * 2 + spectrumData[hi]) / 4)

                    for row in 0..<bldg.rows {
                        // 每扇窗户固定的"性格种子"
                        let seed = sin(Double(col) * 12.9898 + Double(row) * 78.233 + bldg.seedOffset)
                        let noise = seed - floor(seed)

                        // 底层窗户阈值低（易亮），顶层高
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

                        // 深色玻璃
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
        }
    }
}

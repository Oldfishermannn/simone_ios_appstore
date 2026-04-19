// Archived 2026-04-18
// 原 Jazz 频道小图：Lissajous 双轨示波器
// 被黑胶唱片设计替换。保留此备份以便未来需要时恢复。
//
// 用法恢复时：把 renderSingleScope 函数体复制回 OscilloscopeView.swift
// 并在 body 的 Canvas 里按 density 分发。

import SwiftUI

struct OscilloscopeView_Lissajous: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let binCount = spectrumData.count
            guard binCount > 0 else { return }

            let maxValue = spectrumData.max() ?? 0
            let idleBlend = max(Float(0), 1 - maxValue * 4)

            // Grid background
            let gridSpacing: CGFloat = 30
            for x in stride(from: CGFloat(0), through: w, by: gridSpacing) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: h))
                context.stroke(line, with: .color(MorandiPalette.sage.opacity(0.04)), lineWidth: 0.5)
            }
            for y in stride(from: CGFloat(0), through: h, by: gridSpacing) {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: w, y: y))
                context.stroke(line, with: .color(MorandiPalette.sage.opacity(0.04)), lineWidth: 0.5)
            }

            // Center crosshair
            var crossH = Path()
            crossH.move(to: CGPoint(x: 0, y: cy))
            crossH.addLine(to: CGPoint(x: w, y: cy))
            context.stroke(crossH, with: .color(MorandiPalette.sage.opacity(0.08)), lineWidth: 0.5)
            var crossV = Path()
            crossV.move(to: CGPoint(x: cx, y: 0))
            crossV.addLine(to: CGPoint(x: cx, y: h))
            context.stroke(crossV, with: .color(MorandiPalette.sage.opacity(0.08)), lineWidth: 0.5)

            let points = 80
            let traces: [(Color, Float, Float)] = [
                (MorandiPalette.sage, 1.0, 0.0),
                (MorandiPalette.rose, 0.8, 0.3),
            ]

            for (color, freqMult, phaseShift) in traces {
                var path = Path()
                for i in 0..<points {
                    let t = Float(i) / Float(points)
                    let bin = min(Int(t * Float(binCount - 1)), binCount - 1)
                    let raw = spectrumData[bin]
                    let idleVal: Float = 0.45 + 0.25 * sinf(t * .pi * 4 * freqMult + phaseShift)
                    let value = raw * (1 - idleBlend) + idleVal * idleBlend

                    let xPhase = t * Float.pi * 4 * freqMult
                    let xAmp = w * 0.35 * CGFloat(0.3 + value * 0.7)
                    let x = cx + xAmp * CGFloat(sin(xPhase))

                    let yPhase = t * Float.pi * 6 * freqMult + phaseShift
                    let yAmp = h * 0.3 * CGFloat(0.3 + value * 0.7)
                    let y = cy + yAmp * CGFloat(sin(yPhase))

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(path, with: .color(color.opacity(0.1)), lineWidth: 4)
                context.stroke(path, with: .color(color.opacity(0.4)), lineWidth: 1.5)
            }

            // Beam dot
            let lastBin = binCount - 1
            let lastVal = CGFloat(spectrumData[lastBin])
            let dotR = 3 + lastVal * 4
            let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(MorandiPalette.sage.opacity(0.5)))
        }
    }
}

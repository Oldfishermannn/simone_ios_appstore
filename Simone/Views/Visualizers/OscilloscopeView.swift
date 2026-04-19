import SwiftUI

// Jazz visualizer — Vinyl on turntable.
//
// 小图 (expansion=0): 黑胶正面平视居中。唱臂未落。
// 大图 (expansion=1): 黑胶俯视扁平入桌，唱臂从右上伸入，针尖落在外圈。
//
// 物体连续 morph：黑胶始终是同一张，squash/radius/position 线性插值。
// 场景元素（背景光晕 / 地面阴影 / 侧壁厚度 / 唱臂 / 唱头）随 sceneAlpha
// smoothstep(0.30, 0.88, e) 逐帧淡入。
struct OscilloscopeView: View {
    let spectrumData: [Float]
    var density: Int = 1
    /// 0 = small pose (正面黑胶), 1 = big pose (俯视 + 唱臂场景)
    var expansion: CGFloat = 1.0

    var body: some View {
        Canvas { context, size in
            let binCount = spectrumData.count
            guard binCount > 0 else { return }
            renderScene(context: context, size: size, binCount: binCount)
        }
    }

    private func renderScene(context: GraphicsContext, size: CGSize, binCount: Int) {
        let w = size.width, h = size.height
        let e: CGFloat = max(0, min(1, expansion))
        let sceneAlpha: Double = smoothstep(0.30, 0.88, Double(e))

        let maxValue = spectrumData.max() ?? 0
        let idleBlend = max(Float(0), 1 - maxValue * 4)

        // 黑胶几何连续插值
        let centerY = h * (0.50 + 0.02 * e)
        let vinylSmallR = min(w, h) * 0.42
        let vinylBigR = min(w * 0.42, h * 0.38)
        let vinylR = vinylSmallR + (vinylBigR - vinylSmallR) * e
        let squash: CGFloat = 1.0 - 0.68 * e
        let vinylCenter = CGPoint(x: w * 0.5, y: centerY)
        let vinylRy = vinylR * squash

        let armMetal = Color(red: 0.70, green: 0.65, blue: 0.55)
        let armShadowC = Color(red: 0.10, green: 0.09, blue: 0.07)
        let cartridgeRed = Color(red: 0.58, green: 0.20, blue: 0.16)

        // ========= 场景专属元素（淡入）=========
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha

                // 背景：单侧暖光晕
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.16, green: 0.12, blue: 0.10).opacity(0.7),
                            Color.clear
                        ]),
                        center: CGPoint(x: w * 0.32, y: h * 0.22),
                        startRadius: 10,
                        endRadius: max(w, h) * 0.85
                    )
                )
                // 右下 vignette
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.35)
                        ]),
                        center: CGPoint(x: w * 0.5, y: h * 0.55),
                        startRadius: min(w, h) * 0.35,
                        endRadius: max(w, h) * 0.8
                    )
                )

                // 地面柔长阴影
                let shadowR = vinylR * 1.1
                let shadowRy = shadowR * squash * 0.6
                let shadowCenter = CGPoint(x: vinylCenter.x + vinylR * 0.08, y: vinylCenter.y + vinylRy * 1.3)
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: shadowCenter.x - shadowR,
                        y: shadowCenter.y - shadowRy,
                        width: shadowR * 2,
                        height: shadowRy * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [Color.black.opacity(0.55), Color.clear]),
                        center: shadowCenter,
                        startRadius: 0,
                        endRadius: shadowR
                    )
                )

                // 黑胶侧壁厚度
                let vinylThickness: CGFloat = 3
                ctx.fill(
                    Path(CGRect(x: vinylCenter.x - vinylR, y: vinylCenter.y, width: vinylR * 2, height: vinylThickness)),
                    with: .color(armShadowC)
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: vinylCenter.x - vinylR,
                        y: vinylCenter.y + vinylThickness - vinylRy,
                        width: vinylR * 2,
                        height: vinylRy * 2
                    )),
                    with: .color(armShadowC)
                )
            }
        }

        // ========= 黑胶（连续 morph 主物体）=========
        drawVinyl(
            context: context,
            center: vinylCenter,
            radius: vinylR,
            squash: squash,
            binCount: binCount,
            idleBlend: idleBlend,
            labelColor: cartridgeRed
        )

        // ========= 唱臂 + 唱头（淡入）=========
        if sceneAlpha > 0.01 {
            context.drawLayer { ctx in
                ctx.opacity = sceneAlpha
                drawToneArm(
                    ctx: ctx, w: w, h: h,
                    vinylCenter: vinylCenter, vinylR: vinylR, squash: squash,
                    armMetal: armMetal, armShadowC: armShadowC, cartridgeRed: cartridgeRed
                )
            }
        }
    }

    private func drawToneArm(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        vinylCenter: CGPoint, vinylR: CGFloat, squash: CGFloat,
        armMetal: Color, armShadowC: Color, cartridgeRed: Color
    ) {
        let pivotOutside = CGPoint(x: w * 1.08, y: -h * 0.08)

        let avgBass = spectrumData.prefix(4).reduce(Float(0), +) / 4
        let tipAngle: Double = -.pi * 0.30 + Double(avgBass) * 0.12
        let tipRatio: CGFloat = 0.76 - CGFloat(avgBass) * 0.10
        let tipOnVinyl = CGPoint(
            x: vinylCenter.x + vinylR * tipRatio * cos(tipAngle),
            y: vinylCenter.y + vinylR * tipRatio * sin(tipAngle) * squash
        )

        let dx = tipOnVinyl.x - pivotOutside.x
        let dy = tipOnVinyl.y - pivotOutside.y
        let midX = pivotOutside.x + dx * 0.55
        let midY = pivotOutside.y + dy * 0.55
        let segLen = sqrt(dx * dx + dy * dy)
        let perpX = -dy / segLen
        let perpY = dx / segLen
        let perpLen: CGFloat = 22
        let sign: CGFloat = perpY < 0 ? 1 : -1
        let bentMid = CGPoint(
            x: midX + perpX * perpLen * sign,
            y: midY + perpY * perpLen * sign
        )

        var armShadow = Path()
        armShadow.move(to: CGPoint(x: pivotOutside.x + 2, y: pivotOutside.y + 3))
        armShadow.addQuadCurve(
            to: CGPoint(x: tipOnVinyl.x + 2, y: tipOnVinyl.y + 3),
            control: CGPoint(x: bentMid.x + 2, y: bentMid.y + 3)
        )
        ctx.stroke(armShadow, with: .color(Color.black.opacity(0.45)), lineWidth: 5)

        var armDarkPath = Path()
        armDarkPath.move(to: pivotOutside)
        armDarkPath.addQuadCurve(to: tipOnVinyl, control: bentMid)
        ctx.stroke(armDarkPath, with: .color(armShadowC), lineWidth: 5)

        var armLightPath = Path()
        armLightPath.move(to: pivotOutside)
        armLightPath.addQuadCurve(to: tipOnVinyl, control: bentMid)
        ctx.stroke(armLightPath, with: .color(armMetal), lineWidth: 3)

        var armShine = Path()
        armShine.move(to: CGPoint(x: pivotOutside.x, y: pivotOutside.y - 0.8))
        armShine.addQuadCurve(
            to: CGPoint(x: tipOnVinyl.x, y: tipOnVinyl.y - 0.8),
            control: CGPoint(x: bentMid.x, y: bentMid.y - 0.8)
        )
        ctx.stroke(armShine, with: .color(Color.white.opacity(0.5)), lineWidth: 0.6)

        let headAngle = atan2(tipOnVinyl.y - bentMid.y, tipOnVinyl.x - bentMid.x)
        let headW: CGFloat = 22
        let headH: CGFloat = 11
        let headCenter = CGPoint(
            x: tipOnVinyl.x - cos(headAngle) * headW * 0.32,
            y: tipOnVinyl.y - sin(headAngle) * headW * 0.32
        )
        let headT = CGAffineTransform(translationX: headCenter.x, y: headCenter.y).rotated(by: CGFloat(headAngle))
        let shadowHead = Path(roundedRect: CGRect(x: -headW / 2 + 1, y: -headH / 2 + 3, width: headW, height: headH), cornerRadius: 2).applying(headT)
        ctx.fill(shadowHead, with: .color(Color.black.opacity(0.55)))
        let mainHead = Path(roundedRect: CGRect(x: -headW / 2, y: -headH / 2, width: headW, height: headH), cornerRadius: 2).applying(headT)
        ctx.fill(mainHead, with: .color(cartridgeRed))
        ctx.stroke(mainHead, with: .color(Color.black.opacity(0.5)), lineWidth: 0.6)
        let hlRect = CGRect(x: -headW / 2 + 1.8, y: -headH / 2 + 0.8, width: headW - 3.6, height: 1.3)
        let hlHead = Path(roundedRect: hlRect, cornerRadius: 0.6).applying(headT)
        ctx.fill(hlHead, with: .color(Color.white.opacity(0.30)))

        var needle = Path()
        needle.move(to: tipOnVinyl)
        let needleEnd = CGPoint(
            x: tipOnVinyl.x + cos(headAngle + .pi / 2) * 3.2,
            y: tipOnVinyl.y + sin(headAngle + .pi / 2) * 3.2
        )
        needle.addLine(to: needleEnd)
        ctx.stroke(needle, with: .color(armMetal), lineWidth: 1.0)
    }

    // MARK: - 黑胶唱片（物体本身 — 在两个 pose 里都存在）

    private func drawVinyl(
        context: GraphicsContext,
        center: CGPoint,
        radius vinylR: CGFloat,
        squash: CGFloat,
        binCount: Int,
        idleBlend: Float,
        labelColor: Color = Color(red: 0.58, green: 0.20, blue: 0.16)
    ) {
        let cx = center.x
        let cy = center.y
        let vinylRy = vinylR * squash

        let discRect = CGRect(x: cx - vinylR, y: cy - vinylRy, width: vinylR * 2, height: vinylRy * 2)
        context.fill(
            Path(ellipseIn: discRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.03, green: 0.03, blue: 0.04)
                ]),
                center: CGPoint(x: cx - vinylR * 0.25, y: cy - vinylRy * 0.35),
                startRadius: 1,
                endRadius: vinylR * 1.3
            )
        )
        context.stroke(
            Path(ellipseIn: discRect),
            with: .color(Color(red: 0.01, green: 0.01, blue: 0.02)),
            lineWidth: 1.0
        )

        for i in 1...18 {
            let r = vinylR * (0.30 + CGFloat(i) * 0.038)
            let ry = r * squash
            let alpha = 0.02 + Double(i % 3) * 0.015
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - ry, width: r * 2, height: ry * 2)),
                with: .color(Color.white.opacity(alpha)),
                lineWidth: 0.3
            )
        }

        var shineScale = CGAffineTransform(translationX: cx, y: cy)
        shineScale = shineScale.scaledBy(x: 1, y: squash)
        shineScale = shineScale.translatedBy(x: -cx, y: -cy)

        let outerArc = Path { p in
            p.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: vinylR * 0.92,
                startAngle: .radians(-Double.pi * 0.60),
                endAngle: .radians(-Double.pi * 0.05),
                clockwise: false
            )
        }
        context.stroke(outerArc.applying(shineScale), with: .color(Color.white.opacity(0.08)), lineWidth: 3)

        let innerArc = Path { p in
            p.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: vinylR * 0.82,
                startAngle: .radians(-Double.pi * 0.42),
                endAngle: .radians(-Double.pi * 0.18),
                clockwise: false
            )
        }
        context.stroke(innerArc.applying(shineScale), with: .color(Color.white.opacity(0.24)), lineWidth: 1.6)

        let wavePoints = 144
        var wavePath = Path()
        let baseR = vinylR * 1.02
        let waveAmp = vinylR * 0.10
        for i in 0...wavePoints {
            let t = Float(i) / Float(wavePoints)
            let angle = Double(t) * 2 * .pi - .pi / 2
            let bin = min(Int(t * Float(binCount - 1)), binCount - 1)
            let raw = spectrumData[bin]
            let idleVal: Float = 0.28 + 0.18 * sinf(t * .pi * 2 * 5)
            let value = CGFloat(raw * (1 - idleBlend) + idleVal * idleBlend)

            let r = baseR + waveAmp * value
            let px = cx + r * cos(angle)
            let py = cy + r * sin(angle) * squash
            if i == 0 { wavePath.move(to: CGPoint(x: px, y: py)) }
            else { wavePath.addLine(to: CGPoint(x: px, y: py)) }
        }
        context.stroke(wavePath, with: .color(labelColor.opacity(0.10)), lineWidth: 4)
        context.stroke(wavePath, with: .color(labelColor.opacity(0.6)), lineWidth: 1.2)

        let avgBass = spectrumData.prefix(4).reduce(Float(0), +) / 4
        let labelR = vinylR * (0.22 + CGFloat(avgBass) * 0.018)
        let labelRy = labelR * squash
        let labelRect = CGRect(x: cx - labelR, y: cy - labelRy, width: labelR * 2, height: labelRy * 2)
        context.fill(
            Path(ellipseIn: labelRect),
            with: .radialGradient(
                Gradient(colors: [
                    labelColor,
                    labelColor.opacity(0.7)
                ]),
                center: CGPoint(x: cx - labelR * 0.25, y: cy - labelRy * 0.35),
                startRadius: 1,
                endRadius: labelR * 1.2
            )
        )
        let innerLabelR = labelR * 0.50
        let innerLabelRy = innerLabelR * squash
        context.stroke(
            Path(ellipseIn: CGRect(x: cx - innerLabelR, y: cy - innerLabelRy, width: innerLabelR * 2, height: innerLabelRy * 2)),
            with: .color(Color.black.opacity(0.25)),
            lineWidth: 0.5
        )

        let holeR: CGFloat = max(2, vinylR * 0.022)
        let holeRy = holeR * squash
        context.fill(
            Path(ellipseIn: CGRect(x: cx - holeR, y: cy - holeRy, width: holeR * 2, height: holeRy * 2)),
            with: .color(Color.black.opacity(0.9))
        )
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

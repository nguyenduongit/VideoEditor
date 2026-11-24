import Foundation
import CoreGraphics
import Domain

extension AudiogramVectorRenderer {
    static func drawBassSpeaker(
        in ctx: CGContext, rect: CGRect,
        frame: AudioReactiveFrame, primary: RGBA, secondary: RGBA
    ) {
        let dim = min(rect.width, rect.height)
        let pulse = CGFloat(frame.bassLevel * 0.14 + frame.beatImpulse * 0.16)
        let cabinetW = dim * (0.58 + pulse * 0.08)
        let cabinetH = dim * (0.76 + pulse * 0.08)
        let cabRect = CGRect(x: rect.midX - cabinetW * 0.5, y: rect.midY - cabinetH * 0.5, width: cabinetW, height: cabinetH)

        if frame.beatImpulse > 0.12 {
            let shockR = dim * (0.39 + CGFloat(frame.beatImpulse) * 0.11)
            ctx.setStrokeColor(cgColor(primary, alpha: CGFloat(frame.beatImpulse) * 0.55))
            ctx.setLineWidth(max(2.0, dim * 0.015))
            ctx.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: shockR, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
            ctx.strokePath()
        }

        fillRoundedRect(in: ctx, rect: cabRect, radius: cabinetW * 0.16, color: CGColor(red: 0.12, green: 0.13, blue: 0.17, alpha: 0.96))
        ctx.setStrokeColor(cgColor(primary, alpha: 0.9))
        ctx.setLineWidth(max(2.0, dim * 0.018))
        let outline = CGPath(roundedRect: cabRect, cornerWidth: cabinetW * 0.16, cornerHeight: cabinetW * 0.16, transform: nil)
        ctx.addPath(outline)
        ctx.strokePath()

        let tweeterCenter = CGPoint(x: rect.midX, y: cabRect.maxY - cabinetH * 0.23)
        let tweeterR = cabinetW * (0.14 + CGFloat(frame.trebleLevel) * 0.04)
        fillCircle(in: ctx, center: tweeterCenter, radius: tweeterR, color: cgColor(secondary, alpha: 0.92))
        fillCircle(in: ctx, center: tweeterCenter, radius: tweeterR * 0.45, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))

        let wooferCenter = CGPoint(x: rect.midX, y: cabRect.minY + cabinetH * 0.36)
        let wooferR = cabinetW * (0.30 + pulse * 0.25)
        fillCircle(in: ctx, center: wooferCenter, radius: wooferR, color: cgColor(primary, alpha: 0.28))
        ctx.setStrokeColor(cgColor(primary, alpha: 0.96))
        ctx.setLineWidth(max(2.5, dim * 0.022))
        ctx.addArc(center: wooferCenter, radius: wooferR, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.strokePath()
        fillCircle(in: ctx, center: wooferCenter, radius: wooferR * 0.62, color: cgColor(secondary, alpha: 0.88))
        fillCircle(in: ctx, center: wooferCenter, radius: wooferR * 0.28, color: CGColor(red: 0.98, green: 0.98, blue: 1, alpha: 0.92))
    }

    static func drawMusicNotePulse(
        in ctx: CGContext, rect: CGRect,
        frame: AudioReactiveFrame, primary: RGBA, secondary: RGBA
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dim = min(rect.width, rect.height)
        let pulse = CGFloat(frame.overallLevel * 0.18 + frame.beatImpulse * 0.22)

        for ringIdx in 0..<2 {
            let expand = CGFloat(ringIdx) * 0.09 + pulse * (ringIdx == 0 ? 0.5 : 0.95)
            let r = dim * (0.28 + expand)
            let alpha = max(0.15, (0.65 - CGFloat(ringIdx) * 0.25) * CGFloat(0.45 + frame.beatImpulse * 0.55))
            ctx.setStrokeColor(cgColor(ringIdx == 0 ? primary : secondary, alpha: alpha))
            ctx.setLineWidth(max(2.0, dim * 0.016))
            ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
            ctx.strokePath()
        }

        for side in [-1.0, 1.0] {
            for b in 0..<3 {
                let amp = sampleBand(frame.bands, normalizedPosition: Double(b) * 0.35)
                let angleSpan = CGFloat(0.45 + amp * 0.45)
                let arcR = dim * (0.31 + CGFloat(b) * 0.065)
                let baseAngle: CGFloat = side > 0 ? 0.0 : .pi
                ctx.setStrokeColor(blendRGBA(primary, secondary, t: Double(b) / 2.0, alpha: 0.85))
                ctx.setLineWidth(max(2.5, dim * 0.02))
                ctx.setLineCap(.round)
                ctx.addArc(center: center, radius: arcR, startAngle: baseAngle - angleSpan * 0.5, endAngle: baseAngle + angleSpan * 0.5, clockwise: false)
                ctx.strokePath()
            }
        }

        drawJoinedNoteGlyph(in: ctx, center: center, scale: dim * (0.42 + pulse * 0.28), primary: primary, secondary: secondary)
    }

    static func drawVinylEqualizer(
        in ctx: CGContext, rect: CGRect, count: Int,
        frame: AudioReactiveFrame, time: Double, primary: RGBA, secondary: RGBA
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dim = min(rect.width, rect.height)
        let discR = dim * (0.27 + CGFloat(frame.bassLevel * 0.03 + frame.beatImpulse * 0.025))
        let spikes = max(16, count)

        for i in 0..<spikes {
            let t = Double(i) / Double(spikes)
            let amp = sampleBand(frame.bands, normalizedPosition: t <= 0.5 ? t * 2.0 : (1.0 - t) * 2.0)
            let ang = CGFloat(t * 2.0 * .pi) - .pi * 0.5
            let innerR = discR + dim * 0.025
            let outerR = innerR + dim * 0.16 * CGFloat(amp)
            ctx.setStrokeColor(blendRGBA(primary, secondary, t: t, alpha: 0.94))
            ctx.setLineWidth(max(2.0, dim * 0.02))
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: center.x + cos(ang) * innerR, y: center.y + sin(ang) * innerR))
            ctx.addLine(to: CGPoint(x: center.x + cos(ang) * outerR, y: center.y + sin(ang) * outerR))
            ctx.strokePath()
        }

        fillCircle(in: ctx, center: center, radius: discR, color: CGColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 0.98))
        ctx.setStrokeColor(cgColor(primary, alpha: 0.75))
        ctx.setLineWidth(max(1.5, dim * 0.01))
        ctx.addArc(center: center, radius: discR * 0.78, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.strokePath()

        let spin = CGFloat(time * 2.2)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.45))
        ctx.setLineWidth(max(2.0, dim * 0.015))
        ctx.setLineCap(.round)
        ctx.addArc(center: center, radius: discR * 0.62, startAngle: spin, endAngle: spin + 0.9, clockwise: false)
        ctx.strokePath()

        fillCircle(in: ctx, center: center, radius: discR * 0.36, color: cgColor(secondary, alpha: 0.95))
        fillCircle(in: ctx, center: center, radius: discR * 0.10, color: CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
    }

    static func drawDotMatrix(
        in ctx: CGContext, rect: CGRect, count: Int,
        frame: AudioReactiveFrame, primary: RGBA, secondary: RGBA
    ) {
        let cols = max(8, count)
        let rows = 8
        let padX = rect.width * 0.08
        let padY = rect.height * 0.12
        let slotW = (rect.width - padX * 2.0) / CGFloat(cols)
        let slotH = (rect.height - padY * 2.0) / CGFloat(rows)
        let cellW = max(3.0, slotW * 0.68)
        let cellH = max(3.0, slotH * 0.62)

        for c in 0..<cols {
            let u = Double(c) / Double(max(1, cols - 1))
            let level = sampleBand(frame.bands, normalizedPosition: u)
            let litRows = max(1, Int((level * Double(rows)).rounded()))
            let x = padX + CGFloat(c) * slotW + (slotW - cellW) * 0.5

            for r in 0..<rows {
                let y = padY + CGFloat(r) * slotH + (slotH - cellH) * 0.5
                let cellRect = CGRect(x: x, y: y, width: cellW, height: cellH)
                if r < litRows {
                    let rowT = Double(r) / Double(max(1, rows - 1))
                    fillRoundedRect(in: ctx, rect: cellRect, radius: min(cellW, cellH) * 0.35, color: blendRGBA(primary, secondary, t: rowT, alpha: 0.96))
                } else {
                    fillRoundedRect(in: ctx, rect: cellRect, radius: min(cellW, cellH) * 0.35, color: cgColor(primary, alpha: 0.10))
                }
            }
        }
    }

    private static func drawJoinedNoteGlyph(
        in ctx: CGContext, center: CGPoint, scale: CGFloat, primary: RGBA, secondary: RGBA
    ) {
        let noteColor = blendRGBA(primary, secondary, t: 0.35, alpha: 1.0)
        let headR = scale * 0.14
        let leftHead = CGPoint(x: center.x - scale * 0.16, y: center.y - scale * 0.22)
        let rightHead = CGPoint(x: center.x + scale * 0.16, y: center.y - scale * 0.16)
        fillCircle(in: ctx, center: leftHead, radius: headR, color: noteColor)
        fillCircle(in: ctx, center: rightHead, radius: headR, color: noteColor)

        ctx.setStrokeColor(noteColor)
        ctx.setLineWidth(max(3.0, scale * 0.095))
        ctx.setLineCap(.round)
        let topYLeft = center.y + scale * 0.24
        let topYRight = center.y + scale * 0.30
        ctx.move(to: CGPoint(x: leftHead.x + headR * 0.75, y: leftHead.y))
        ctx.addLine(to: CGPoint(x: leftHead.x + headR * 0.75, y: topYLeft))
        ctx.addLine(to: CGPoint(x: rightHead.x + headR * 0.75, y: topYRight))
        ctx.addLine(to: CGPoint(x: rightHead.x + headR * 0.75, y: rightHead.y))
        ctx.strokePath()
    }

    private static func fillCircle(in ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
        guard radius > 0.5 else { return }
        ctx.setFillColor(color)
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.fillPath()
    }
}

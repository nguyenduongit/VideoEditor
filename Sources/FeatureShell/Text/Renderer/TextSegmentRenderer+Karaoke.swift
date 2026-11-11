import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain

/// Phần mở rộng hỗ trợ hiệu ứng Karaoke Highlight Box và Karaoke Glow.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TextSegmentRenderer {
    #if os(macOS)
    internal static func drawKaraokeHighlightBox(
        tokens: [TextToken],
        visibleIndices: [Int],
        activeOrder: Int,
        localFrac: Double,
        startX: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        in context: CGContext
    ) {
        let clampedOrder = max(0, min(visibleIndices.count - 1, activeOrder))
        let currentToken = tokens[visibleIndices[clampedOrder]]
        var boxX = startX + currentToken.relativeX
        var boxW = currentToken.width

        // Nội suy trượt mượt sang từ kế tiếp ở 25% cuối thời lượng mỗi từ
        if localFrac > 0.72, clampedOrder + 1 < visibleIndices.count {
            let nextToken = tokens[visibleIndices[clampedOrder + 1]]
            let slideT = TextAnimationCurves.springOvershoot((localFrac - 0.72) / 0.28, tension: 1.5)
            let nextX = startX + nextToken.relativeX
            boxX += (nextX - boxX) * CGFloat(slideT)
            boxW += (nextToken.width - boxW) * CGFloat(slideT)
        }

        let padX: CGFloat = max(8.0, CGFloat(baseConfig.fontSize) * 0.16)
        let padY: CGFloat = max(4.0, CGFloat(baseConfig.fontSize) * 0.10)
        let bounceScale = 1.0 + CGFloat(sin(localFrac * .pi) * 0.08)
        let rect = CGRect(
            x: boxX - padX,
            y: (-totalHeight / 2.0 - padY) * bounceScale,
            width: boxW + padX * 2.0,
            height: (totalHeight + padY * 2.0) * bounceScale
        )
        let corner = max(6.0, CGFloat(baseConfig.backgroundCornerRadius))
        context.saveGState()
        let path = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
        TextRendererEngine.parseHexColor(baseConfig.animation.highlightColorHex).setFill()
        path.fill()
        context.restoreGState()
    }

    internal static func applyKaraokeTokenStyle(
        evaluated: inout TextAnimationEvaluator.EvaluationResult,
        isActive: Bool,
        localFrac: Double,
        isGlowMode: Bool,
        highlightHex: String
    ) {
        var cfg = evaluated.config
        var ov = evaluated.overlay
        if isActive {
            let pop = 1.0 + sin(min(1.0, localFrac * 1.5) * .pi) * 0.22
            cfg.scale *= pop
            let jelly = TextAnimationCurves.jellySquashStretch(progress: localFrac, amplitude: 0.20, frequency: 2.0)
            ov.scaleX *= jelly.scaleX
            ov.scaleY *= jelly.scaleY
            if isGlowMode {
                cfg.textColorHex = highlightHex
                cfg.hasGlow = true
                cfg.glowColorHex = highlightHex
                cfg.glowRadius = max(14.0, cfg.glowRadius)
            }
        } else if isGlowMode {
            cfg.opacity *= 0.65
        }
        evaluated = TextAnimationEvaluator.EvaluationResult(
            config: cfg, blurRadius: evaluated.blurRadius, hueAngle: evaluated.hueAngle,
            pixelateScale: evaluated.pixelateScale, rgbSplitIntensity: evaluated.rgbSplitIntensity, overlay: ov
        )
    }

    internal static func drawTrailingCursorBar(
        config: TextConfiguration,
        font: NSFont,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        cursorOpacity: Double,
        in context: CGContext
    ) {
        let barW = max(2.2, font.pointSize * 0.062)
        let barH = max(12.0, totalHeight * 0.86)
        let gap = max(3.0, font.pointSize * 0.08)
        let cursorX = config.opacity > 0.005 ? (tokenWidth / 2.0 + gap) : (-tokenWidth / 2.0)
        let barRect = CGRect(x: cursorX, y: -barH / 2.0, width: barW, height: barH)
        let cursorColor = TextAdvancedStyleRenderer.parseHexColor(config.textColorHex)
            .withAlphaComponent(CGFloat(max(0.0, min(1.0, cursorOpacity))))
        context.saveGState()
        context.setFillColor(cursorColor.cgColor)
        context.fill(barRect)
        context.restoreGState()
    }

    internal static func resolveTokenWaveAndCurveCenter(
        evaluated: inout TextAnimationEvaluator.EvaluationResult,
        baseConfig: TextConfiguration,
        tokenCenter: CGFloat,
        totalWidth: CGFloat,
        orderIndex: Int,
        visibleCount: Int
    ) -> CGPoint {
        let em = max(16.0, baseConfig.fontSize)
        let centerIdx = Double(max(1, visibleCount - 1)) * 0.5
        if abs(evaluated.overlay.trackingEmDelta) > 0.001 {
            evaluated.config.positionX += (Double(orderIndex) - centerIdx) * evaluated.overlay.trackingEmDelta * em
        }
        if abs(evaluated.overlay.waveAmplitudeEm) > 0.001 {
            let amp = evaluated.overlay.waveAmplitudeEm
            let freq = evaluated.overlay.waveFrequencyEm
            let phase = evaluated.overlay.wavePhaseRadians

            let approxEmX = (Double(orderIndex) - centerIdx) * 0.62 + evaluated.config.positionX / em
            let approxTheta = approxEmX * freq + phase
            let approxWaveY = -amp * em * sin(approxTheta)
            let approxRot = -atan(amp * freq * cos(approxTheta)) * 180.0 / .pi

            let actualEmX = (Double(tokenCenter) + evaluated.config.positionX) / em
            let actualTheta = actualEmX * freq + phase
            let actualWaveY = -amp * em * sin(actualTheta)
            let actualRot = -atan(amp * freq * cos(actualTheta)) * 180.0 / .pi

            evaluated.config.positionY += (actualWaveY - approxWaveY)
            evaluated.config.rotation += (actualRot - approxRot)
        }
        let (curvePt, curveTangentRad) = TextCurvedPathBuilder.evaluateCurve(
            x: tokenCenter,
            totalWidth: totalWidth,
            baselineOffset: 0.0,
            curve: baseConfig.curve
        )
        if baseConfig.curve.isActive && baseConfig.curve.followTangent {
            evaluated.config.rotation -= Double(curveTangentRad) * 180.0 / .pi
        }
        return curvePt
    }

    internal static func renderTokenGlyphAndEchoes(
        config: TextConfiguration,
        font: NSFont,
        overlay: TextTransformOverlay,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        if overlay.clipRevealX < 0.999 || overlay.clipRevealY < 0.999 {
            let padX = max(8.0, font.pointSize * 0.28)
            let padY = max(8.0, totalHeight * 0.35)
            let fullW = tokenWidth + padX * 2.0
            let fullH = totalHeight + padY * 2.0
            let clipW = fullW * CGFloat(max(0.0, min(1.0, overlay.clipRevealX)))
            let clipH = fullH * CGFloat(max(0.0, min(1.0, overlay.clipRevealY)))
            let clipRect = CGRect(x: -fullW / 2.0, y: -fullH / 2.0, width: clipW, height: clipH)
            context.clip(to: clipRect)
        }

        if overlay.echoCount > 0, config.opacity > 0.01 {
            let em = CGFloat(max(16.0, config.fontSize))
            for idx in (1...overlay.echoCount).reversed() {
                let factor = CGFloat(idx)
                let echoAlpha = CGFloat(config.opacity) * (0.36 / factor)
                context.saveGState()
                context.translateBy(
                    x: CGFloat(overlay.echoOffsetXEm) * em * factor,
                    y: -CGFloat(overlay.echoOffsetYEm) * em * factor
                )
                context.setAlpha(max(0.0, min(1.0, echoAlpha)))
                TextAdvancedStyleRenderer.drawStyledTokenString(config.content, font: font, config: config, in: context)
                context.restoreGState()
            }
        }

        if config.opacity < 1.0 {
            context.setAlpha(CGFloat(max(0.0, config.opacity)))
        }
        TextAdvancedStyleRenderer.drawStyledTokenString(config.content, font: font, config: config, in: context)
        context.restoreGState()
    }
    #endif
}

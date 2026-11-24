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
    internal static func splitWordsPreservingSpaces(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for char in text {
            if char.isWhitespace {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    internal static func applyKaraokeTokenStyle(
        evaluated: inout TextAnimationEvaluator.EvaluationResult,
        isActive: Bool,
        localFrac: Double,
        isGlowMode: Bool
    ) {
        var cfg = evaluated.config
        var ov = evaluated.overlay
        if isActive {
            let pop = 1.0 + sin(min(1.0, localFrac * 1.5) * .pi) * 0.22
            cfg.scale *= pop
            let jelly = TextAnimationCurves.jellySquashStretch(progress: localFrac, amplitude: 0.20, frequency: 2.0)
            ov.scaleX *= jelly.scaleX
            ov.scaleY *= jelly.scaleY
            if isGlowMode, cfg.hasGlow {
                cfg.glowRadius = max(14.0, cfg.glowRadius)
            }
        } else if isGlowMode {
            cfg.opacity *= 0.65
        }
        evaluated = TextAnimationEvaluator.EvaluationResult(
            config: cfg,
            blurRadius: evaluated.blurRadius,
            pixelateScale: evaluated.pixelateScale,
            rgbSplitIntensity: 0.0,
            noiseIntensity: evaluated.noiseIntensity,
            overlay: ov,
            animationParameters: evaluated.animationParameters
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
        tokenRelativeY: CGFloat = 0.0,
        totalWidth: CGFloat,
        orderIndex: Int,
        visibleCount: Int
    ) -> CGPoint {
        let em = max(16.0, baseConfig.fontSize)
        let centerIdx = Double(max(1, visibleCount - 1)) * 0.5
        if abs(evaluated.overlay.trackingEmDelta) > 0.001 {
            evaluated.config.positionX += (Double(orderIndex) - centerIdx) * evaluated.overlay.trackingEmDelta * em
        }
        if !baseConfig.animation.hasScriptAnimation, abs(evaluated.overlay.waveAmplitudeEm) > 0.001 {
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
            baselineOffset: tokenRelativeY,
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
            let fullBounds = CGRect(x: -fullW / 2.0, y: -fullH / 2.0, width: fullW, height: fullH)
            TextMaskClipHelper.applyMask(
                bounds: fullBounds, clipRevealX: overlay.clipRevealX,
                clipRevealY: overlay.clipRevealY, mode: overlay.maskShapeMode, in: context
            )
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
        if overlay.strokeTrimProgress < 0.999 {
            let layout = TextRenderPerformanceCache.shared.cachedShapedLayout(
                text: config.content, font: font, config: config,
                curveOverride: TextCurveStyle(shape: .none), preserveBaseline: true
            )
            let key = "tok|\(config.content)|\(config.fontName)|\(Int(config.fontSize * 100))|\(config.isBold)|\(config.isItalic)"
            TextPathTrimRenderer.drawTrimmedGlyphPath(
                layout.combinedPath, pathBounds: layout.bounds, cacheKey: key,
                trimProgress: overlay.strokeTrimProgress, config: config, in: context
            )
        } else {
            TextAdvancedStyleRenderer.drawStyledTokenString(config.content, font: font, config: config, in: context)
        }
        context.restoreGState()
    }

    internal static func applyTokenTransform(
        _ config: TextConfiguration,
        overlay: TextTransformOverlay,
        center: CGPoint,
        totalHeight: CGFloat,
        in context: CGContext
    ) {
        let pivotOffsetY: CGFloat
        switch config.animation.anchorPoint {
        case .center: pivotOffsetY = 0.0
        case .bottom: pivotOffsetY = -totalHeight / 2.0
        case .top: pivotOffsetY = totalHeight / 2.0
        }
        context.translateBy(x: center.x + CGFloat(config.positionX), y: center.y - CGFloat(config.positionY) + pivotOffsetY)
        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        let totalSkewX = overlay.skewX + tan(config.skewX * .pi / 180.0)
        let totalSkewY = tan(config.skewY * .pi / 180.0)
        if abs(totalSkewX) > 0.001 || abs(totalSkewY) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: CGFloat(totalSkewY), c: CGFloat(totalSkewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 {
            context.scaleBy(x: sx, y: sy)
        }
        context.translateBy(x: 0, y: -pivotOffsetY)
    }
    #endif
}

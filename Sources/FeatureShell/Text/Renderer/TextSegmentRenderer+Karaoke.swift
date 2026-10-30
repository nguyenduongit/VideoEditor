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
    #endif
}

import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Phần mở rộng kết xuất hoạt ảnh phân tách ký tự (Per-Character Kinetic Typography) chuẩn CapCut.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TextRendererEngine {

    /// Determines whether text should render per-line / per-word / per-character for the active `TextAnimationScript`.
    public func shouldRenderSegmented(for config: TextConfiguration) -> Bool {
        guard !config.animation.isDefault else { return false }
        if config.animation.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: config.animation.scriptId) {
            let effective = config.animation.scopeOverride ?? script.scope
            return effective != .wholeBlock
        }
        return (config.animation.scopeOverride ?? config.animation.scope) != .wholeBlock
    }

    #if os(macOS)
    /// Renders per-line / per-word / per-character kinetic typography driven by unified scripts.
    internal func renderSegmentedAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard width > 0, height > 0,
              let context = createBitmapContext(width: width, height: height) else { return nil }

        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        let effectiveScope: TextAnimationScope
        if config.animation.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: config.animation.scriptId) {
            effectiveScope = config.animation.scopeOverride ?? script.scope
        } else if let overrideScope = config.animation.scopeOverride, overrideScope != .wholeBlock {
            effectiveScope = overrideScope
        } else if config.animation.scope != .wholeBlock {
            effectiveScope = config.animation.scope
        } else {
            effectiveScope = config.content.count > 50 ? .perWord : .perCharacter
        }

        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let displayContent = config.content.precomposedStringWithCanonicalMapping
        let (tokens, totalWidth) = TextRenderPerformanceCache.shared.cachedTokenize(
            content: displayContent, scope: effectiveScope,
            font: font, config: config
        )
        let textSize = measureCoreGlyphBounds(for: config)

        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        context.saveGState()
        context.translateBy(x: cx, y: cy)

        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if totalWidth > maxSafeW && totalWidth > 0 {
            let safeguardScale = maxSafeW / totalWidth
            context.scaleBy(x: safeguardScale, y: safeguardScale)
        }
        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        if abs(config.scale - 1.0) > 0.001 {
            context.scaleBy(x: CGFloat(config.scale), y: CGFloat(config.scale))
        }

        TextSegmentRenderer.drawSegmentedText(
            tokens: tokens, totalWidth: totalWidth, totalHeight: textSize.height,
            baseConfig: config, font: font, localTime: localTime, duration: duration,
            canvasSize: canvasSize, in: context
        )
        context.restoreGState()

        guard let cgImage = context.makeImage() else { return nil }
        var ciImage = CIImage(cgImage: cgImage)
        ciImage = TextSVGAndAssetCache.applyPremultipliedOpacity(config.opacity, to: ciImage)
        let globalEval = TextAnimationEvaluator.evaluate(
            config: config, localTime: localTime, duration: duration, canvasSize: canvasSize,
            charIndex: max(0, tokens.count / 2), charCount: max(1, tokens.count)
        )
        return TextShaderFilterEngine.applyFilters(
            to: ciImage,
            blurRadius: config.blurRadius,
            hueAngle: globalEval.hueAngle,
            pixelateScale: globalEval.pixelateScale,
            rgbSplitIntensity: globalEval.rgbSplitIntensity,
            overlay: globalEval.overlay,
            lightSweepIntensity: config.animation.lightSweepIntensity,
            shadow: globalEval.config.shadow,
            glow: globalEval.config.glow,
            noiseIntensity: config.noiseIntensity
        )
    }
    #endif
}

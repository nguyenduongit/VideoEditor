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

    /// Determines whether text should render per-line / per-word / per-character for the active graph or script.
    public func shouldRenderSegmented(for config: TextConfiguration) -> Bool {
        guard !config.animation.isDefault else { return false }
        if let graph = config.animation.graph {
            let effective = config.animation.scopeOverride ?? graph.scope
            return effective != .wholeBlock
        }
        if config.animation.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: config.animation.scriptId) {
            let effective = config.animation.scopeOverride ?? script.scope
            return effective != .wholeBlock
        }
        return (config.animation.scopeOverride ?? config.animation.scope) != .wholeBlock
    }

    #if os(macOS)
    /// Renders per-line / per-word / per-character kinetic typography driven by unified graphs or scripts.
    internal func renderSegmentedAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double] = [:]
    ) -> CIImage? {
        let effectiveScope = resolveEffectiveSegmentedScope(for: config)
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let displayContent = config.content.precomposedStringWithCanonicalMapping
        let (tokens, totalWidth) = TextRenderPerformanceCache.shared.cachedTokenize(
            content: displayContent, scope: effectiveScope, font: font, config: config
        )
        let textSize = measureCoreGlyphBounds(for: config)

        let renderedSegmentLayer: (image: CIImage, handledStages: TextShaderFilterEngine.AppliedStagesMask)?
        if let gpuSeg = TextGPUSegmentedRenderer.renderSegmentedGPU(
            tokens: tokens, totalWidth: totalWidth, totalHeight: textSize.height,
            baseConfig: config, font: font, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs,
            renderPlugins: renderPlugins, atlasCache: glyphAtlasCache
        ) {
            renderedSegmentLayer = gpuSeg
        } else {
            renderedSegmentLayer = renderSegmentedViaCPUContext(
                tokens: tokens, totalWidth: totalWidth, totalHeight: textSize.height,
                config: config, font: font, localTime: localTime, duration: duration,
                canvasSize: canvasSize, animationInputs: animationInputs
            )
        }
        guard let (ciImage, handledPerTokenStages) = renderedSegmentLayer else { return nil }
        return finalizeSegmentedFilters(
            ciImage: ciImage, config: config, tokensCount: tokens.count,
            localTime: localTime, duration: duration, canvasSize: canvasSize,
            animationInputs: animationInputs, handledPerTokenStages: handledPerTokenStages
        )
    }

    private func renderSegmentedViaCPUContext(
        tokens: [TextSegmentRenderer.TextToken],
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        config: TextConfiguration,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double]
    ) -> (image: CIImage, handledStages: TextShaderFilterEngine.AppliedStagesMask)? {
        let width = Int(canvasSize.width), height = Int(canvasSize.height)
        guard width > 0, height > 0, let context = createBitmapContext(width: width, height: height) else { return nil }

        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        context.saveGState()
        context.translateBy(x: cx, y: cy)
        applySegmentedBlockTransform(totalWidth: totalWidth, config: config, canvasSize: canvasSize, in: context)
        let handled = TextSegmentRenderer.drawSegmentedText(
            tokens: tokens, totalWidth: totalWidth, totalHeight: totalHeight,
            baseConfig: config, font: font, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs, renderPlugins: renderPlugins, in: context
        )
        context.restoreGState()
        guard let cgImage = context.makeImage() else { return nil }
        let ciImg = TextSVGAndAssetCache.applyPremultipliedOpacity(config.opacity, to: CIImage(cgImage: cgImage))
        return (ciImg, handled)
    }

    private func finalizeSegmentedFilters(
        ciImage: CIImage,
        config: TextConfiguration,
        tokensCount: Int,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double],
        handledPerTokenStages: TextShaderFilterEngine.AppliedStagesMask
    ) -> CIImage {
        let globalEval = TextAnimationEvaluator.evaluate(
            config: config, localTime: localTime, duration: duration, canvasSize: canvasSize,
            charIndex: max(0, tokensCount / 2), charCount: max(1, tokensCount), externalInputs: animationInputs
        )
        var blockOverlay = globalEval.overlay
        blockOverlay.rotationX = 0.0
        blockOverlay.rotationY = 0.0
        let pluginCtx = TextAnimationRenderPluginContext(localTime: localTime, duration: duration, canvasSize: canvasSize)
        return TextShaderFilterEngine.applyFilters(
            to: ciImage, blurRadius: config.blurRadius,
            pixelateScale: globalEval.pixelateScale,
            overlay: blockOverlay,
            shadow: globalEval.config.shadow, glow: globalEval.config.glow,
            noiseIntensity: max(globalEval.noiseIntensity, config.noiseIntensity),
            localTime: localTime, animationParameters: globalEval.animationParameters,
            renderPlugins: renderPlugins, pluginContext: pluginCtx, skipStages: handledPerTokenStages
        )
    }

    private func resolveEffectiveSegmentedScope(for config: TextConfiguration) -> TextAnimationScope {
        if let graph = config.animation.graph {
            return config.animation.scopeOverride ?? graph.scope
        }
        if config.animation.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: config.animation.scriptId) {
            return config.animation.scopeOverride ?? script.scope
        }
        if let overrideScope = config.animation.scopeOverride, overrideScope != .wholeBlock {
            return overrideScope
        }
        if config.animation.scope != .wholeBlock {
            return config.animation.scope
        }
        return config.content.count > 50 ? .perWord : .perCharacter
    }

    private func applySegmentedBlockTransform(
        totalWidth: CGFloat,
        config: TextConfiguration,
        canvasSize: CGSize,
        in context: CGContext
    ) {
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
    }
    #endif
}

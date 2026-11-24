import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Engine kết xuất văn bản 1-Layer thống nhất (Text [Basic/Stroke/Style/Curved] · Background · Animation) ở 60fps.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
public final class TextRendererEngine: Sendable {
    public let renderPlugins: TextAnimationRenderPluginPipeline
    public let glyphAtlasCache: TextGlyphAtlasCache

    public init(
        renderPlugins: [any TextAnimationRenderPlugin] = [],
        glyphAtlasCache: TextGlyphAtlasCache = TextGlyphAtlasCache()
    ) {
        self.renderPlugins = TextAnimationRenderPluginPipeline(plugins: renderPlugins)
        self.glyphAtlasCache = glyphAtlasCache
    }

    /// Kết xuất văn bản tại thời điểm `localTime`, tự động dùng Static Bitmap Cache nếu khung hình đứng yên.
    public func renderAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double] = [:]
    ) -> CIImage? {
        guard !config.content.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let isStaticFrame = isFrameStatic(config: config, localTime: localTime, duration: duration)
        if isStaticFrame {
            var hasher = Hasher()
            hasher.combine(config)
            hasher.combine(Int(canvasSize.width))
            hasher.combine(Int(canvasSize.height))
            let cacheKey = hasher.finalize()
            if let cached = TextSVGAndAssetCache.shared.cachedTextImage(forKey: cacheKey) {
                return cached
            }
            if let rendered = renderDynamicComposite(
                for: config, localTime: localTime, duration: duration,
                canvasSize: canvasSize, animationInputs: animationInputs
            ) {
                TextSVGAndAssetCache.shared.storeTextImage(rendered, forKey: cacheKey)
                return rendered
            }
            return nil
        }

        return renderDynamicComposite(
            for: config, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs
        )
    }

    private func isFrameStatic(config: TextConfiguration, localTime: Double, duration: Double) -> Bool {
        if config.background.isEnabled && config.background.sourceKind == .animatedAsset {
            return false
        }
        let anim = config.animation
        return !anim.hasScriptAnimation && anim.lightSweepIntensity <= 0.01 && anim.rgbSplitIntensity <= 0.01
    }

    private func renderDynamicComposite(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double]
    ) -> CIImage? {
        let evaluated = TextAnimationEvaluator.evaluate(
            config: config,
            localTime: localTime,
            duration: duration,
            canvasSize: canvasSize,
            externalInputs: animationInputs
        )

        let textImage: CIImage?
        if shouldRenderSegmented(for: config) {
            textImage = renderSegmentedAnimatedImage(
                for: config,
                localTime: localTime,
                duration: duration,
                canvasSize: canvasSize,
                animationInputs: animationInputs
            )
        } else if let rawText = renderImage(
            for: evaluated.config,
            canvasSize: canvasSize,
            overlay: evaluated.overlay,
            localTime: localTime,
            duration: duration
        ) {
            let totalBlur = max(evaluated.blurRadius, config.blurRadius)
            let totalNoise = max(evaluated.noiseIntensity, config.noiseIntensity)
            let pluginCtx = TextAnimationRenderPluginContext(
                localTime: localTime,
                duration: duration,
                canvasSize: canvasSize
            )
            textImage = TextShaderFilterEngine.applyFilters(
                to: rawText,
                blurRadius: totalBlur,
                pixelateScale: evaluated.pixelateScale,
                rgbSplitIntensity: 0.0,
                overlay: evaluated.overlay,
                lightSweepIntensity: config.animation.lightSweepIntensity,
                shadow: evaluated.config.shadow,
                glow: evaluated.config.glow,
                noiseIntensity: totalNoise,
                localTime: localTime,
                animationParameters: evaluated.animationParameters,
                renderPlugins: renderPlugins,
                pluginContext: pluginCtx,
                skipStages: [.sdfMaterial]
            )
        } else {
            textImage = nil
        }

        #if os(macOS)
        return compositeWithBackground(
            textImage: textImage,
            baseConfig: config,
            evaluated: evaluated,
            canvasSize: canvasSize,
            localTime: localTime
        )
        #else
        return textImage
        #endif
    }

    #if os(macOS)
    private func compositeWithBackground(
        textImage: CIImage?,
        baseConfig: TextConfiguration,
        evaluated: TextAnimationEvaluator.EvaluationResult,
        canvasSize: CGSize,
        localTime: Double
    ) -> CIImage? {
        guard baseConfig.background.isEnabled else { return textImage }
        let rawGlyphBounds = measureCoreGlyphBounds(for: baseConfig)
        let envelopeBounds = measureBackgroundEnvelopeBounds(for: baseConfig)
        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        let safeguard: CGFloat = (rawGlyphBounds.width > maxSafeW && rawGlyphBounds.width > 0)
            ? (maxSafeW / rawGlyphBounds.width)
            : 1.0

        let followText = baseConfig.background.animateWithText
        guard let bgImg = TextCompositeLayerRenderer.renderBackground(
            background: baseConfig.background,
            anchorConfig: followText ? evaluated.config : baseConfig,
            overlay: followText ? evaluated.overlay : TextTransformOverlay(),
            textRawSize: followText ? rawGlyphBounds : envelopeBounds,
            safeguardScale: safeguard,
            canvasSize: canvasSize,
            localTime: localTime
        ) else {
            return textImage
        }

        guard let fgText = textImage else { return bgImg }
        return fgText.composited(over: bgImg)
    }
    #endif

    /// Kết xuất lớp chữ (thẳng hoặc cong Arc / Sine Wave) thành CIImage
    public func renderImage(
        for config: TextConfiguration,
        canvasSize: CGSize,
        overlay: TextTransformOverlay = TextTransformOverlay(),
        localTime: Double = 0.0,
        duration: Double = 4.0
    ) -> CIImage? {
        guard !config.content.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        #if os(macOS)
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        if let gpuImage = TextGPUGlyphRenderer.renderWholeBlock(
            config: config, overlay: overlay, canvasSize: canvasSize, font: font,
            atlasCache: glyphAtlasCache, localTime: localTime
        ) {
            return gpuImage
        }
        #endif

        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard let context = createBitmapContext(width: width, height: height) else { return nil }

        #if os(macOS)
        drawText(config: config, overlay: overlay, canvasSize: canvasSize, in: context)
        #endif

        guard let cgImage = context.makeImage() else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        return TextSVGAndAssetCache.applyPremultipliedOpacity(config.opacity, to: ciImage)
    }

    internal func createBitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    #if os(macOS)
    private func drawText(
        config: TextConfiguration,
        overlay: TextTransformOverlay,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let displayText = TextTokenFXRenderer.resolveDisplayText(
            config.content, scrambleStrength: overlay.scrambleStrength, unitIndex: 0
        )
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let layout = TextRenderPerformanceCache.shared.cachedShapedLayout(
            text: displayText,
            font: font,
            config: config
        )

        let textWidth = max(1.0, layout.bounds.width)
        let textHeight = max(1.0, layout.bounds.height)
        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        let pivotY: CGFloat = switch config.animation.anchorPoint {
        case .center: 0.0
        case .bottom: -textHeight / 2.0
        case .top: textHeight / 2.0
        }

        context.saveGState()
        context.translateBy(x: cx, y: cy + pivotY)
        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if textWidth > maxSafeW && textWidth > 0 {
            let safeguardScale = maxSafeW / textWidth
            context.scaleBy(x: safeguardScale, y: safeguardScale)
        }
        if abs(config.rotation) > 0.001 { context.rotate(by: CGFloat(-config.rotation * .pi / 180.0)) }
        let totalSkewX = overlay.skewX + tan(config.skewX * .pi / 180.0)
        let totalSkewY = tan(config.skewY * .pi / 180.0)
        if abs(totalSkewX) > 0.001 || abs(totalSkewY) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: CGFloat(totalSkewY), c: CGFloat(totalSkewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX)), sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 { context.scaleBy(x: sx, y: sy) }
        context.translateBy(x: 0, y: -pivotY)

        if config.animation.isMaskEnabled { context.clip(to: layout.bounds.insetBy(dx: -20.0, dy: -12.0)) }
        if overlay.clipRevealX < 0.999 || overlay.clipRevealY < 0.999 {
            TextMaskClipHelper.applyMask(
                bounds: layout.bounds.insetBy(dx: -16.0, dy: -16.0),
                clipRevealX: overlay.clipRevealX, clipRevealY: overlay.clipRevealY,
                mode: overlay.maskShapeMode, in: context
            )
        }
        if overlay.revealProgress >= 0.0 {
            let p = CGFloat(max(0.0, min(1.0, overlay.revealProgress)))
            context.clip(to: CGRect(x: layout.bounds.minX - 20.0, y: layout.bounds.minY - 20.0, width: (layout.bounds.width + 40.0) * p, height: layout.bounds.height + 40.0))
        }

        if overlay.strokeTrimProgress < 0.999 {
            let key = "\(displayText)|\(config.fontName)|\(Int(config.fontSize * 100))|\(config.isBold)|\(config.isItalic)|\(Int(config.characterSpacing * 100))"
            TextPathTrimRenderer.drawTrimmedGlyphPath(
                layout.combinedPath, pathBounds: layout.bounds, cacheKey: key,
                trimProgress: overlay.strokeTrimProgress, config: config, in: context
            )
        } else {
            TextAdvancedStyleRenderer.drawStyledVectorGlyphPath(layout.combinedPath, pathBounds: layout.bounds, config: config, in: context)
            TextCurvedPathBuilder.drawEmojiFallbacks(layout.emojiGlyphs, in: context)
        }
        context.restoreGState()
    }
    #endif
}

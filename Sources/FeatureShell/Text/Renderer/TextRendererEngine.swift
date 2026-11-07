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
    public init() {}

    /// Kết xuất văn bản tại thời điểm `localTime`, tự động dùng Static Bitmap Cache nếu khung hình đứng yên.
    public func renderAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
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
            if let rendered = renderDynamicComposite(for: config, localTime: localTime, duration: duration, canvasSize: canvasSize) {
                TextSVGAndAssetCache.shared.storeTextImage(rendered, forKey: cacheKey)
                return rendered
            }
            return nil
        }

        return renderDynamicComposite(for: config, localTime: localTime, duration: duration, canvasSize: canvasSize)
    }

    private func isFrameStatic(config: TextConfiguration, localTime: Double, duration: Double) -> Bool {
        if config.background.isEnabled && config.background.sourceKind == .animatedAsset {
            return false
        }
        let anim = config.animation
        if anim.isDefault { return true }
        if anim.hasLoopAnimation || anim.comboType != .none || anim.lightSweepIntensity > 0.01 || anim.rgbSplitIntensity > 0.01 {
            return false
        }
        let inEnd = anim.hasInAnimation ? anim.inDuration : 0.0
        let outStart = anim.hasOutAnimation ? max(inEnd, max(0.1, duration) - anim.outDuration) : .greatestFiniteMagnitude
        return localTime >= inEnd && localTime <= outStart
    }

    private func renderDynamicComposite(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        let evaluated = TextAnimationEvaluator.evaluate(
            config: config,
            localTime: localTime,
            duration: duration,
            canvasSize: canvasSize
        )

        let textImage: CIImage?
        if shouldRenderSegmented(for: config) && !config.curve.isActive {
            textImage = renderSegmentedAnimatedImage(
                for: config,
                localTime: localTime,
                duration: duration,
                canvasSize: canvasSize
            )
        } else if let rawText = renderImage(
            for: evaluated.config,
            canvasSize: canvasSize,
            overlay: evaluated.overlay,
            localTime: localTime,
            duration: duration
        ) {
            textImage = TextShaderFilterEngine.applyFilters(
                to: rawText,
                blurRadius: evaluated.blurRadius,
                hueAngle: evaluated.hueAngle,
                pixelateScale: evaluated.pixelateScale,
                rgbSplitIntensity: evaluated.rgbSplitIntensity,
                overlay: evaluated.overlay,
                lightSweepIntensity: config.animation.lightSweepIntensity,
                shadow: evaluated.config.shadow,
                glow: evaluated.config.glow
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
        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        let safeguard: CGFloat = (rawGlyphBounds.width > maxSafeW && rawGlyphBounds.width > 0)
            ? (maxSafeW / rawGlyphBounds.width)
            : 1.0

        let bgAnchor = baseConfig.background.animateWithText ? evaluated.config : baseConfig
        let bgOverlay = baseConfig.background.animateWithText ? evaluated.overlay : TextTransformOverlay()

        guard var bgImg = TextCompositeLayerRenderer.renderBackground(
            background: baseConfig.background,
            anchorConfig: bgAnchor,
            overlay: bgOverlay,
            textRawSize: rawGlyphBounds,
            safeguardScale: safeguard,
            canvasSize: canvasSize,
            localTime: localTime
        ) else {
            return textImage
        }

        if baseConfig.background.animateWithText {
            bgImg = TextShaderFilterEngine.applyFilters(
                to: bgImg,
                blurRadius: evaluated.blurRadius,
                hueAngle: evaluated.hueAngle,
                pixelateScale: evaluated.pixelateScale,
                rgbSplitIntensity: evaluated.rgbSplitIntensity,
                overlay: evaluated.overlay,
                lightSweepIntensity: 0.0
            )
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
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let layout = TextRenderPerformanceCache.shared.cachedShapedLayout(
            text: config.content,
            font: font,
            config: config
        )

        let textWidth = max(1.0, layout.bounds.width)
        let textHeight = max(1.0, layout.bounds.height)
        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)

        let pivotY: CGFloat
        switch config.animation.anchorPoint {
        case .center: pivotY = 0.0
        case .bottom: pivotY = -textHeight / 2.0
        case .top: pivotY = textHeight / 2.0
        }

        context.saveGState()
        context.translateBy(x: cx, y: cy + pivotY)

        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if textWidth > maxSafeW && textWidth > 0 {
            let safeguardScale = maxSafeW / textWidth
            context.scaleBy(x: safeguardScale, y: safeguardScale)
        }

        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        if abs(overlay.skewX) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: 0, c: CGFloat(overlay.skewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 {
            context.scaleBy(x: sx, y: sy)
        }
        context.translateBy(x: 0, y: -pivotY)

        if config.animation.isMaskEnabled {
            let maskRect = layout.bounds.insetBy(dx: -20.0, dy: -12.0)
            context.clip(to: maskRect)
        }
        if overlay.revealProgress >= 0.0 {
            let p = CGFloat(max(0.0, min(1.0, overlay.revealProgress)))
            let wipeRect = CGRect(
                x: layout.bounds.minX - 20.0,
                y: layout.bounds.minY - 20.0,
                width: (layout.bounds.width + 40.0) * p,
                height: layout.bounds.height + 40.0
            )
            context.clip(to: wipeRect)
        }

        TextAdvancedStyleRenderer.drawStyledVectorGlyphPath(
            layout.combinedPath,
            pathBounds: layout.bounds,
            config: config,
            in: context
        )
        TextCurvedPathBuilder.drawEmojiFallbacks(layout.emojiGlyphs, in: context)
        context.restoreGState()
    }
    #endif
}

import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

#if os(macOS)
/// Per-unit cipher scramble & offscreen GPU 3D perspective, Metal shaders, HDR bloom, and plugin FX renderer.
public enum TextTokenFXRenderer: Sendable {
    nonisolated(unsafe) private static let fxCIContext = CIContext(options: [.useSoftwareRenderer: false, .highQualityDownsample: true])
    private static let scrambleGlyphs = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&*+<>=")

    public static func resolveDisplayText(_ text: String, scrambleStrength: Double, unitIndex: Int) -> String {
        let strength = max(0.0, min(1.0, scrambleStrength))
        guard strength > 0.01 else { return text }

        let step = Int((strength * 22.0).rounded())
        let lockThreshold = 1.0 - strength
        let chars = Array(text)
        let count = max(1, chars.count)
        var out = String()
        out.reserveCapacity(chars.count)

        for (i, ch) in chars.enumerated() {
            if ch.isWhitespace || ch.isNewline {
                out.append(ch)
                continue
            }
            let charNorm = Double(i) / Double(count)
            if charNorm < lockThreshold && strength < 0.85 {
                out.append(ch)
                continue
            }
            let hash = abs((i + 1) * 73 &+ (unitIndex + 1) * 31 &+ step * 17)
            out.append(scrambleGlyphs[hash % scrambleGlyphs.count])
        }
        return out
    }

    public static func perTokenStages(
        evaluated: TextAnimationEvaluator.EvaluationResult,
        baseConfig: TextConfiguration,
        plugins: TextAnimationRenderPluginPipeline
    ) -> TextShaderFilterEngine.AppliedStagesMask {
        let overlay = evaluated.overlay
        var mask: TextShaderFilterEngine.AppliedStagesMask = []

        if evaluated.config.blurRadius > 0.4 || abs(overlay.rotationX) > 0.5 || abs(overlay.rotationY) > 0.5 ||
            abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01 {
            mask.insert(.perspectiveBlur)
        }
        if overlay.liquidMorphIntensity > 0.01 || overlay.liquidWavePhase >= 0.0 {
            mask.insert(.liquid)
        }
        if overlay.motionBlurRadius > 0.5 {
            mask.insert(.motionBlur)
        }
        if overlay.glitchBlockIntensity > 0.01 || overlay.glitchSliceIntensity > 0.02 {
            mask.insert(.glitch)
        }
        if overlay.dissolveProgress > 0.004 || overlay.particleFieldProgress > 0.004 {
            mask.insert(.dissolve)
        }
        if overlay.bloomIntensity > 0.01 || overlay.volumetricRaysIntensity > 0.01 {
            mask.insert(.bloom)
        }
        if overlay.bevelDepth > 0.1 {
            mask.insert(.sdfMaterial)
        }
        if evaluated.pixelateScale > 1.0 {
            mask.insert(.huePixelate)
        }
        if plugins.hasMatchingPlugin(for: evaluated.animationParameters) {
            mask.insert(.plugins)
        }
        return mask
    }

    public static func drawTokenWith3DAndBlur(
        config: TextConfiguration,
        font: NSFont,
        overlay: TextTransformOverlay,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        renderGlyphBlock: (TextConfiguration, NSFont, TextTransformOverlay, CGFloat, CGFloat, CGContext) -> Void,
        in context: CGContext
    ) {
        let emptyEval = TextAnimationEvaluator.EvaluationResult(config: config, blurRadius: config.blurRadius, overlay: overlay)
        drawTokenWithFX(
            evaluated: emptyEval, font: font, tokenWidth: tokenWidth, totalHeight: totalHeight,
            localTime: 0.0, pluginContext: nil, plugins: TextAnimationRenderPluginPipeline(),
            renderGlyphBlock: renderGlyphBlock, in: context
        )
    }

    public static func drawTokenWithFX(
        evaluated: TextAnimationEvaluator.EvaluationResult,
        font: NSFont,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        localTime: Double,
        pluginContext: TextAnimationRenderPluginContext?,
        plugins: TextAnimationRenderPluginPipeline,
        totalRotationDegrees: Double = 0.0,
        renderGlyphBlock: (TextConfiguration, NSFont, TextTransformOverlay, CGFloat, CGFloat, CGContext) -> Void,
        in context: CGContext
    ) {
        let config = evaluated.config
        var tokenOverlay = evaluated.overlay
        tokenOverlay.lightSweepPhase = -1.0
        if tokenOverlay.motionBlurRadius > 0.5 {
            tokenOverlay.motionBlurAngle += totalRotationDegrees * .pi / 180.0
        }
        let blurR = min(28.0, max(0.0, config.blurRadius))
        let pad = computeTokenScratchPad(blurR: blurR, overlay: tokenOverlay, totalHeight: totalHeight)
        let boxW = max(12, Int(ceil(tokenWidth + pad * 2.0)))
        let boxH = max(12, Int(ceil(totalHeight + pad * 2.0)))
        guard let cg = rasterizeTokenScratch(
            config: config, font: font, overlay: tokenOverlay,
            tokenWidth: tokenWidth, totalHeight: totalHeight, boxW: boxW, boxH: boxH,
            renderGlyphBlock: renderGlyphBlock
        ) else {
            renderGlyphBlock(config, font, tokenOverlay, tokenWidth, totalHeight, context)
            return
        }
        let filtered = TextShaderFilterEngine.applyFilters(
            to: CIImage(cgImage: cg), blurRadius: blurR, pixelateScale: evaluated.pixelateScale,
            rgbSplitIntensity: 0.0, overlay: tokenOverlay, lightSweepIntensity: 0.0,
            shadow: TextShadowStyle(), glow: TextGlowStyle(), noiseIntensity: 0.0,
            localTime: localTime, animationParameters: evaluated.animationParameters,
            renderPlugins: plugins, pluginContext: pluginContext
        )
        let cropRect = CGRect(x: 0, y: 0, width: boxW, height: boxH)
        let fullRect = CGRect(x: -CGFloat(boxW) / 2.0, y: -CGFloat(boxH) / 2.0, width: CGFloat(boxW), height: CGFloat(boxH))
        if let outCG = fxCIContext.createCGImage(filtered.cropped(to: cropRect), from: cropRect) {
            context.draw(outCG, in: fullRect)
        }
    }

    private static func computeTokenScratchPad(blurR: Double, overlay: TextTransformOverlay, totalHeight: CGFloat) -> CGFloat {
        let motionPad = overlay.motionBlurRadius > 0.5 ? CGFloat(min(45.0, overlay.motionBlurRadius)) * 1.25 : 0.0
        let has3D = abs(overlay.rotationX) > 0.5 || abs(overlay.rotationY) > 0.5 ||
            abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01
        let hasWideFX = overlay.bloomIntensity > 0.01 || overlay.dissolveProgress > 0.004 || overlay.glitchBlockIntensity > 0.01
        return ceil(CGFloat(blurR) * 2.5 + motionPad + (has3D ? max(24.0, totalHeight * 0.45) : 16.0) + (hasWideFX ? max(24.0, totalHeight * 0.40) : 0.0))
    }

    private static func rasterizeTokenScratch(
        config: TextConfiguration, font: NSFont, overlay: TextTransformOverlay,
        tokenWidth: CGFloat, totalHeight: CGFloat, boxW: Int, boxH: Int,
        renderGlyphBlock: (TextConfiguration, NSFont, TextTransformOverlay, CGFloat, CGFloat, CGContext) -> Void
    ) -> CGImage? {
        guard let scratch = CGContext(
            data: nil, width: boxW, height: boxH, bitsPerComponent: 8, bytesPerRow: boxW * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let nsScratch = NSGraphicsContext(cgContext: scratch, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsScratch
        scratch.translateBy(x: CGFloat(boxW) / 2.0, y: CGFloat(boxH) / 2.0)
        renderGlyphBlock(config, font, overlay, tokenWidth, totalHeight, scratch)
        NSGraphicsContext.restoreGraphicsState()
        return scratch.makeImage()
    }

    public static func applyGPUFXInPixelSpace(
        to pixelImage: CIImage,
        entry: TextGlyphAtlasEntry,
        evaluated: TextAnimationEvaluator.EvaluationResult,
        totalHeight: CGFloat,
        localTime: Double,
        pluginContext: TextAnimationRenderPluginContext,
        plugins: TextAnimationRenderPluginPipeline,
        blockScale: CGFloat = 1.0,
        totalRotationDegrees: Double = 0.0
    ) -> CIImage {
        let config = evaluated.config
        var tokenOverlay = evaluated.overlay
        tokenOverlay.lightSweepPhase = -1.0

        let s = Double(entry.rasterScale)
        let blurR = min(28.0, max(0.0, config.blurRadius)) * s
        tokenOverlay.bevelDepth *= s
        tokenOverlay.bevelExtrudeDepth *= s
        tokenOverlay.liquidMorphIntensity *= min(1.8, s * 0.6)
        let motionPxScale = s / Double(max(0.01, blockScale))
        if tokenOverlay.motionBlurRadius > 0.5 {
            tokenOverlay.motionBlurRadius = min(45.0, tokenOverlay.motionBlurRadius * motionPxScale)
            tokenOverlay.motionBlurAngle += totalRotationDegrees * .pi / 180.0
        }

        let hasMotionBlur = evaluated.overlay.motionBlurRadius > 0.5
        let hasWideFX = tokenOverlay.bloomIntensity > 0.01 || tokenOverlay.dissolveProgress > 0.004 ||
            tokenOverlay.particleFieldProgress > 0.004 || tokenOverlay.volumetricRaysIntensity > 0.01 ||
            tokenOverlay.glitchBlockIntensity > 0.01 || hasMotionBlur ||
            abs(tokenOverlay.rotationX) > 0.5 || abs(tokenOverlay.rotationY) > 0.5 || config.blurRadius > 0.4
        let motionPadLogical = hasMotionBlur ? CGFloat(evaluated.overlay.motionBlurRadius) * 1.25 / max(0.01, blockScale) : 0.0
        let extraPad = hasWideFX ? ceil(max(18.0, CGFloat(config.blurRadius) * 2.0 + motionPadLogical + totalHeight * 0.35)) : 0.0
        let extraPadPx = extraPad * entry.rasterScale
        let pixelRect = CGRect(origin: .zero, size: entry.pixelSize)
        let fxPixelExtent = pixelRect.insetBy(dx: -extraPadPx, dy: -extraPadPx)

        // Built-in Metal shaders use `readAlignedSDF` so cached `entry.sdfTexture` stays registered even inside padded boxes.
        return TextShaderFilterEngine.applyFilters(
            to: pixelImage,
            blurRadius: blurR,
            pixelateScale: evaluated.pixelateScale * s,
            rgbSplitIntensity: 0.0,
            overlay: tokenOverlay,
            lightSweepIntensity: 0.0,
            shadow: TextShadowStyle(),
            glow: TextGlowStyle(),
            noiseIntensity: 0.0,
            localTime: localTime,
            animationParameters: evaluated.animationParameters,
            renderPlugins: plugins,
            pluginContext: pluginContext,
            sdfTexture: entry.sdfTexture
        ).cropped(to: fxPixelExtent)
    }
}
#endif

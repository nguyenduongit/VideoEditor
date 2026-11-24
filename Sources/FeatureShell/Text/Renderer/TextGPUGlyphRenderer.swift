import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

#if os(macOS)
/// Pure-GPU whole-block compositor and transform/mask utilities driven by `TextGlyphAtlasCache`.
enum TextGPUGlyphRenderer {
    static func renderWholeBlock(
        config: TextConfiguration,
        overlay: TextTransformOverlay,
        canvasSize: CGSize,
        font: NSFont,
        atlasCache: TextGlyphAtlasCache,
        localTime: Double = 0.0
    ) -> CIImage? {
        guard overlay.strokeTrimProgress >= 0.999 else { return nil }
        let displayText = TextTokenFXRenderer.resolveDisplayText(
            config.content, scrambleStrength: overlay.scrambleStrength, unitIndex: 0
        )
        let desiredScale = max(2.0, CGFloat(config.scale) * max(1.0, CGFloat(max(abs(overlay.scaleX), abs(overlay.scaleY)))))
        guard let entry = atlasCache.entry(
            forText: displayText, font: font, config: config, requestedScale: desiredScale
        ) else {
            return nil
        }

        var localPixels = applyGlyphLocalSDFFX(to: entry, overlay: overlay, localTime: localTime)
        let toPixel = entry.toLogicalTransform.inverted()
        if config.animation.isMaskEnabled {
            localPixels = localPixels.cropped(to: entry.shapedBounds.insetBy(dx: -20.0, dy: -12.0).applying(toPixel))
        }
        if overlay.clipRevealX < 0.999 || overlay.clipRevealY < 0.999 {
            localPixels = applyGPUMaskInPixelSpace(
                to: localPixels,
                pixelBounds: entry.shapedBounds.insetBy(dx: -16.0, dy: -16.0).applying(toPixel),
                clipRevealX: overlay.clipRevealX,
                clipRevealY: overlay.clipRevealY,
                mode: overlay.maskShapeMode
            )
        }
        if overlay.revealProgress >= 0.0 {
            let p = CGFloat(max(0.0, min(1.0, overlay.revealProgress)))
            let b = entry.shapedBounds
            let revealPx = CGRect(x: b.minX - 20.0, y: b.minY - 20.0, width: (b.width + 40.0) * p, height: b.height + 40.0)
                .applying(toPixel)
            localPixels = localPixels.cropped(to: revealPx)
        }

        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        let safeguard: CGFloat = (entry.shapedBounds.width > maxSafeW && entry.shapedBounds.width > 0)
            ? (maxSafeW / entry.shapedBounds.width)
            : 1.0
        let worldTransform = wholeBlockTransform(
            config: config, overlay: overlay, textHeight: max(1.0, entry.shapedBounds.height),
            canvasSize: canvasSize, safeguardScale: safeguard
        )
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        // Compose toLogical and worldTransform once so CoreImage does not downsample to 1/s before scaling up.
        let combinedTransform = entry.toLogicalTransform.concatenating(worldTransform)
        let transformed = localPixels
            .transformed(by: combinedTransform)
            .composited(over: CIImage.clear.cropped(to: canvasRect))
            .cropped(to: canvasRect)
        return TextSVGAndAssetCache.applyPremultipliedOpacity(config.opacity, to: transformed)
    }

    static func wholeBlockTransform(
        config: TextConfiguration,
        overlay: TextTransformOverlay,
        textHeight: CGFloat,
        canvasSize: CGSize,
        safeguardScale: CGFloat
    ) -> CGAffineTransform {
        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        let pivotY: CGFloat = switch config.animation.anchorPoint {
        case .center: 0.0
        case .bottom: -textHeight / 2.0
        case .top: textHeight / 2.0
        }
        return makeUnitTransform(
            center: CGPoint(x: cx, y: cy),
            pivotOffsetY: pivotY,
            rotationDegrees: config.rotation,
            skewX: overlay.skewX + tan(config.skewX * .pi / 180.0),
            skewY: tan(config.skewY * .pi / 180.0),
            scaleX: CGFloat(max(0.01, config.scale * overlay.scaleX)),
            scaleY: CGFloat(max(0.01, config.scale * overlay.scaleY)),
            safeguardScale: safeguardScale
        )
    }

    static func applyGPUMaskInPixelSpace(
        to pixelImage: CIImage,
        pixelBounds: CGRect,
        clipRevealX: Double,
        clipRevealY: Double,
        mode: TextMaskShapeMode
    ) -> CIImage {
        let rx = CGFloat(max(0.0, min(1.0, clipRevealX)))
        let ry = CGFloat(max(0.0, min(1.0, clipRevealY)))
        switch mode {
        case .rect:
            return pixelImage.cropped(to: CGRect(x: pixelBounds.minX, y: pixelBounds.minY, width: pixelBounds.width * rx, height: pixelBounds.height * ry))
        case .centerSplitX, .centerSplitY:
            let w = pixelBounds.width * rx, h = pixelBounds.height * ry
            return pixelImage.cropped(to: CGRect(x: pixelBounds.midX - w * 0.5, y: pixelBounds.midY - h * 0.5, width: w, height: h))
        case .diagonalSlash, .irisCircle:
            let alignedBounds = pixelBounds.standardized.integral
            let u = MetalEffectUniforms(
                width: Float(alignedBounds.width), height: Float(alignedBounds.height),
                p0: Float(rx), p1: Float(ry), p2: Float(TextMaskShapeMode.allCases.firstIndex(of: mode) ?? 0)
            )
            return MetalComputeRuntimeEngine.shared.dispatchTransparentEffect(
                kernelName: "metal_text_mask_shape",
                on: pixelImage,
                uniforms: u,
                canvasRect: alignedBounds
            )
        }
    }

    static func makeBlockTransform(
        config: TextConfiguration,
        canvasSize: CGSize,
        safeguardScale: CGFloat
    ) -> CGAffineTransform {
        makeUnitTransform(
            center: CGPoint(x: canvasSize.width / 2.0 + CGFloat(config.positionX), y: canvasSize.height / 2.0 - CGFloat(config.positionY)),
            pivotOffsetY: 0.0,
            rotationDegrees: config.rotation,
            skewX: 0.0,
            skewY: 0.0,
            scaleX: CGFloat(max(0.01, config.scale)),
            scaleY: CGFloat(max(0.01, config.scale)),
            safeguardScale: safeguardScale
        )
    }

    static func makeUnitTransform(
        center: CGPoint,
        pivotOffsetY: CGFloat,
        rotationDegrees: Double,
        skewX: Double,
        skewY: Double,
        scaleX: CGFloat,
        scaleY: CGFloat,
        safeguardScale: CGFloat
    ) -> CGAffineTransform {
        var t = CGAffineTransform(translationX: 0.0, y: -pivotOffsetY)
        if abs(scaleX - 1.0) > 0.001 || abs(scaleY - 1.0) > 0.001 {
            t = t.concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
        }
        if abs(skewX) > 0.001 || abs(skewY) > 0.001 {
            t = t.concatenating(CGAffineTransform(a: 1.0, b: CGFloat(skewY), c: CGFloat(skewX), d: 1.0, tx: 0.0, ty: 0.0))
        }
        if abs(rotationDegrees) > 0.001 {
            t = t.concatenating(CGAffineTransform(rotationAngle: CGFloat(-rotationDegrees * .pi / 180.0)))
        }
        if safeguardScale < 0.999 {
            t = t.concatenating(CGAffineTransform(scaleX: safeguardScale, y: safeguardScale))
        }
        return t.concatenating(CGAffineTransform(translationX: center.x, y: center.y + pivotOffsetY))
    }

    static func makeTrailingCursorBar(
        config: TextConfiguration, font: NSFont, tokenWidth: CGFloat, totalHeight: CGFloat, opacity: Double
    ) -> CIImage {
        let barW = max(2.2, font.pointSize * 0.062)
        let barH = max(12.0, totalHeight * 0.86)
        let gap = max(3.0, font.pointSize * 0.08)
        let cursorX = config.opacity > 0.005 ? (tokenWidth / 2.0 + gap) : (-tokenWidth / 2.0)
        let barRect = CGRect(x: cursorX, y: -barH / 2.0, width: barW, height: barH)
        let nsCol = TextAdvancedStyleRenderer.parseHexColor(config.textColorHex)
            .withAlphaComponent(CGFloat(max(0.0, min(1.0, opacity))))
        let ciCol = CIColor(red: nsCol.redComponent, green: nsCol.greenComponent, blue: nsCol.blueComponent, alpha: nsCol.alphaComponent)
        return CIImage(color: ciCol).cropped(to: barRect)
    }

    private static func applyGlyphLocalSDFFX(
        to entry: TextGlyphAtlasEntry,
        overlay: TextTransformOverlay,
        localTime: Double
    ) -> CIImage {
        let s = Float(entry.rasterScale)
        let w = Float(entry.pixelSize.width)
        let h = Float(entry.pixelSize.height)
        var passes: [MetalTransparentPass] = []

        if overlay.bevelDepth > 0.1 {
            let u = MetalEffectUniforms(
                intensity: 1.0, width: w, height: h,
                p0: Float(overlay.bevelLightAngle), p1: Float(max(2.0, overlay.bevelDepth)) * s,
                p2: 0.0, p3: Float(overlay.bevelExtrudeDepth) * s
            )
            passes.append(MetalTransparentPass(kernelName: "metal_text_sdf_bevel_pbr", uniforms: u, secondaryTexture: entry.sdfTexture))
        }
        guard !passes.isEmpty else { return entry.rawPixelCIImage }
        let pixelRect = CGRect(origin: .zero, size: entry.pixelSize)
        return MetalComputeRuntimeEngine.shared.dispatchTransparentEffectChain(
            passes: passes, on: entry.rawPixelCIImage, canvasRect: pixelRect
        )
    }
}
#endif

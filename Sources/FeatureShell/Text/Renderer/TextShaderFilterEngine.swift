import Foundation
import CoreGraphics
import CoreImage
import Metal
import Domain

/// Bộ xử lý hiệu ứng Shader, Metal Compute VFX & Render Plugins cho Text Image.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum TextShaderFilterEngine: Sendable {
    /// Tracks which shader stages were already evaluated per segmented unit so block-level compositing avoids double-applying them.
    public struct AppliedStagesMask: OptionSet, Sendable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) { self.rawValue = rawValue }

        public static let perspectiveBlur = Self(rawValue: 1 << 0)
        public static let liquid = Self(rawValue: 1 << 1)
        public static let motionBlur = Self(rawValue: 1 << 2)
        public static let glitch = Self(rawValue: 1 << 3)
        public static let dissolve = Self(rawValue: 1 << 4)
        public static let bloom = Self(rawValue: 1 << 5)
        public static let huePixelate = Self(rawValue: 1 << 6)
        public static let plugins = Self(rawValue: 1 << 7)
        public static let sdfMaterial = Self(rawValue: 1 << 8)
    }

    public static func hasActiveFilters(
        blurRadius: Double,
        pixelateScale: Double,
        rgbSplitIntensity: Double = 0.0,
        overlay: TextTransformOverlay,
        shadow: TextShadowStyle = TextShadowStyle(),
        glow: TextGlowStyle = TextGlowStyle(),
        noiseIntensity: Double = 0.0
    ) -> Bool {
        abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01 ||
        abs(overlay.rotationX) > 0.2 || abs(overlay.rotationY) > 0.2 ||
        overlay.liquidWavePhase >= 0.0 || overlay.liquidMorphIntensity > 0.01 ||
        overlay.glitchSliceIntensity > 0.02 || overlay.glitchBlockIntensity > 0.01 ||
        overlay.lightSweepPhase >= 0.0 || overlay.motionBlurRadius > 0.5 ||
        overlay.dissolveProgress > 0.004 || overlay.bloomIntensity > 0.01 ||
        overlay.bevelDepth > 0.1 ||
        overlay.particleFieldProgress > 0.004 || overlay.volumetricRaysIntensity > 0.01 ||
        blurRadius > 0.001 || pixelateScale > 1.0 || noiseIntensity > 0.1 ||
        (shadow.isEnabled && shadow.opacity > 0.5 && shadow.colorHex.uppercased() != "NONE") ||
        (glow.isEnabled && glow.intensity > 0.5 && glow.range > 0.2 && glow.colorHex.uppercased() != "NONE")
    }

    public static func applyFilters(
        to image: CIImage,
        blurRadius: Double,
        pixelateScale: Double,
        rgbSplitIntensity: Double = 0.0,
        overlay: TextTransformOverlay = TextTransformOverlay(),
        lightSweepIntensity: Double = 0.65,
        shadow: TextShadowStyle = TextShadowStyle(),
        glow: TextGlowStyle = TextGlowStyle(),
        noiseIntensity: Double = 0.0,
        localTime: Double = 0.0,
        animationParameters: TextAnimationParameterBag = TextAnimationParameterBag(),
        renderPlugins: TextAnimationRenderPluginPipeline = TextAnimationRenderPluginPipeline(),
        pluginContext: TextAnimationRenderPluginContext? = nil,
        skipStages: AppliedStagesMask = [],
        sdfTexture: MTLTexture? = nil
    ) -> CIImage {
        let canvasExtent = image.extent
        let needsBuiltIn = hasActiveFilters(
            blurRadius: blurRadius, pixelateScale: pixelateScale,
            rgbSplitIntensity: rgbSplitIntensity, overlay: overlay,
            shadow: shadow, glow: glow, noiseIntensity: noiseIntensity
        )
        let shouldRunPlugins = !skipStages.contains(.plugins) && renderPlugins.hasMatchingPlugin(for: animationParameters)
        guard needsBuiltIn || shouldRunPlugins else { return image }

        var result = needsBuiltIn
            ? applyStyleEffects(to: image, shadow: shadow, glow: glow, extent: canvasExtent)
            : image

        if needsBuiltIn {
            result = applyBuiltInStages(
                to: result,
                blurRadius: blurRadius,
                pixelateScale: pixelateScale,
                rgbSplitIntensity: 0.0,
                overlay: overlay,
                lightSweepIntensity: lightSweepIntensity,
                noiseIntensity: noiseIntensity,
                localTime: localTime,
                extent: canvasExtent,
                skipStages: skipStages,
                sdfTexture: sdfTexture
            )
        }

        if shouldRunPlugins {
            let ctx = pluginContext ?? TextAnimationRenderPluginContext(
                localTime: localTime,
                duration: max(0.1, localTime),
                canvasSize: canvasExtent.size
            )
            result = renderPlugins.apply(to: result, parameters: animationParameters, context: ctx)
                .cropped(to: canvasExtent)
        }
        return result.cropped(to: canvasExtent)
    }

    private static func applyBuiltInStages(
        to image: CIImage,
        blurRadius: Double,
        pixelateScale: Double,
        rgbSplitIntensity: Double,
        overlay: TextTransformOverlay,
        lightSweepIntensity: Double,
        noiseIntensity: Double,
        localTime: Double,
        extent: CGRect,
        skipStages: AppliedStagesMask,
        sdfTexture: MTLTexture?
    ) -> CIImage {
        var result = image
        if !skipStages.contains(.perspectiveBlur),
           abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01 ||
           abs(overlay.rotationX) > 0.2 || abs(overlay.rotationY) > 0.2 {
            result = applyTrue3DPerspective(
                to: result, pitchX: overlay.perspectiveX, yawY: overlay.perspectiveY,
                rotXDegrees: overlay.rotationX, rotYDegrees: overlay.rotationY
            )
        }

        var filteredOverlay = overlay
        if skipStages.contains(.liquid) { filteredOverlay.liquidWavePhase = -1.0; filteredOverlay.liquidMorphIntensity = 0.0 }
        if skipStages.contains(.motionBlur) { filteredOverlay.motionBlurRadius = 0.0 }
        if skipStages.contains(.glitch) { filteredOverlay.glitchBlockIntensity = 0.0; filteredOverlay.glitchSliceIntensity = 0.0 }
        if skipStages.contains(.dissolve) { filteredOverlay.dissolveProgress = 0.0; filteredOverlay.particleFieldProgress = 0.0 }
        if skipStages.contains(.bloom) { filteredOverlay.bloomIntensity = 0.0; filteredOverlay.volumetricRaysIntensity = 0.0 }
        if skipStages.contains(.sdfMaterial) {
            filteredOverlay.bevelDepth = 0.0
        }

        result = applyMetalTextPipeline(
            to: result,
            overlay: filteredOverlay,
            rgbSplitIntensity: 0.0,
            lightSweepIntensity: lightSweepIntensity,
            localTime: localTime,
            extent: extent,
            sdfTexture: sdfTexture
        )

        if !skipStages.contains(.perspectiveBlur), blurRadius > 0.001 {
            result = applyGaussianBlur(to: result, radius: blurRadius)
        }
        if !skipStages.contains(.huePixelate), pixelateScale > 1.0 {
            result = applyPixelate(to: result, scale: pixelateScale)
        }
        if noiseIntensity > 0.1 {
            result = applyNoiseGrain(to: result, intensity: noiseIntensity, extent: extent)
        }
        return result
    }

    public static func applyGaussianBlur(to image: CIImage, radius: Double) -> CIImage {
        let clampedRadius = max(0.0, min(60.0, radius))
        guard clampedRadius > 0.001,
              let filter = CIFilter(name: "CIGaussianBlur", parameters: [
                  kCIInputImageKey: image, kCIInputRadiusKey: clampedRadius
              ]) else { return image }
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    public static func applyMotionBlur(to image: CIImage, radius: Double, angle: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIMotionBlur", parameters: [
            kCIInputImageKey: image, kCIInputRadiusKey: min(45.0, max(0.0, radius)), kCIInputAngleKey: angle
        ]) else { return image }
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    private static func applyPixelate(to image: CIImage, scale: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIPixellate", parameters: [
            kCIInputImageKey: image, "inputScale": scale
        ]) else { return image }
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    public static func applyLightSweep(to image: CIImage, phase: Double, intensity: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return image }
        let normalized = min(1.0, max(0.0, phase))
        let sweepX = extent.minX - extent.width * 0.25 + (extent.width * 1.5) * CGFloat(normalized)
        let bandHalfWidth = max(24.0, extent.width * 0.08)
        let alpha = CGFloat(min(0.95, max(0.1, intensity)))
        let hi = CIColor(red: 1.0, green: 0.99, blue: 0.92, alpha: alpha)
        let clear = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)

        guard let gradL = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: sweepX - bandHalfWidth, y: extent.minY),
            "inputPoint1": CIVector(x: sweepX, y: extent.midY),
            "inputColor0": clear, "inputColor1": hi
        ])?.outputImage?.cropped(to: extent),
        let gradR = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: sweepX, y: extent.midY),
            "inputPoint1": CIVector(x: sweepX + bandHalfWidth, y: extent.maxY),
            "inputColor0": hi, "inputColor1": clear
        ])?.outputImage?.cropped(to: extent) else { return image }

        let lRect = CGRect(x: extent.minX, y: extent.minY, width: max(0, sweepX - extent.minX), height: extent.height)
        let rRect = CGRect(x: sweepX, y: extent.minY, width: max(0, extent.maxX - sweepX), height: extent.height)
        let beam = gradL.cropped(to: lRect).composited(over: gradR.cropped(to: rRect))
        guard let atop = CIFilter(name: "CISourceAtopCompositing", parameters: [
            kCIInputImageKey: beam, kCIInputBackgroundImageKey: image
        ])?.outputImage else { return image }
        return atop.cropped(to: extent)
    }

    public static func applyGlitchSlices(to image: CIImage, intensity: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 12 else { return image }
        let sliceCount = 5
        let sliceH = extent.height / CGFloat(sliceCount)
        var acc = CIImage.empty()
        for i in 0..<sliceCount {
            let sliceRect = CGRect(x: extent.minX, y: extent.minY + CGFloat(i) * sliceH, width: extent.width, height: sliceH)
            let dir: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let weight: CGFloat = (i == 1 || i == 3) ? 1.0 : 0.35
            let sliced = image.cropped(to: sliceRect)
                .transformed(by: CGAffineTransform(translationX: dir * weight * CGFloat(intensity) * 24.0, y: 0))
                .cropped(to: extent)
            acc = sliced.composited(over: acc)
        }
        return acc.cropped(to: extent)
    }

    public static func applyPerspective3D(to image: CIImage, pitchX: Double, yawY: Double) -> CIImage {
        applyTrue3DPerspective(to: image, pitchX: pitchX, yawY: yawY)
    }

    public static func applyLiquidWave(to image: CIImage, phase: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 4 else { return image }
        let cx = extent.midX + CGFloat(sin(phase)) * extent.width * 0.12
        let cy = extent.midY + CGFloat(cos(phase * 1.3)) * extent.height * 0.08
        let radius = max(80.0, min(extent.width, extent.height) * 0.45)
        guard let filter = CIFilter(name: "CIBumpDistortion", parameters: [
            kCIInputImageKey: image, kCIInputCenterKey: CIVector(x: cx, y: cy),
            kCIInputRadiusKey: radius, kCIInputScaleKey: CGFloat(sin(phase * 2.0)) * 0.28
        ])?.outputImage else { return image }
        return filter.cropped(to: extent)
    }

    public static func applyRGBSplit(to image: CIImage, offset: Double) -> CIImage {
        let dx = CGFloat(offset)
        let redShift = image.transformed(by: CGAffineTransform(translationX: -dx, y: 0))
        let blueShift = image.transformed(by: CGAffineTransform(translationX: dx, y: 0))
        let rMat = CIVector(x: 1, y: 0, z: 0, w: 0), bMat = CIVector(x: 0, y: 0, z: 1, w: 0), zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let redOnly = CIFilter(name: "CIColorMatrix", parameters: [kCIInputImageKey: redShift, "inputRVector": rMat, "inputGVector": zero, "inputBVector": zero])?.outputImage,
              let blueOnly = CIFilter(name: "CIColorMatrix", parameters: [kCIInputImageKey: blueShift, "inputRVector": zero, "inputGVector": zero, "inputBVector": bMat])?.outputImage,
              let m1 = CIFilter(name: "CIScreenBlendMode", parameters: [kCIInputImageKey: redOnly, kCIInputBackgroundImageKey: image])?.outputImage,
              let finalImg = CIFilter(name: "CIScreenBlendMode", parameters: [kCIInputImageKey: blueOnly, kCIInputBackgroundImageKey: m1])?.outputImage else {
            return image
        }
        return finalImg.cropped(to: image.extent.insetBy(dx: -dx * 2, dy: 0))
    }
}

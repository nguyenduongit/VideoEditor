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
        public static let dissolve = Self(rawValue: 1 << 4)
        public static let pixelate = Self(rawValue: 1 << 6)
        public static let plugins = Self(rawValue: 1 << 7)
        public static let sdfMaterial = Self(rawValue: 1 << 8)
        public static let meshWarp = Self(rawValue: 1 << 9)
        public static let perspective3D = Self(rawValue: 1 << 10)
    }

    public static func hasActiveFilters(
        blurRadius: Double,
        pixelateScale: Double,
        overlay: TextTransformOverlay,
        shadow: TextShadowStyle = TextShadowStyle(),
        glow: TextGlowStyle = TextGlowStyle(),
        noiseIntensity: Double = 0.0
    ) -> Bool {
        abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01 ||
        abs(overlay.rotationX) > 0.2 || abs(overlay.rotationY) > 0.2 ||
        overlay.liquidWavePhase >= 0.0 || overlay.liquidMorphIntensity > 0.01 ||
        overlay.motionBlurRadius > 0.5 ||
        overlay.dissolveProgress > 0.004 ||
        overlay.bevelDepth > 0.1 ||
        overlay.particleFieldProgress > 0.004 ||
        (overlay.meshWarpMode != .none && abs(overlay.meshWarpAmount) > 0.005) ||
        blurRadius > 0.001 || pixelateScale > 1.0 || noiseIntensity > 0.1 ||
        (shadow.isEnabled && shadow.opacity > 0.5 && shadow.colorHex.uppercased() != "NONE") ||
        (glow.isEnabled && glow.intensity > 0.5 && glow.range > 0.2 && glow.colorHex.uppercased() != "NONE")
    }

    public static func applyFilters(
        to image: CIImage,
        blurRadius: Double,
        pixelateScale: Double,
        overlay: TextTransformOverlay = TextTransformOverlay(),
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
            overlay: overlay, shadow: shadow, glow: glow, noiseIntensity: noiseIntensity
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
                overlay: overlay,
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
        overlay: TextTransformOverlay,
        noiseIntensity: Double,
        localTime: Double,
        extent: CGRect,
        skipStages: AppliedStagesMask,
        sdfTexture: MTLTexture?
    ) -> CIImage {
        var result = image
        if !skipStages.contains(.perspectiveBlur), !skipStages.contains(.perspective3D),
           abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01 ||
           abs(overlay.rotationX) > 0.2 || abs(overlay.rotationY) > 0.2 {
            result = applyTrue3DPerspective(
                to: result, pitchX: overlay.perspectiveX, yawY: overlay.perspectiveY,
                rotXDegrees: overlay.rotationX, rotYDegrees: overlay.rotationY,
                anchor: overlay.anchorPoint
            )
        }

        var filteredOverlay = overlay
        if skipStages.contains(.liquid) { filteredOverlay.liquidWavePhase = -1.0; filteredOverlay.liquidMorphIntensity = 0.0 }
        if skipStages.contains(.motionBlur) { filteredOverlay.motionBlurRadius = 0.0 }
        if skipStages.contains(.dissolve) { filteredOverlay.dissolveProgress = 0.0; filteredOverlay.particleFieldProgress = 0.0 }
        if skipStages.contains(.sdfMaterial) {
            filteredOverlay.bevelDepth = 0.0
        }
        if skipStages.contains(.meshWarp) {
            filteredOverlay.meshWarpMode = .none
            filteredOverlay.meshWarpAmount = 0.0
        }

        result = applyMetalTextPipeline(
            to: result,
            overlay: filteredOverlay,
            localTime: localTime,
            extent: extent,
            sdfTexture: sdfTexture
        )

        if !skipStages.contains(.perspectiveBlur), blurRadius > 0.001 {
            result = applyGaussianBlur(to: result, radius: blurRadius)
        }
        if !skipStages.contains(.pixelate), pixelateScale > 1.0 {
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
}

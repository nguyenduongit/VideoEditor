import Foundation
import CoreGraphics
import CoreImage
import Metal
import Domain

/// Metal Compute Kernel dispatchers & true 3D matrix projection for `TextShaderFilterEngine`.
extension TextShaderFilterEngine {

    public static func applyTrue3DPerspective(
        to image: CIImage,
        pitchX: Double,
        yawY: Double,
        rotXDegrees: Double = 0.0,
        rotYDegrees: Double = 0.0,
        anchor: TextAnchorPoint = .center,
        anchorReferenceSize: CGSize? = nil
    ) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 4 else { return image }

        let totalRx = (rotXDegrees * .pi / 180.0) + max(-0.85, min(0.85, pitchX)) * 0.95
        let totalRy = (rotYDegrees * .pi / 180.0) + max(-0.85, min(0.85, yawY)) * 0.95
        guard abs(totalRx) > 0.005 || abs(totalRy) > 0.005 else { return image }

        let hw = Double(extent.width) * 0.5
        let hh = Double(extent.height) * 0.5
        let refW = Double(anchorReferenceSize?.width ?? extent.width)
        let refH = Double(anchorReferenceSize?.height ?? extent.height)
        let px = refW * 0.5 * anchor.x
        let py = refH * 0.5 * anchor.y
        let camDist = max(240.0, max(hw, hh) * 3.4)
        let cosX = cos(totalRx), sinX = sin(totalRx)
        let cosY = cos(totalRy), sinY = sin(totalRy)

        func project(_ x: Double, _ y: Double) -> CIVector {
            // Rotate around normalized 2D anchor pivot, then apply perspective divide
            let rx = x - px
            let ry = y - py
            let y1 = ry * cosX
            let z1 = ry * sinX
            let x2 = rx * cosY + z1 * sinY
            let z2 = -rx * sinY + z1 * cosY
            let factor = camDist / max(45.0, camDist + z2)
            return CIVector(
                x: extent.midX + CGFloat(px + x2 * factor),
                y: extent.midY + CGFloat(py + y1 * factor)
            )
        }

        let facing = cosX * cosY
        guard let filter = CIFilter(name: "CIPerspectiveTransform", parameters: [
            kCIInputImageKey: image,
            "inputTopLeft": project(-hw, hh),
            "inputTopRight": project(hw, hh),
            "inputBottomLeft": project(-hw, -hh),
            "inputBottomRight": project(hw, -hh)
        ])?.outputImage else { return image }

        var output = filter.cropped(to: extent)
        if facing < 0.0 {
            // Subtle backface shading when rotated past 90 degrees
            let dim = CGFloat(max(0.32, 1.0 - abs(facing) * 0.55))
            output = applyDimColorMatrix(to: output, scale: dim)
        }
        return output
    }

    static func applyMetalTextPipeline(
        to image: CIImage,
        overlay: TextTransformOverlay,
        localTime: Double,
        extent: CGRect,
        sdfTexture: MTLTexture? = nil
    ) -> CIImage {
        let engine = MetalComputeRuntimeEngine.shared
        guard engine.isAvailable, !extent.isEmpty, !extent.isInfinite else {
            return applyCoreImageFallbacks(to: image, overlay: overlay, extent: extent)
        }

        let passes = buildMetalPasses(
            overlay: overlay,
            localTime: localTime,
            extent: extent,
            sdfTexture: sdfTexture
        )
        return passes.isEmpty
            ? image
            : engine.dispatchTransparentEffectChain(passes: passes, on: image, canvasRect: extent)
    }

    private static func buildMetalPasses(
        overlay: TextTransformOverlay,
        localTime: Double,
        extent: CGRect,
        sdfTexture: MTLTexture?
    ) -> [MetalTransparentPass] {
        var passes = buildMaterialAndSurfacePasses(
            overlay: overlay, localTime: localTime, extent: extent, sdfTexture: sdfTexture
        )
        passes.append(contentsOf: buildOpticalAndParticlePasses(
            overlay: overlay, localTime: localTime, extent: extent, sdfTexture: sdfTexture
        ))
        return passes
    }

    private static func buildMaterialAndSurfacePasses(
        overlay: TextTransformOverlay,
        localTime: Double,
        extent: CGRect,
        sdfTexture: MTLTexture?
    ) -> [MetalTransparentPass] {
        let w = Float(extent.width), h = Float(extent.height)
        var passes: [MetalTransparentPass] = []

        if let sdfTexture, overlay.bevelDepth > 0.1 {
            let u = MetalEffectUniforms(
                intensity: 1.0, width: w, height: h,
                p0: Float(overlay.bevelLightAngle), p1: Float(max(2.0, overlay.bevelDepth)),
                p2: 0.0, p3: Float(overlay.bevelExtrudeDepth)
            )
            passes.append(MetalTransparentPass(kernelName: "metal_text_sdf_bevel_pbr", uniforms: u, secondaryTexture: sdfTexture))
        }
        if overlay.meshWarpMode != .none, abs(overlay.meshWarpAmount) > 0.005 {
            let u = MetalEffectUniforms(
                time: Float(overlay.meshWarpPhase), intensity: 1.0, width: w, height: h,
                p0: Float(overlay.meshWarpMode.shaderIndex),
                p1: Float(overlay.meshWarpAmount),
                p2: Float(overlay.meshWarpFrequency)
            )
            passes.append(MetalTransparentPass(kernelName: "metal_text_mesh_warp", uniforms: u))
        }
        if overlay.liquidMorphIntensity > 0.01 || overlay.liquidWavePhase >= 0.0 {
            let phase = overlay.liquidWavePhase >= 0.0 ? overlay.liquidWavePhase : localTime * 2.0
            let morphAmt = max(overlay.liquidMorphIntensity, overlay.liquidWavePhase >= 0.0 ? 0.85 : 0.0)
            let u = MetalEffectUniforms(
                time: Float(phase), intensity: Float(morphAmt), width: w, height: h,
                p0: Float(10.0 * morphAmt), p1: 1.0, p2: 0.0
            )
            passes.append(MetalTransparentPass(kernelName: "metal_text_liquid_morph", uniforms: u, secondaryTexture: sdfTexture))
        }
        return passes
    }

    private static func buildOpticalAndParticlePasses(
        overlay: TextTransformOverlay,
        localTime: Double,
        extent: CGRect,
        sdfTexture: MTLTexture?
    ) -> [MetalTransparentPass] {
        let w = Float(extent.width), h = Float(extent.height)
        var passes: [MetalTransparentPass] = []

        if overlay.motionBlurRadius > 0.5 {
            let u = MetalEffectUniforms(width: w, height: h, p0: Float(min(45.0, overlay.motionBlurRadius)), p1: Float(overlay.motionBlurAngle))
            passes.append(MetalTransparentPass(kernelName: "metal_text_directional_blur", uniforms: u))
        }
        if overlay.particleFieldProgress > 0.004 {
            let u = MetalEffectUniforms(
                time: Float(localTime), progress: Float(overlay.particleFieldProgress), intensity: 1.0, width: w, height: h,
                p0: Float(overlay.particleFieldAngle), p1: Float(max(70.0, extent.height * 0.30)), p2: 14.0
            )
            passes.append(MetalTransparentPass(kernelName: "metal_text_gpu_particle_scatter", uniforms: u, secondaryTexture: sdfTexture))
        } else if overlay.dissolveProgress > 0.004 {
            let u = MetalEffectUniforms(
                progress: Float(overlay.dissolveProgress), intensity: 1.0, width: w, height: h,
                p0: Float(overlay.dissolveAngleRadians), p1: Float(max(65.0, extent.height * 0.25))
            )
            passes.append(MetalTransparentPass(kernelName: "metal_text_particle_dissolve", uniforms: u, secondaryTexture: sdfTexture))
        }
        return passes
    }

    private static func applyCoreImageFallbacks(
        to image: CIImage,
        overlay: TextTransformOverlay,
        extent: CGRect
    ) -> CIImage {
        var result = image
        if overlay.liquidWavePhase >= 0.0 { result = applyLiquidWave(to: result, phase: overlay.liquidWavePhase) }
        if overlay.motionBlurRadius > 0.5 { result = applyMotionBlur(to: result, radius: overlay.motionBlurRadius, angle: overlay.motionBlurAngle) }
        return result.cropped(to: extent)
    }

    private static func applyDimColorMatrix(to image: CIImage, scale: CGFloat) -> CIImage {
        CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: image,
            "inputRVector": CIVector(x: scale, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: scale, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: scale, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])?.outputImage ?? image
    }
}

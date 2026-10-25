import Foundation
import CoreGraphics
import CoreImage

/// Bộ xử lý các hiệu ứng Shader & Visual FX (RGB Split, Motion Blur, Light Sweep, Glitch Slice, 3D Perspective, Wave) cho Text Image.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public enum TextShaderFilterEngine: Sendable {
    /// Áp dụng toàn bộ chuỗi hiệu ứng shader lên CIImage
    public static func applyFilters(
        to image: CIImage,
        blurRadius: Double,
        hueAngle: Double,
        pixelateScale: Double,
        rgbSplitIntensity: Double,
        overlay: TextTransformOverlay = TextTransformOverlay(),
        lightSweepIntensity: Double = 0.65
    ) -> CIImage {
        var result = image

        if abs(overlay.perspectiveX) > 0.01 || abs(overlay.perspectiveY) > 0.01 {
            result = applyPerspective3D(to: result, pitchX: overlay.perspectiveX, yawY: overlay.perspectiveY)
        }
        if overlay.liquidWavePhase >= 0.0 {
            result = applyLiquidWave(to: result, phase: overlay.liquidWavePhase)
        }
        if overlay.glitchSliceIntensity > 0.02 {
            result = applyGlitchSlices(to: result, intensity: overlay.glitchSliceIntensity)
        }
        if overlay.lightSweepPhase >= 0.0 {
            let sweepStrength = max(0.35, lightSweepIntensity)
            result = applyLightSweep(to: result, phase: overlay.lightSweepPhase, intensity: sweepStrength)
        }
        if overlay.motionBlurRadius > 0.5 {
            result = applyMotionBlur(to: result, radius: overlay.motionBlurRadius, angle: overlay.motionBlurAngle)
        }
        if blurRadius > 0.001 {
            result = applyBlur(to: result, radius: blurRadius)
        }
        if abs(hueAngle) > 0.001 {
            result = applyHue(to: result, angle: hueAngle)
        }
        if pixelateScale > 1.0 {
            result = applyPixelate(to: result, scale: pixelateScale)
        }
        if rgbSplitIntensity > 0.01 {
            result = applyRGBSplit(to: result, offset: rgbSplitIntensity)
        }

        return result
    }

    private static func applyBlur(to image: CIImage, radius: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: radius
        ]) else { return image }
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    /// Làm nhòe theo hướng chuyển động (Directional Motion Blur) chuẩn điện ảnh
    public static func applyMotionBlur(to image: CIImage, radius: Double, angle: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIMotionBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: min(45.0, max(0.0, radius)),
            kCIInputAngleKey: angle
        ]) else { return image }
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    private static func applyHue(to image: CIImage, angle: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIHueAdjust", parameters: [
            kCIInputImageKey: image,
            kCIInputAngleKey: angle
        ]) else { return image }
        return filter.outputImage ?? image
    }

    private static func applyPixelate(to image: CIImage, scale: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIPixellate", parameters: [
            kCIInputImageKey: image,
            "inputScale": scale
        ]) else { return image }
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    /// Tạo vệt ánh sáng kim loại quét chéo qua bề mặt chữ (Metallic Light Sweep Shimmer)
    public static func applyLightSweep(to image: CIImage, phase: Double, intensity: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return image }
        let normalized = min(1.0, max(0.0, phase))
        let sweepX = extent.minX - extent.width * 0.25 + (extent.width * 1.5) * CGFloat(normalized)
        let bandHalfWidth = max(24.0, extent.width * 0.08)

        let p0 = CIVector(x: sweepX - bandHalfWidth, y: extent.minY)
        let p1 = CIVector(x: sweepX + bandHalfWidth, y: extent.maxY)
        let alpha = CGFloat(min(0.95, max(0.1, intensity)))
        let highlightColor = CIColor(red: 1.0, green: 0.99, blue: 0.92, alpha: alpha)
        let clearColor = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)

        guard let gradLeft = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": p0, "inputPoint1": CIVector(x: sweepX, y: extent.midY),
            "inputColor0": clearColor, "inputColor1": highlightColor
        ])?.outputImage?.cropped(to: extent),
        let gradRight = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: sweepX, y: extent.midY), "inputPoint1": p1,
            "inputColor0": highlightColor, "inputColor1": clearColor
        ])?.outputImage?.cropped(to: extent) else {
            return image
        }

        let leftRect = CGRect(x: extent.minX, y: extent.minY, width: max(0, sweepX - extent.minX), height: extent.height)
        let rightRect = CGRect(x: sweepX, y: extent.minY, width: max(0, extent.maxX - sweepX), height: extent.height)
        let beam = gradLeft.cropped(to: leftRect).composited(over: gradRight.cropped(to: rightRect))

        guard let atop = CIFilter(name: "CISourceAtopCompositing", parameters: [
            kCIInputImageKey: beam,
            kCIInputBackgroundImageKey: image
        ])?.outputImage else { return image }
        return atop.cropped(to: extent)
    }

    /// Cắt lát ngang kỹ thuật số (Digital Glitch Slices)
    public static func applyGlitchSlices(to image: CIImage, intensity: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 12 else { return image }
        let sliceCount = 5
        let sliceH = extent.height / CGFloat(sliceCount)
        var acc = CIImage.empty()

        for i in 0..<sliceCount {
            let sliceRect = CGRect(
                x: extent.minX,
                y: extent.minY + CGFloat(i) * sliceH,
                width: extent.width,
                height: sliceH
            )
            let dir: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let weight: CGFloat = (i == 1 || i == 3) ? 1.0 : 0.35
            let shiftX = dir * weight * CGFloat(intensity) * 24.0
            let sliced = image.cropped(to: sliceRect)
                .transformed(by: CGAffineTransform(translationX: shiftX, y: 0))
                .cropped(to: extent)
            acc = sliced.composited(over: acc)
        }
        return acc.cropped(to: extent)
    }

    /// Phối cảnh 3D (True 3D Perspective Tilt) quanh trục X và trục Y
    public static func applyPerspective3D(to image: CIImage, pitchX: Double, yawY: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 4 else { return image }
        let px = CGFloat(max(-0.85, min(0.85, pitchX))) * extent.width * 0.14
        let py = CGFloat(max(-0.85, min(0.85, yawY))) * extent.height * 0.14

        let tl = CIVector(x: extent.minX + px, y: extent.maxY - py)
        let tr = CIVector(x: extent.maxX - px, y: extent.maxY + py)
        let bl = CIVector(x: extent.minX - px, y: extent.minY + py)
        let br = CIVector(x: extent.maxX + px, y: extent.minY - py)

        guard let filter = CIFilter(name: "CIPerspectiveTransform", parameters: [
            kCIInputImageKey: image,
            "inputTopLeft": tl,
            "inputTopRight": tr,
            "inputBottomLeft": bl,
            "inputBottomRight": br
        ])?.outputImage else { return image }
        return filter.cropped(to: extent)
    }

    /// Biến dạng uốn lượn sóng nước (Liquid Wave Distortion)
    public static func applyLiquidWave(to image: CIImage, phase: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 4 else { return image }
        let cx = extent.midX + CGFloat(sin(phase)) * extent.width * 0.12
        let cy = extent.midY + CGFloat(cos(phase * 1.3)) * extent.height * 0.08
        let radius = max(80.0, min(extent.width, extent.height) * 0.45)
        let scale = CGFloat(sin(phase * 2.0)) * 0.28

        guard let filter = CIFilter(name: "CIBumpDistortion", parameters: [
            kCIInputImageKey: image,
            kCIInputCenterKey: CIVector(x: cx, y: cy),
            kCIInputRadiusKey: radius,
            kCIInputScaleKey: scale
        ])?.outputImage else { return image }
        return filter.cropped(to: extent)
    }

    /// Tách kênh màu RGB (Chromatic Aberration) tạo phong cách Glitch / TikTok hiện đại
    public static func applyRGBSplit(to image: CIImage, offset: Double) -> CIImage {
        let dx = CGFloat(offset)
        let redShift = image.transformed(by: CGAffineTransform(translationX: -dx, y: 0))
        let blueShift = image.transformed(by: CGAffineTransform(translationX: dx, y: 0))

        let rMat = CIVector(x: 1, y: 0, z: 0, w: 0)
        let bMat = CIVector(x: 0, y: 0, z: 1, w: 0)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)

        guard let rFilter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: redShift,
            "inputRVector": rMat, "inputGVector": zero, "inputBVector": zero
        ]), let redOnly = rFilter.outputImage,
        let bFilter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: blueShift,
            "inputRVector": zero, "inputGVector": zero, "inputBVector": bMat
        ]), let blueOnly = bFilter.outputImage else {
            return image
        }

        guard let blend1 = CIFilter(name: "CIScreenBlendMode", parameters: [
            kCIInputImageKey: redOnly,
            kCIInputBackgroundImageKey: image
        ]), let merged1 = blend1.outputImage,
        let blend2 = CIFilter(name: "CIScreenBlendMode", parameters: [
            kCIInputImageKey: blueOnly,
            kCIInputBackgroundImageKey: merged1
        ]), let finalImage = blend2.outputImage else {
            return image
        }

        return finalImage.cropped(to: image.extent.insetBy(dx: -dx * 2, dy: 0))
    }
}

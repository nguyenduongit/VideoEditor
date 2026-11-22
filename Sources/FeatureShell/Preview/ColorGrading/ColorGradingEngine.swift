import Foundation
@preconcurrency import CoreImage
import Domain
import os

/// Engine áp dụng hiệu ứng chỉnh màu GPU thông qua Core Image & Metal Compute Pipeline (không dùng OpenGL/CIKL cũ).
/// Biên độ tác động được hiệu chuẩn theo đáp tuyến các phần mềm chỉnh màu chuyên nghiệp (DaVinci Resolve / Premiere Lumetri).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R9.4 của AGENTS.md.
public final class ColorGradingEngine: Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "ColorGradingEngine")

    public init() {}

    // MARK: - Áp dụng toàn bộ chuỗi lọc màu (Chuẩn NLE: Primary -> Secondary -> Creative LUT -> Post-Effects)

    public func applyGrading(
        to image: CIImage,
        config: AdjustmentConfiguration,
        intensity: Float = 1.0
    ) -> CIImage {
        guard !config.isNeutral && intensity > 0.001 else { return image }
        var result = image
        let basic = config.basic
        let k = max(0.0, min(1.0, intensity))

        // 1. Primary Correction: White Balance -> Exposure -> Highlight/Shadow Recovery -> Tone & S-Contrast -> Sat/Brilliance
        result = applyWhiteBalance(to: result, temp: basic.temp * k, tint: basic.tint * k)
        result = applyExposure(to: result, exposure: basic.exposure * k)
        result = applyHighlightShadowRecovery(to: result, shadow: basic.shadow * k, highlight: basic.highlight * k)
        result = applyToneCurve(
            to: result,
            shadow: basic.shadow * k,
            highlight: basic.highlight * k,
            white: basic.white * k,
            black: basic.black * k,
            contrast: basic.contrast * k,
            brilliance: basic.brilliance * k
        )
        result = applyColorControls(to: result, saturation: basic.saturation * k, contrast: basic.contrast * k)
        result = applyVibrance(to: result, brilliance: basic.brilliance * k)

        // 2. Secondary Grading: 3-Way Color Wheels -> Master/RGB Curves -> 8-Band HSL Selective Color
        result = applyColorWheels(to: result, wheels: config.wheels, intensity: k)
        result = applyColorCurves(to: result, curves: config.curves, intensity: k)
        result = applyHSLSelective(to: result, hsl: config.hsl, intensity: k)

        // 3. Creative Look: 3D LUT (.cube)
        result = applyLUT(to: result, lut: config.lut, intensity: k)

        // 4. Finishing / Post-Effects: Sharpen -> Vignette -> Organic Film Grain
        result = applyEffects(to: result, effects: config.effects, intensity: k)

        return result
    }

    // MARK: - Từng bước bộ lọc Primary

    private func applyWhiteBalance(to image: CIImage, temp: Float, tint: Float) -> CIImage {
        guard temp != 0.0 || tint != 0.0 else { return image }
        var result = image
        let tNorm = CGFloat(max(-1.0, min(1.0, temp / 100.0)))
        let mNorm = CGFloat(max(-1.0, min(1.0, tint / 100.0)))

        if let wbFilter = CIFilter(name: "CITemperatureAndTint") {
            wbFilter.setValue(result, forKey: kCIInputImageKey)
            let neutralKelvin: CGFloat = 6500.0
            // Đáp tuyến phi tuyến theo Mireds: +100 đạt +7500K offset, -100 đạt -3800K offset
            let tempOffset = tNorm >= 0 ? (tNorm * 7500.0) : (tNorm * 3800.0)
            let tintOffset = mNorm * 135.0
            wbFilter.setValue(CIVector(x: neutralKelvin + tempOffset, y: tintOffset), forKey: "inputNeutral")
            wbFilter.setValue(CIVector(x: neutralKelvin, y: 0), forKey: "inputTargetNeutral")
            result = wbFilter.outputImage ?? result
        }

        // Bù ma trận kênh R/G/B chuẩn Lumetri để tạo độ ấm Golden Hour / độ lạnh Deep Blue rõ nét
        if let matrix = CIFilter(name: "CIColorMatrix") {
            let rGain = max(0.2, 1.0 + tNorm * 0.28 + mNorm * 0.12)
            let gGain = max(0.2, 1.0 - mNorm * 0.22 + tNorm * 0.03)
            let bGain = max(0.2, 1.0 - tNorm * 0.30 + mNorm * 0.12)
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: rGain, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: gGain, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: bGain, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            result = matrix.outputImage ?? result
        }
        return result
    }

    private func applyHighlightShadowRecovery(to image: CIImage, shadow: Float, highlight: Float) -> CIImage {
        guard shadow != 0.0 || highlight != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return image }
        let sNorm = CGFloat(max(-1.0, min(1.0, shadow / 100.0)))
        let hNorm = CGFloat(max(-1.0, min(1.0, highlight / 100.0)))
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(sNorm * 0.85, forKey: "inputShadowAmount")
        // Trong CIHighlightShadowAdjust: 1.0 là trung tính, < 1.0 cứu vùng cháy sáng, > 1.0 đẩy sáng highlight
        filter.setValue(max(0.20, min(1.80, 1.0 + hNorm * 0.70)), forKey: "inputHighlightAmount")
        return filter.outputImage ?? image
    }

    private func applyToneCurve(
        to image: CIImage,
        shadow: Float,
        highlight: Float,
        white: Float,
        black: Float,
        contrast: Float = 0.0,
        brilliance: Float = 0.0
    ) -> CIImage {
        guard shadow != 0.0 || highlight != 0.0 || white != 0.0 || black != 0.0 || contrast != 0.0 || brilliance != 0.0 else {
            return image
        }
        guard let filter = CIFilter(name: "CIToneCurve") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)

        let bNorm = CGFloat(max(-1.0, min(1.0, black / 100.0)))
        let sNorm = CGFloat(max(-1.0, min(1.0, shadow / 100.0)))
        let hNorm = CGFloat(max(-1.0, min(1.0, highlight / 100.0)))
        let wNorm = CGFloat(max(-1.0, min(1.0, white / 100.0)))
        let cNorm = CGFloat(max(-1.0, min(1.0, contrast / 100.0)))
        let brNorm = CGFloat(max(-1.0, min(1.0, brilliance / 100.0)))

        let p0X = bNorm < 0 ? (-bNorm * 0.24) : 0.0
        let p0Y = bNorm > 0 ? (bNorm * 0.28) : 0.0
        let p1Y = max(0.01, min(0.49, 0.25 + sNorm * 0.24 + bNorm * 0.14 - cNorm * 0.11 + brNorm * 0.05))
        let p2Y = max(0.25, min(0.75, 0.50 + (sNorm + hNorm) * 0.07 + (bNorm + wNorm) * 0.04 + brNorm * 0.10))
        let p3Y = max(0.51, min(0.99, 0.75 + hNorm * 0.24 + wNorm * 0.14 + cNorm * 0.11 + brNorm * 0.05))
        let p4X = wNorm > 0 ? (1.0 - wNorm * 0.24) : 1.0
        let p4Y = wNorm < 0 ? (1.0 + wNorm * 0.28) : 1.0

        filter.setValue(CIVector(x: p0X, y: p0Y), forKey: "inputPoint0")
        filter.setValue(CIVector(x: 0.25, y: p1Y), forKey: "inputPoint1")
        filter.setValue(CIVector(x: 0.50, y: p2Y), forKey: "inputPoint2")
        filter.setValue(CIVector(x: 0.75, y: p3Y), forKey: "inputPoint3")
        filter.setValue(CIVector(x: p4X, y: p4Y), forKey: "inputPoint4")
        return filter.outputImage ?? image
    }

    private func applyExposure(to image: CIImage, exposure: Float) -> CIImage {
        guard exposure != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue((exposure / 100.0) * 2.8, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }

    private func applyColorControls(to image: CIImage, saturation: Float, contrast: Float) -> CIImage {
        guard saturation != 0.0 || contrast != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        let sNorm = saturation / 100.0
        let cNorm = contrast / 100.0
        let satFactor = sNorm >= 0 ? (1.0 + sNorm * 1.45) : max(0.0, 1.0 + sNorm)
        let conFactor = cNorm >= 0 ? (1.0 + cNorm * 1.10) : max(0.15, 1.0 + cNorm * 0.72)
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(satFactor, forKey: kCIInputSaturationKey)
        filter.setValue(conFactor, forKey: kCIInputContrastKey)
        filter.setValue(0.0, forKey: kCIInputBrightnessKey)
        return filter.outputImage ?? image
    }

    private func applyVibrance(to image: CIImage, brilliance: Float) -> CIImage {
        guard brilliance != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIVibrance") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(max(-1.0, min(1.8, (brilliance / 100.0) * 1.6)), forKey: "inputAmount")
        return filter.outputImage ?? image
    }

    public func applyHSLSelective(to image: CIImage, hsl: HSLAdjustments, intensity: Float = 1.0) -> CIImage {
        guard !hsl.isNeutral, intensity > 0.001, image.extent.width > 0, image.extent.height > 0 else { return image }
        let k = intensity / 100.0
        let channels = [hsl.red, hsl.orange, hsl.yellow, hsl.green, hsl.cyan, hsl.blue, hsl.purple, hsl.magenta]
        var params: [Float] = []
        params.reserveCapacity(24)
        for ch in channels { params.append(ch.hue * k) }
        for ch in channels { params.append(ch.saturation * k) }
        for ch in channels { params.append(ch.luminance * k) }

        return MetalComputeRuntimeEngine.shared.dispatchRawCompute(
            kernelName: "metal_grading_hsl",
            on: image,
            uniformFloats: params,
            canvasRect: image.extent
        )
    }
}

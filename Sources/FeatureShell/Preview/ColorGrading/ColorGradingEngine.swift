import Foundation
@preconcurrency import CoreImage
import Domain
import os

/// Engine áp dụng hiệu ứng chỉnh màu GPU thông qua Core Image & Metal Compute Pipeline (không dùng OpenGL/CIKL cũ).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R9.4 của AGENTS.md.
public final class ColorGradingEngine: Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "ColorGradingEngine")

    public init() {}

    // MARK: - Áp dụng toàn bộ chuỗi lọc màu

    public func applyGrading(
        to image: CIImage,
        config: AdjustmentConfiguration,
        intensity: Float = 1.0
    ) -> CIImage {
        guard !config.isNeutral && intensity > 0.001 else { return image }
        var result = image
        let basic = config.basic
        let k = max(0.0, min(1.0, intensity))

        result = applyLUT(to: result, lut: config.lut, intensity: k)
        result = applyColorCurves(to: result, curves: config.curves, intensity: k)
        result = applyColorWheels(to: result, wheels: config.wheels, intensity: k)
        result = applyWhiteBalance(to: result, temp: basic.temp * k, tint: basic.tint * k)
        result = applyToneCurve(
            to: result,
            shadow: basic.shadow * k,
            highlight: basic.highlight * k,
            white: basic.white * k,
            black: basic.black * k
        )
        result = applyExposure(to: result, exposure: basic.exposure * k)
        result = applyColorControls(to: result, saturation: basic.saturation * k, contrast: basic.contrast * k)
        result = applyVibrance(to: result, brilliance: basic.brilliance * k)
        result = applyHSLSelective(to: result, hsl: config.hsl, intensity: k)
        result = applyEffects(to: result, effects: config.effects, intensity: k)

        return result
    }

    // MARK: - Từng bước bộ lọc

    private func applyWhiteBalance(to image: CIImage, temp: Float, tint: Float) -> CIImage {
        guard temp != 0.0 || tint != 0.0 else { return image }
        guard let wbFilter = CIFilter(name: "CITemperatureAndTint") else { return image }
        wbFilter.setValue(image, forKey: kCIInputImageKey)
        let neutralKelvin: CGFloat = 6500.0
        let tempOffset = CGFloat(temp) * 20.0
        let tintOffset = CGFloat(tint) * 0.5
        wbFilter.setValue(CIVector(x: neutralKelvin + tempOffset, y: tintOffset), forKey: "inputNeutral")
        wbFilter.setValue(CIVector(x: neutralKelvin, y: 0), forKey: "inputTargetNeutral")
        return wbFilter.outputImage ?? image
    }

    private func applyToneCurve(
        to image: CIImage,
        shadow: Float,
        highlight: Float,
        white: Float,
        black: Float
    ) -> CIImage {
        guard shadow != 0.0 || highlight != 0.0 || white != 0.0 || black != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIToneCurve") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        let blackY = max(0.0, min(0.25, CGFloat(black / 100.0) * 0.15))
        let shadowY = max(0.05, min(0.46, 0.25 + CGFloat(shadow / 100.0) * 0.16))
        let midY = max(0.35, min(0.65, 0.50 + CGFloat((shadow + highlight) / 100.0) * 0.04))
        let highlightY = max(0.54, min(0.95, 0.75 + CGFloat(highlight / 100.0) * 0.16))
        let whiteY = max(0.75, min(1.0, 1.0 + CGFloat(white / 100.0) * 0.15))
        filter.setValue(CIVector(x: 0.0, y: blackY), forKey: "inputPoint0")
        filter.setValue(CIVector(x: 0.25, y: shadowY), forKey: "inputPoint1")
        filter.setValue(CIVector(x: 0.5, y: midY), forKey: "inputPoint2")
        filter.setValue(CIVector(x: 0.75, y: highlightY), forKey: "inputPoint3")
        filter.setValue(CIVector(x: 1.0, y: whiteY), forKey: "inputPoint4")
        return filter.outputImage ?? image
    }

    private func applyExposure(to image: CIImage, exposure: Float) -> CIImage {
        guard exposure != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue((exposure / 100.0) * 2.0, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }

    private func applyColorControls(to image: CIImage, saturation: Float, contrast: Float) -> CIImage {
        guard saturation != 0.0 || contrast != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(max(0.0, 1.0 + (saturation / 100.0)), forKey: kCIInputSaturationKey)
        filter.setValue(max(0.0, 1.0 + (contrast / 100.0) * 0.6), forKey: kCIInputContrastKey)
        filter.setValue(0.0, forKey: kCIInputBrightnessKey)
        return filter.outputImage ?? image
    }

    private func applyVibrance(to image: CIImage, brilliance: Float) -> CIImage {
        guard brilliance != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIVibrance") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(max(-1.0, min(1.0, brilliance / 100.0)), forKey: "inputAmount")
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

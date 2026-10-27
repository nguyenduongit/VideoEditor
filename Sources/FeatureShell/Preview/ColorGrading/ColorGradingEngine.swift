import Foundation
@preconcurrency import CoreImage
import Domain
import os

/// Engine áp dụng hiệu ứng chỉnh màu GPU thông qua Core Image & CIColorKernel.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R9.4 của AGENTS.md.
public final class ColorGradingEngine: Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "ColorGradingEngine")

    public init() {}

    // MARK: - CIColorKernel HSL 8 dải màu
    /// CIColorKernel là immutable sau khi biên dịch từ mã nguồn shader, thread-safe theo Apple Core Image (R8.3).
    nonisolated(unsafe) private static let hslSelectiveKernel: CIColorKernel? = {
        let source = """
        kernel vec4 hslSelectiveKernel(
            __sample s,
            vec4 dHue0_3, vec4 dHue4_7,
            vec4 dSat0_3, vec4 dSat4_7,
            vec4 dLum0_3, vec4 dLum4_7
        ) {
            float r = s.r; float g = s.g; float b = s.b;
            float maxC = max(r, max(g, b));
            float minC = min(r, min(g, b));
            float delta = maxC - minC;
            float lum = (maxC + minC) * 0.5;
            if (delta < 0.001 || lum < 0.005 || lum > 0.995) { return s; }
            float sat = lum > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC);
            if (sat < 0.03) { return s; }

            float hue = 0.0;
            if (r == maxC) {
                hue = (g - b) / delta;
                if (hue < 0.0) hue += 6.0;
            } else if (g == maxC) {
                hue = 2.0 + (b - r) / delta;
            } else {
                hue = 4.0 + (r - g) / delta;
            }
            hue = hue / 6.0;

            float centers[8];
            centers[0] = 0.0; centers[1] = 0.0833; centers[2] = 0.1667; centers[3] = 0.3333;
            centers[4] = 0.5000; centers[5] = 0.6667; centers[6] = 0.7917; centers[7] = 0.9028;

            float widths[8];
            widths[0] = 0.075; widths[1] = 0.065; widths[2] = 0.065; widths[3] = 0.110;
            widths[4] = 0.090; widths[5] = 0.090; widths[6] = 0.080; widths[7] = 0.080;

            float dH[8];
            dH[0] = dHue0_3.x; dH[1] = dHue0_3.y; dH[2] = dHue0_3.z; dH[3] = dHue0_3.w;
            dH[4] = dHue4_7.x; dH[5] = dHue4_7.y; dH[6] = dHue4_7.z; dH[7] = dHue4_7.w;

            float dS[8];
            dS[0] = dSat0_3.x; dS[1] = dSat0_3.y; dS[2] = dSat0_3.z; dS[3] = dSat0_3.w;
            dS[4] = dSat4_7.x; dS[5] = dSat4_7.y; dS[6] = dSat4_7.z; dS[7] = dSat4_7.w;

            float dL[8];
            dL[0] = dLum0_3.x; dL[1] = dLum0_3.y; dL[2] = dLum0_3.z; dL[3] = dLum0_3.w;
            dL[4] = dLum4_7.x; dL[5] = dLum4_7.y; dL[6] = dLum4_7.z; dL[7] = dLum4_7.w;

            float totalDeltaH = 0.0; float totalDeltaS = 0.0; float totalDeltaL = 0.0; float totalW = 0.0;
            for (int i = 0; i < 8; i++) {
                float d = abs(hue - centers[i]);
                if (d > 0.5) d = 1.0 - d;
                if (d < widths[i]) {
                    float c = cos((d / widths[i]) * 1.57079632679);
                    float w = c * c;
                    totalDeltaH += dH[i] * w; totalDeltaS += dS[i] * w; totalDeltaL += dL[i] * w; totalW += w;
                }
            }
            if (totalW < 0.001) { return s; }

            float satRoll = smoothstep(0.03, 0.15, sat);
            totalDeltaH *= satRoll; totalDeltaS *= satRoll; totalDeltaL *= satRoll;
            hue = fract(hue + totalDeltaH * 0.15);
            if (hue < 0.0) hue += 1.0;
            sat = clamp(sat * (1.0 + totalDeltaS), 0.0, 1.0);
            lum = clamp(lum + totalDeltaL * 0.35, 0.0, 1.0);

            float q = lum < 0.5 ? lum * (1.0 + sat) : lum + sat - lum * sat;
            float p = 2.0 * lum - q;
            vec3 rgb;
            vec3 t = vec3(hue + 0.33333333, hue, hue - 0.33333333);
            if (t.x < 0.0) t.x += 1.0; else if (t.x > 1.0) t.x -= 1.0;
            if (t.y < 0.0) t.y += 1.0; else if (t.y > 1.0) t.y -= 1.0;
            if (t.z < 0.0) t.z += 1.0; else if (t.z > 1.0) t.z -= 1.0;

            if (t.x < 0.16666667) rgb.r = p + (q - p) * 6.0 * t.x;
            else if (t.x < 0.5) rgb.r = q;
            else if (t.x < 0.66666667) rgb.r = p + (q - p) * (0.66666667 - t.x) * 6.0;
            else rgb.r = p;

            if (t.y < 0.16666667) rgb.g = p + (q - p) * 6.0 * t.y;
            else if (t.y < 0.5) rgb.g = q;
            else if (t.y < 0.66666667) rgb.g = p + (q - p) * (0.66666667 - t.y) * 6.0;
            else rgb.g = p;

            if (t.z < 0.16666667) rgb.b = p + (q - p) * 6.0 * t.z;
            else if (t.z < 0.5) rgb.b = q;
            else if (t.z < 0.66666667) rgb.b = p + (q - p) * (0.66666667 - t.z) * 6.0;
            else rgb.b = p;

            return vec4(rgb, s.a);
        }
        """
        return CIColorKernel(source: source)
    }()

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
        let ev = (exposure / 100.0) * 2.0
        filter.setValue(ev, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }

    private func applyColorControls(to image: CIImage, saturation: Float, contrast: Float) -> CIImage {
        guard saturation != 0.0 || contrast != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        let satFactor = max(0.0, 1.0 + (saturation / 100.0))
        let conFactor = max(0.0, 1.0 + (contrast / 100.0) * 0.6)
        filter.setValue(satFactor, forKey: kCIInputSaturationKey)
        filter.setValue(conFactor, forKey: kCIInputContrastKey)
        filter.setValue(0.0, forKey: kCIInputBrightnessKey)
        return filter.outputImage ?? image
    }

    private func applyVibrance(to image: CIImage, brilliance: Float) -> CIImage {
        guard brilliance != 0.0 else { return image }
        guard let filter = CIFilter(name: "CIVibrance") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        let amount = max(-1.0, min(1.0, brilliance / 100.0))
        filter.setValue(amount, forKey: "inputAmount")
        return filter.outputImage ?? image
    }

    public func applyHSLSelective(to image: CIImage, hsl: HSLAdjustments, intensity: Float = 1.0) -> CIImage {
        guard !hsl.isNeutral, intensity > 0.001 else { return image }
        guard let kernel = Self.hslSelectiveKernel else { return image }
        let k = CGFloat(intensity)

        let dH0_3 = CIVector(x: CGFloat(hsl.red.hue / 100.0) * k, y: CGFloat(hsl.orange.hue / 100.0) * k,
                             z: CGFloat(hsl.yellow.hue / 100.0) * k, w: CGFloat(hsl.green.hue / 100.0) * k)
        let dS0_3 = CIVector(x: CGFloat(hsl.red.saturation / 100.0) * k, y: CGFloat(hsl.orange.saturation / 100.0) * k,
                             z: CGFloat(hsl.yellow.saturation / 100.0) * k, w: CGFloat(hsl.green.saturation / 100.0) * k)
        let dL0_3 = CIVector(x: CGFloat(hsl.red.luminance / 100.0) * k, y: CGFloat(hsl.orange.luminance / 100.0) * k,
                             z: CGFloat(hsl.yellow.luminance / 100.0) * k, w: CGFloat(hsl.green.luminance / 100.0) * k)

        let dH4_7 = CIVector(x: CGFloat(hsl.cyan.hue / 100.0) * k, y: CGFloat(hsl.blue.hue / 100.0) * k,
                             z: CGFloat(hsl.purple.hue / 100.0) * k, w: CGFloat(hsl.magenta.hue / 100.0) * k)
        let dS4_7 = CIVector(x: CGFloat(hsl.cyan.saturation / 100.0) * k, y: CGFloat(hsl.blue.saturation / 100.0) * k,
                             z: CGFloat(hsl.purple.saturation / 100.0) * k, w: CGFloat(hsl.magenta.saturation / 100.0) * k)
        let dL4_7 = CIVector(x: CGFloat(hsl.cyan.luminance / 100.0) * k, y: CGFloat(hsl.blue.luminance / 100.0) * k,
                             z: CGFloat(hsl.purple.luminance / 100.0) * k, w: CGFloat(hsl.magenta.luminance / 100.0) * k)

        return kernel.apply(
            extent: image.extent,
            arguments: [image, dH0_3, dH4_7, dS0_3, dS4_7, dL0_3, dL4_7]
        ) ?? image
    }
}

import Foundation
@preconcurrency import CoreImage
import CoreGraphics
import Domain
import os

/// Extension mở rộng cho `ColorGradingEngine` thực thi các bộ lọc nâng cao:
/// 3D LUT (bảo toàn Premultiplied Alpha), Color Wheels (Metal GPU), Independent Master/R/G/B Curves,
/// Vignette (có Feather/Falloff), Organic Film Grain (Metal GPU) và Sharpen.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng), 0 force-unwrap và R9.4 của AGENTS.md.
extension ColorGradingEngine {

    // MARK: - Color Wheels (Metal Compute)

    func applyColorWheels(
        to image: CIImage,
        wheels: ColorWheelsAdjustments,
        intensity: Float
    ) -> CIImage {
        guard !wheels.isNeutral, intensity > 0.001, image.extent.width > 0, image.extent.height > 0 else {
            return image
        }
        let k = intensity
        let liftVec = Self.wheelOffsetToRGBLuma(wheels.lift, scale: 0.78 * k, lumaScale: k / 95.0)
        let gammaVec = Self.wheelOffsetToRGBLuma(wheels.gamma, scale: 0.78 * k, lumaScale: k / 95.0)
        let gainVec = Self.wheelOffsetToRGBLuma(wheels.gain, scale: 0.78 * k, lumaScale: k / 95.0)
        let params: [Float] = liftVec + gammaVec + gainVec
        return MetalComputeRuntimeEngine.shared.dispatchRawCompute(
            kernelName: "metal_grading_wheels",
            on: image,
            uniformFloats: params,
            canvasRect: image.extent
        )
    }

    /// Chuyển đổi tọa độ cực `(x, y)` trên bánh xe màu (`0°=Red`, `60°=Yellow`, `120°=Green`, `180°=Cyan`, `240°=Blue`, `300°=Magenta`)
    /// sang vector bù trừ màu RGB trung hòa độ sáng (`dR + dG + dB == 0`) với đáp tuyến phi tuyến nhạy ở vùng tinh chỉnh.
    static func wheelOffsetToRGBLuma(
        _ offset: ColorWheelOffset,
        scale: Float,
        lumaScale: Float
    ) -> [Float] {
        let rawRadius = min(1.0, hypot(offset.x, offset.y))
        let dLuma = offset.luma * lumaScale
        guard rawRadius > 0.0001 else {
            return [0.0, 0.0, 0.0, dLuma]
        }
        // Đáp tuyến gamma 0.82 giúp các bước kéo nhỏ (0.10..0.35) có lực tác động tương đương DaVinci Resolve
        let radius = pow(rawRadius, 0.82)
        var angle = atan2(offset.y, offset.x)
        if angle < 0 { angle += 2.0 * .pi }
        let h6 = (angle / (2.0 * .pi)) * 6.0
        let sector = Int(floor(h6)) % 6
        let f = h6 - floor(h6)
        let q = 1.0 - f
        let (r, g, b): (Float, Float, Float) = {
            switch sector {
            case 0: return (1.0, f, 0.0)
            case 1: return (q, 1.0, 0.0)
            case 2: return (0.0, 1.0, f)
            case 3: return (0.0, q, 1.0)
            case 4: return (f, 0.0, 1.0)
            default: return (1.0, 0.0, q)
            }
        }()
        let mean = (r + g + b) / 3.0
        let strength = radius * scale
        return [(r - mean) * strength, (g - mean) * strength, (b - mean) * strength, dLuma]
    }

    // MARK: - Color Curves (Master + Independent R / G / B)

    func applyColorCurves(
        to image: CIImage,
        curves: ColorCurvesAdjustments,
        intensity: Float
    ) -> CIImage {
        guard !curves.isNeutral, intensity > 0.001 else { return image }
        let k = CGFloat(intensity)
        var result = applyMasterToneCurve(to: image, points: curves.master, k: k)

        if (!isChannelLinear(curves.red) || !isChannelLinear(curves.green) || !isChannelLinear(curves.blue)),
           result.extent.width > 0, result.extent.height > 0 {
            let rSamples = sampleCurve5(points: curves.red, k: k)
            let gSamples = sampleCurve5(points: curves.green, k: k)
            let bSamples = sampleCurve5(points: curves.blue, k: k)
            result = MetalComputeRuntimeEngine.shared.dispatchRawCompute(
                kernelName: "metal_grading_rgb_curves",
                on: result,
                uniformFloats: rSamples + gSamples + bSamples,
                canvasRect: result.extent
            )
        }
        return result
    }

    private func applyMasterToneCurve(to image: CIImage, points: [CurvePoint], k: CGFloat) -> CIImage {
        guard !isChannelLinear(points), let filter = CIFilter(name: "CIToneCurve") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 0.00, y: interpolateCurveY(at: 0.00, in: points, k: k)), forKey: "inputPoint0")
        filter.setValue(CIVector(x: 0.25, y: interpolateCurveY(at: 0.25, in: points, k: k)), forKey: "inputPoint1")
        filter.setValue(CIVector(x: 0.50, y: interpolateCurveY(at: 0.50, in: points, k: k)), forKey: "inputPoint2")
        filter.setValue(CIVector(x: 0.75, y: interpolateCurveY(at: 0.75, in: points, k: k)), forKey: "inputPoint3")
        filter.setValue(CIVector(x: 1.00, y: interpolateCurveY(at: 1.00, in: points, k: k)), forKey: "inputPoint4")
        return filter.outputImage ?? image
    }

    private func sampleCurve5(points: [CurvePoint], k: CGFloat) -> [Float] {
        [0.0, 0.25, 0.50, 0.75, 1.0].map { x in
            Float(interpolateCurveY(at: x, in: points, k: k))
        }
    }

    private func isChannelLinear(_ points: [CurvePoint]) -> Bool {
        guard points.count == 2 else { return false }
        return abs(points[0].x - 0.0) < 0.001 && abs(points[0].y - 0.0) < 0.001 &&
               abs(points[1].x - 1.0) < 0.001 && abs(points[1].y - 1.0) < 0.001
    }

    /// Nội suy đường cong Catmull-Rom Spline đơn điệu bị chặn trong `[0, 1]`, khớp với đồ thị `ColorCurvesControlView`.
    func interpolateCurveY(at x: Float, in points: [CurvePoint], k: CGFloat) -> CGFloat {
        let sorted = points.sorted { $0.x < $1.x }
        guard let firstPt = sorted.first, let lastPt = sorted.last else { return CGFloat(x) }
        if x <= firstPt.x {
            return max(0.0, min(1.0, CGFloat(x) + (CGFloat(firstPt.y) - CGFloat(x)) * k))
        }
        if x >= lastPt.x {
            return max(0.0, min(1.0, CGFloat(x) + (CGFloat(lastPt.y) - CGFloat(x)) * k))
        }
        for i in 0..<(sorted.count - 1) {
            let p1 = sorted[i]
            let p2 = sorted[i + 1]
            if x >= p1.x && x <= p2.x {
                let dx = max(0.0001, p2.x - p1.x)
                let t = CGFloat((x - p1.x) / dx)
                let targetY: CGFloat
                if sorted.count == 2 {
                    targetY = CGFloat(p1.y) + t * CGFloat(p2.y - p1.y)
                } else {
                    let p0 = i > 0 ? sorted[i - 1] : p1
                    let p3 = (i + 2 < sorted.count) ? sorted[i + 2] : p2
                    let y0 = CGFloat(p0.y), y1 = CGFloat(p1.y), y2 = CGFloat(p2.y), y3 = CGFloat(p3.y)
                    let t2 = t * t, t3 = t2 * t
                    let splineY = 0.5 * ((2.0 * y1) + (-y0 + y2) * t +
                        (2.0 * y0 - 5.0 * y1 + 4.0 * y2 - y3) * t2 +
                        (-y0 + 3.0 * y1 - 3.0 * y2 + y3) * t3)
                    targetY = max(0.0, min(1.0, splineY))
                }
                return max(0.0, min(1.0, CGFloat(x) + (targetY - CGFloat(x)) * k))
            }
        }
        return CGFloat(x)
    }

    // MARK: - 3D LUT (.cube) — Premultiplied Alpha Safe

    func applyLUT(
        to image: CIImage,
        lut: LUTConfiguration,
        intensity: Float
    ) -> CIImage {
        guard !lut.isNeutral, intensity > 0.001 else { return image }
        guard let parsed = LUTParser.parse(cubeString: lut.lutDataString),
              let colorCubeFilter = CIFilter(name: "CIColorCube") else { return image }

        colorCubeFilter.setValue(image, forKey: kCIInputImageKey)
        colorCubeFilter.setValue(parsed.dimension, forKey: "inputCubeDimension")
        colorCubeFilter.setValue(parsed.cubeData, forKey: "inputCubeData")

        guard let lutOutput = colorCubeFilter.outputImage else { return image }
        let blendWeight = max(0.0, min(1.0, (lut.intensity / 100.0) * intensity))
        if blendWeight >= 0.999 { return lutOutput }
        if blendWeight <= 0.001 { return image }

        if let dissolve = CIFilter(name: "CIDissolveTransition", parameters: [
            kCIInputImageKey: image,
            kCIInputTargetImageKey: lutOutput,
            kCIInputTimeKey: CGFloat(blendWeight)
        ]), let blended = dissolve.outputImage {
            return blended.cropped(to: image.extent)
        }
        let premultLUT = TextSVGAndAssetCache.applyPremultipliedOpacity(Double(blendWeight), to: lutOutput)
        let premultBase = TextSVGAndAssetCache.applyPremultipliedOpacity(Double(1.0 - blendWeight), to: image)
        return premultLUT.composited(over: premultBase).cropped(to: image.extent)
    }

    // MARK: - Film Effects (Sharpen -> Vignette with Feather -> Film Grain)

    func applyEffects(
        to image: CIImage,
        effects: EffectsGradingParameters,
        intensity: Float
    ) -> CIImage {
        guard !effects.isNeutral, intensity > 0.001 else { return image }
        var result = image
        let k = intensity

        // 1. Sharpen trước để không làm gắt hạt Film Grain
        if effects.sharpenAmount > 0.001, let sharpFilter = CIFilter(name: "CISharpenLuminance") {
            sharpFilter.setValue(result, forKey: kCIInputImageKey)
            sharpFilter.setValue((effects.sharpenAmount / 100.0) * k * 2.8, forKey: "inputSharpness")
            sharpFilter.setValue(2.2, forKey: "inputRadius")
            if let output = sharpFilter.outputImage {
                result = output.cropped(to: image.extent)
            }
        }

        // 2. Vignette hỗ trợ đầy đủ Amount, Midpoint (Radius) và Feather (Falloff)
        if abs(effects.vignetteAmount) > 0.001 {
            result = applyVignette(to: result, effects: effects, k: k)
        }

        // 3. Organic Monochromatic Film Grain ở cuối cùng
        if effects.grainAmount > 0.001, result.extent.width > 0, result.extent.height > 0 {
            let grainStrength = max(0.0, min(1.0, (effects.grainAmount / 100.0) * k))
            let grainCellSize = 1.0 + (max(0.0, min(100.0, effects.grainSize)) / 100.0) * 2.5
            result = MetalComputeRuntimeEngine.shared.dispatchRawCompute(
                kernelName: "metal_grading_film_grain",
                on: result,
                uniformFloats: [grainStrength, grainCellSize],
                canvasRect: result.extent
            )
        }

        return result
    }

    private func applyVignette(
        to image: CIImage,
        effects: EffectsGradingParameters,
        k: Float
    ) -> CIImage {
        let ext = image.extent
        let featherNorm = max(0.0, min(1.0, effects.vignetteFeather / 100.0))
        let midNorm = max(0.05, min(1.0, effects.vignetteMidpoint / 100.0))
        if ext.width > 0, ext.height > 0, let vigEffect = CIFilter(name: "CIVignetteEffect") {
            let halfDiag = hypot(ext.width * 0.5, ext.height * 0.5)
            vigEffect.setValue(image, forKey: kCIInputImageKey)
            vigEffect.setValue(CIVector(x: ext.midX, y: ext.midY), forKey: kCIInputCenterKey)
            vigEffect.setValue(max(8.0, halfDiag * CGFloat(0.12 + midNorm * 0.62)), forKey: kCIInputRadiusKey)
            let effIntensity = max(-1.0, min(1.0, (effects.vignetteAmount / 100.0) * k * 1.85))
            vigEffect.setValue(CGFloat(effIntensity), forKey: kCIInputIntensityKey)
            vigEffect.setValue(CGFloat(0.08 + featherNorm * 0.90), forKey: "inputFalloff")
            if let output = vigEffect.outputImage {
                return output.cropped(to: ext)
            }
        }
        guard let vigFilter = CIFilter(name: "CIVignette") else { return image }
        vigFilter.setValue(image, forKey: kCIInputImageKey)
        vigFilter.setValue((effects.vignetteAmount / 100.0) * k * 2.5, forKey: "inputIntensity")
        vigFilter.setValue(max(0.1, (midNorm * 2.0) + (featherNorm * 0.6)), forKey: "inputRadius")
        return vigFilter.outputImage?.cropped(to: ext) ?? image
    }
}

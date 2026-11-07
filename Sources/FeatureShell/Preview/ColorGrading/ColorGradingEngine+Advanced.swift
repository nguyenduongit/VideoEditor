import Foundation
@preconcurrency import CoreImage
import CoreGraphics
import Domain
import os

/// Extension mở rộng cho `ColorGradingEngine` thực thi các bộ lọc nâng cao:
/// 3D LUT (bảo toàn Premultiplied Alpha), Color Wheels (Metal GPU), Independent Master/R/G/B Curves,
/// Vignette, Organic Film Grain (Metal GPU) và Sharpen.
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
        let params: [Float] = [
            wheels.lift.x * 0.25 * k, -wheels.lift.y * 0.25 * k, wheels.lift.y * 0.15 * k, (wheels.lift.luma / 200.0) * k,
            wheels.gamma.x * 0.25 * k, -wheels.gamma.y * 0.25 * k, wheels.gamma.y * 0.15 * k, (wheels.gamma.luma / 200.0) * k,
            wheels.gain.x * 0.25 * k, -wheels.gain.y * 0.25 * k, wheels.gain.y * 0.15 * k, (wheels.gain.luma / 200.0) * k
        ]
        return MetalComputeRuntimeEngine.shared.dispatchRawCompute(
            kernelName: "metal_grading_wheels",
            on: image,
            uniformFloats: params,
            canvasRect: image.extent
        )
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

    private func interpolateCurveY(at x: Float, in points: [CurvePoint], k: CGFloat) -> CGFloat {
        let sorted = points.sorted { $0.x < $1.x }
        guard let firstPt = sorted.first, let lastPt = sorted.last else { return CGFloat(x) }
        if x <= firstPt.x {
            return CGFloat(x) + (CGFloat(firstPt.y) - CGFloat(x)) * k
        }
        if x >= lastPt.x {
            return CGFloat(x) + (CGFloat(lastPt.y) - CGFloat(x)) * k
        }
        for i in 0..<(sorted.count - 1) {
            let pA = sorted[i]
            let pB = sorted[i + 1]
            if x >= pA.x && x <= pB.x {
                let dx = max(0.0001, pB.x - pA.x)
                let t = (x - pA.x) / dx
                let targetY = CGFloat(pA.y + t * (pB.y - pA.y))
                return CGFloat(x) + (targetY - CGFloat(x)) * k
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

    // MARK: - Film Effects (Vignette, Film Grain, Sharpen)

    func applyEffects(
        to image: CIImage,
        effects: EffectsGradingParameters,
        intensity: Float
    ) -> CIImage {
        guard !effects.isNeutral, intensity > 0.001 else { return image }
        var result = image
        let k = intensity

        if abs(effects.vignetteAmount) > 0.001, let vigFilter = CIFilter(name: "CIVignette") {
            vigFilter.setValue(result, forKey: kCIInputImageKey)
            vigFilter.setValue((effects.vignetteAmount / 100.0) * k * 2.0, forKey: "inputIntensity")
            vigFilter.setValue(max(0.1, (effects.vignetteMidpoint / 100.0) * 3.0), forKey: "inputRadius")
            if let output = vigFilter.outputImage {
                result = output.cropped(to: image.extent)
            }
        }

        if effects.sharpenAmount > 0.001, let sharpFilter = CIFilter(name: "CISharpenLuminance") {
            sharpFilter.setValue(result, forKey: kCIInputImageKey)
            sharpFilter.setValue((effects.sharpenAmount / 100.0) * k * 1.5, forKey: "inputSharpness")
            if let output = sharpFilter.outputImage {
                result = output.cropped(to: image.extent)
            }
        }

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
}

import Foundation
@preconcurrency import CoreImage
import CoreGraphics
import Domain
import os

/// Extension mở rộng cho ColorGradingEngine thực thi các bộ lọc nâng cao:
/// 3D LUT, Color Wheels, Curves, Vignette, Film Grain, Sharpen.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R9.4 của AGENTS.md.
extension ColorGradingEngine {

    /// CIColorKernel là immutable sau khi biên dịch từ mã nguồn shader, thread-safe theo Apple Core Image (R8.3).
    nonisolated(unsafe) private static let colorWheelsKernel: CIColorKernel? = {
        let source = """
        kernel vec4 colorWheelsKernel(
            __sample s,
            vec4 lift,
            vec4 gamma,
            vec4 gain
        ) {
            vec3 rgb = s.rgb;
            float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));

            // 1. Lift (Shadows): tỷ trọng cao ở vùng tối (1.0 - luma)
            float wLift = clamp(1.0 - luma, 0.0, 1.0);
            rgb += lift.rgb * wLift;
            rgb += vec3(lift.w) * wLift;

            // 2. Gamma (Midtones): tỷ trọng cao ở vùng trung gian (luma ~ 0.5)
            float diff = luma - 0.5;
            float wGamma = clamp(1.0 - 4.0 * diff * diff, 0.0, 1.0);
            rgb += gamma.rgb * wGamma;
            rgb += vec3(gamma.w) * wGamma;

            // 3. Gain (Highlights): tỷ trọng cao ở vùng sáng (luma)
            float wGain = clamp(luma, 0.0, 1.0);
            rgb += gain.rgb * wGain;
            rgb += vec3(gain.w) * wGain;

            return vec4(clamp(rgb, 0.0, 1.0), s.a);
        }
        """
        return CIColorKernel(source: source)
    }()

    // MARK: - Color Wheels

    func applyColorWheels(
        to image: CIImage,
        wheels: ColorWheelsAdjustments,
        intensity: Float
    ) -> CIImage {
        guard !wheels.isNeutral, intensity > 0.001 else { return image }
        guard let kernel = Self.colorWheelsKernel else { return image }
        let k = CGFloat(intensity)

        // Quy đổi tọa độ x, y trên bánh xe màu thành vector dịch chuyển RGB
        let liftVec = CIVector(
            x: CGFloat(wheels.lift.x * 0.25) * k,
            y: CGFloat(-wheels.lift.y * 0.25) * k,
            z: CGFloat(wheels.lift.y * 0.15) * k,
            w: CGFloat(wheels.lift.luma / 200.0) * k
        )

        let gammaVec = CIVector(
            x: CGFloat(wheels.gamma.x * 0.25) * k,
            y: CGFloat(-wheels.gamma.y * 0.25) * k,
            z: CGFloat(wheels.gamma.y * 0.15) * k,
            w: CGFloat(wheels.gamma.luma / 200.0) * k
        )

        let gainVec = CIVector(
            x: CGFloat(wheels.gain.x * 0.25) * k,
            y: CGFloat(-wheels.gain.y * 0.25) * k,
            z: CGFloat(wheels.gain.y * 0.15) * k,
            w: CGFloat(wheels.gain.luma / 200.0) * k
        )

        return kernel.apply(
            extent: image.extent,
            arguments: [image, liftVec, gammaVec, gainVec]
        ) ?? image
    }

    // MARK: - Color Curves

    func applyColorCurves(
        to image: CIImage,
        curves: ColorCurvesAdjustments,
        intensity: Float
    ) -> CIImage {
        guard !curves.isNeutral, intensity > 0.001 else { return image }
        guard let filter = CIFilter(name: "CIToneCurve") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)

        // Tính 5 điểm neo nội suy trên Master Curve
        let pts = curves.master
        let k = CGFloat(intensity)

        let p0Y = interpolateCurveY(at: 0.0, in: pts, k: k)
        let p1Y = interpolateCurveY(at: 0.25, in: pts, k: k)
        let p2Y = interpolateCurveY(at: 0.50, in: pts, k: k)
        let p3Y = interpolateCurveY(at: 0.75, in: pts, k: k)
        let p4Y = interpolateCurveY(at: 1.0, in: pts, k: k)

        filter.setValue(CIVector(x: 0.0, y: p0Y), forKey: "inputPoint0")
        filter.setValue(CIVector(x: 0.25, y: p1Y), forKey: "inputPoint1")
        filter.setValue(CIVector(x: 0.50, y: p2Y), forKey: "inputPoint2")
        filter.setValue(CIVector(x: 0.75, y: p3Y), forKey: "inputPoint3")
        filter.setValue(CIVector(x: 1.0, y: p4Y), forKey: "inputPoint4")

        return filter.outputImage ?? image
    }

    private func interpolateCurveY(at x: Float, in points: [CurvePoint], k: CGFloat) -> CGFloat {
        guard !points.isEmpty else { return CGFloat(x) }
        let sorted = points.sorted { $0.x < $1.x }
        if x <= sorted.first!.x {
            let targetY = CGFloat(sorted.first!.y)
            return CGFloat(x) + (targetY - CGFloat(x)) * k
        }
        if x >= sorted.last!.x {
            let targetY = CGFloat(sorted.last!.y)
            return CGFloat(x) + (targetY - CGFloat(x)) * k
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

    // MARK: - 3D LUT (.cube)

    func applyLUT(
        to image: CIImage,
        lut: LUTConfiguration,
        intensity: Float
    ) -> CIImage {
        guard !lut.isNeutral, intensity > 0.001 else { return image }
        guard let parsed = LUTParser.parse(cubeString: lut.lutDataString) else { return image }
        guard let colorCubeFilter = CIFilter(name: "CIColorCube") else { return image }

        colorCubeFilter.setValue(image, forKey: kCIInputImageKey)
        colorCubeFilter.setValue(parsed.dimension, forKey: "inputCubeDimension")
        colorCubeFilter.setValue(parsed.cubeData, forKey: "inputCubeData")

        guard let lutOutput = colorCubeFilter.outputImage else { return image }
        let blendWeight = (lut.intensity / 100.0) * intensity
        if blendWeight >= 0.999 { return lutOutput }

        let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, min(1.0, blendWeight))))
        guard let alphaFilter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: lutOutput,
            "inputAVector": alphaVector
        ]), let semiTransparentLUT = alphaFilter.outputImage else {
            return lutOutput
        }

        return semiTransparentLUT.composited(over: image)
    }

    // MARK: - Film Effects (Vignette, Grain, Sharpen)

    func applyEffects(
        to image: CIImage,
        effects: EffectsGradingParameters,
        intensity: Float
    ) -> CIImage {
        guard !effects.isNeutral, intensity > 0.001 else { return image }
        var result = image
        let k = intensity

        // 1. Vignette (Tối 4 góc)
        if effects.vignetteAmount != 0.0 {
            if let vigFilter = CIFilter(name: "CIVignette") {
                vigFilter.setValue(result, forKey: kCIInputImageKey)
                let vigIntensity = (effects.vignetteAmount / 100.0) * k * 2.0
                let vigRadius = max(0.1, (effects.vignetteMidpoint / 100.0) * 3.0)
                vigFilter.setValue(vigIntensity, forKey: "inputIntensity")
                vigFilter.setValue(vigRadius, forKey: "inputRadius")
                if let output = vigFilter.outputImage {
                    result = output
                }
            }
        }

        // 2. Sharpen (Làm nét chi tiết)
        if effects.sharpenAmount > 0.0 {
            if let sharpFilter = CIFilter(name: "CISharpenLuminance") {
                sharpFilter.setValue(result, forKey: kCIInputImageKey)
                let sharpness = (effects.sharpenAmount / 100.0) * k * 1.5
                sharpFilter.setValue(sharpness, forKey: "inputSharpness")
                if let output = sharpFilter.outputImage {
                    result = output
                }
            }
        }

        return result
    }
}

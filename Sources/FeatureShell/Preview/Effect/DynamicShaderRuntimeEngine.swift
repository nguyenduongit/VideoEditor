import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Động cơ thực thi Gói Sáng Tạo Mở (Open Creative Package Runtime Engine).
/// Tích hợp trực tiếp với `MetalComputeRuntimeEngine` (GPU Compute Pipeline cho Mac Intel `x86_64`)
/// và hỗ trợ chuỗi kết hợp đa tầng ở tốc độ 60fps.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R8.3 (Thread-safe).
public final class DynamicShaderRuntimeEngine: @unchecked Sendable {
    public static let shared = DynamicShaderRuntimeEngine()

    public init() {}

    /// Thực thi toàn bộ chuỗi pipeline đồ họa động lên khung hình `image`.
    public func executePipeline(
        on image: CIImage,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double,
        canvasSize: CGSize
    ) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var current = image
        for step in config.filterPipeline {
            current = applyStep(
                step, to: current, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect
            )
        }
        return current
    }

    /// Thực thi hiệu ứng chuyển cảnh (Dual-Texture Transition) giữa `fromImage` (Clip A) và `toImage` (Clip B)
    /// bằng Metal Compute Kernel trên GPU.
    public func executeTransition(
        from fromImage: CIImage,
        to toImage: CIImage,
        kernelName: String = "metal_transition_cross_warp",
        customSource: String? = nil,
        progress: Double,
        warpStrength: Double = 48.0,
        parameters: [Float] = [],
        canvasSize: CGSize
    ) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let clampedProgress = Float(max(0.0, min(1.0, progress)))
        var slots = [Float](repeating: 0, count: 8)
        if parameters.isEmpty {
            slots[0] = Float(warpStrength)
        } else {
            for (idx, val) in parameters.prefix(8).enumerated() {
                slots[idx] = val
            }
        }
        let uniforms = MetalEffectUniforms(
            time: clampedProgress, progress: clampedProgress, intensity: 1.0, speed: 1.0,
            width: Float(canvasSize.width), height: Float(canvasSize.height),
            p0: slots[0], p1: slots[1], p2: slots[2], p3: slots[3],
            p4: slots[4], p5: slots[5], p6: slots[6], p7: slots[7]
        )
        return MetalComputeRuntimeEngine.shared.dispatchTransition(
            kernelName: kernelName, customSource: customSource,
            from: fromImage, to: toImage, uniforms: uniforms, canvasRect: canvasRect
        )
    }

    /// Giải mã biểu thức tham số động (hỗ trợ phép cộng `+` và phép nhân `*`, ví dụ: `"$param.rgbOffset * $intensity + 2.0"`).
    public func evaluateExpression(
        _ expr: String,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double
    ) -> Double {
        let sumTerms = expr.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !sumTerms.isEmpty else { return 0.0 }
        var total = 0.0
        for term in sumTerms {
            let factors = term.split(separator: "*").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !factors.isEmpty else { continue }
            var product = 1.0
            for token in factors {
                product *= resolveSingleToken(token, config: config, progress: progress, localTime: localTime)
            }
            total += product
        }
        return total
    }

    private func resolveSingleToken(
        _ token: String,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double
    ) -> Double {
        if let literal = Double(token) { return literal }
        switch token {
        case "$progress": return progress
        case "$time": return localTime
        case "$intensity": return config.intensity
        case "$speed": return config.speed
        default:
            if token.hasPrefix("$param.") {
                let paramID = String(token.dropFirst("$param.".count))
                return config.value(forParameter: paramID)
            }
            return 0.0
        }
    }

    private func applyStep(
        _ step: CreativeFilterStep,
        to image: CIImage,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double,
        canvasRect: CGRect
    ) -> CIImage {
        if let customSource = step.kernelSource, !customSource.isEmpty {
            return applyCustomMetalKernel(
                source: customSource, step: step, to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect
            )
        }
        if let explicitKernel = step.metalKernelName, !explicitKernel.isEmpty {
            return applyCustomMetalKernel(
                source: nil, step: step, to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect
            )
        }
        if let metalResult = applyNamedMetalStep(
            step, to: image, config: config,
            progress: progress, localTime: localTime, canvasRect: canvasRect
        ) {
            return metalResult
        }
        return applyCoreImageFilter(
            step: step, to: image, config: config,
            progress: progress, localTime: localTime, canvasRect: canvasRect
        )
    }

    private func applyNamedMetalStep(
        _ step: CreativeFilterStep,
        to image: CIImage,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double,
        canvasRect: CGRect
    ) -> CIImage? {
        switch step.filterName {
        case "RGBSplit":
            let offset = evalParam("offset", default: "12.0", step: step, config: config, progress: progress, localTime: localTime)
            let freq = evalParam("frequency", default: "4.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_cyber_glitch", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(offset), p1: Float(freq)
            )
        case "VHSRetro":
            let scanline = evalParam("scanlineStrength", default: "0.45", step: step, config: config, progress: progress, localTime: localTime)
            let bleed = evalParam("colorBleed", default: "8.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_vhs_retro", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(scanline), p1: Float(bleed)
            )
        case "ThermalVision":
            let sens = evalParam("thermalSensitivity", default: "1.2", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_thermal_vision", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(sens)
            )
        default:
            return applySecondaryMetalStep(
                step, to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect
            )
        }
    }

    private func applySecondaryMetalStep(
        _ step: CreativeFilterStep,
        to image: CIImage,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double,
        canvasRect: CGRect
    ) -> CIImage? {
        switch step.filterName {
        case "CIComicEffect", "MetalHalftone":
            let blend = evalParam("comicBlend", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            guard blend > 0.01 else { return image }
            return dispatchBuiltInMetal(
                kernelName: "metal_halftone_dots", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(blend)
            )
        case "MetalPixelArcade":
            let scale = evalParam("pixelScale", default: "16.0", step: step, config: config, progress: progress, localTime: localTime)
            let levels = evalParam("colorLevels", default: "6.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_pixel_arcade", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(scale), p1: Float(levels)
            )
        case "MetalShockwave":
            let amp = evalParam("amplitude", default: "28.0", step: step, config: config, progress: progress, localTime: localTime)
            let band = evalParam("bandWidth", default: "0.14", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_shockwave_ripple", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(amp), p1: Float(band)
            )
        default:
            return nil
        }
    }

    private func evalParam(
        _ key: String, default fallback: String, step: CreativeFilterStep,
        config: EffectConfiguration, progress: Double, localTime: Double
    ) -> Double {
        evaluateExpression(step.parameterBindings[key] ?? fallback, config: config, progress: progress, localTime: localTime)
    }

    private func dispatchBuiltInMetal(
        kernelName: String, to image: CIImage, config: EffectConfiguration,
        progress: Double, localTime: Double, canvasRect: CGRect,
        p0: Float = 0, p1: Float = 0, p2: Float = 0, p3: Float = 0
    ) -> CIImage {
        let uniforms = MetalEffectUniforms(
            time: Float(localTime), progress: Float(progress),
            intensity: Float(config.intensity), speed: Float(config.speed),
            width: Float(canvasRect.width), height: Float(canvasRect.height),
            p0: p0, p1: p1, p2: p2, p3: p3
        )
        return MetalComputeRuntimeEngine.shared.dispatchEffect(
            kernelName: kernelName, on: image, uniforms: uniforms, canvasRect: canvasRect
        )
    }

    private func applyCustomMetalKernel(
        source: String?, step: CreativeFilterStep, to image: CIImage,
        config: EffectConfiguration, progress: Double, localTime: Double, canvasRect: CGRect
    ) -> CIImage {
        let sortedKeys = step.parameterBindings.keys.sorted()
        var slots = [Float](repeating: 0, count: 8)
        for (idx, key) in sortedKeys.prefix(8).enumerated() {
            if let expr = step.parameterBindings[key] {
                slots[idx] = Float(evaluateExpression(expr, config: config, progress: progress, localTime: localTime))
            }
        }
        let uniforms = MetalEffectUniforms(
            time: Float(localTime), progress: Float(progress),
            intensity: Float(config.intensity), speed: Float(config.speed),
            width: Float(canvasRect.width), height: Float(canvasRect.height),
            p0: slots[0], p1: slots[1], p2: slots[2], p3: slots[3],
            p4: slots[4], p5: slots[5], p6: slots[6], p7: slots[7]
        )
        let kernelName = step.metalKernelName ?? (step.filterName.isEmpty ? "custom_effect_kernel" : step.filterName)
        return MetalComputeRuntimeEngine.shared.dispatchEffect(
            kernelName: kernelName, customSource: source, on: image, uniforms: uniforms, canvasRect: canvasRect
        )
    }

    private func applyCoreImageFilter(
        step: CreativeFilterStep, to image: CIImage, config: EffectConfiguration,
        progress: Double, localTime: Double, canvasRect: CGRect
    ) -> CIImage {
        var params: [String: Any] = [:]
        for (key, expr) in step.parameterBindings {
            params[key] = evaluateExpression(expr, config: config, progress: progress, localTime: localTime)
        }
        if step.filterName == "CIPixellate" || step.filterName == "CITwirlDistortion" || step.filterName == "CIKaleidoscope" {
            params[kCIInputCenterKey] = CIVector(x: canvasRect.midX, y: canvasRect.midY)
        }
        return image.clampedToExtent().applyingFilter(step.filterName, parameters: params).cropped(to: canvasRect)
    }
}

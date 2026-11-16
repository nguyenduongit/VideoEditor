import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Mở rộng `DynamicShaderRuntimeEngine` phân phối các bước lọc Metal Compute thuộc 11 danh mục hiệu ứng:
/// Mưa/Tuyết, Bụi & Xước phim, HUD Scanlines, Light Leak, Duotone, Rung máy quay & Mini-Zoom,
/// và nhóm hiệu ứng thiên nhiên đặc thù: Lá rơi, Cánh hoa, Bụi bay, Đom đóm, Than hồng, Bong bóng.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension DynamicShaderRuntimeEngine {

    func applyCreativeMetalStep(
        _ step: CreativeFilterStep,
        to image: CIImage,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double,
        canvasRect: CGRect
    ) -> CIImage? {
        switch step.filterName {
        case "RainSnow", "MetalRainSnow":
            let mode = evalParam("mode", default: "0.0", step: step, config: config, progress: progress, localTime: localTime)
            let density = evalParam("density", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            let speed = evalParam("speed", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_rain_snow", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(mode), p1: Float(density), p2: Float(speed)
            )

        case "FilmDustScratch", "MetalFilmDust":
            let scratch = evalParam("scratchIntensity", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            let dust = evalParam("dustDensity", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            let jitter = evalParam("jitterAmp", default: "2.5", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_film_dust_scratch", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(scratch), p1: Float(dust), p2: Float(jitter)
            )

        case "HUDScanlines", "MetalHUD":
            let scan = evalParam("scanlineStrength", default: "0.45", step: step, config: config, progress: progress, localTime: localTime)
            let spacing = evalParam("gridSpacing", default: "48.0", step: step, config: config, progress: progress, localTime: localTime)
            let crosshair = evalParam("crosshair", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_hud_grid_scanlines", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(scan), p1: Float(spacing), p2: Float(crosshair)
            )

        case "LightLeak", "MetalLightLeak":
            let flare = evalParam("flareIntensity", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_light_leak_flare", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(flare)
            )

        case "Duotone", "MetalDuotone":
            let mode = evalParam("mode", default: "0.0", step: step, config: config, progress: progress, localTime: localTime)
            let blend = evalParam("blend", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_duotone", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(mode), p1: Float(blend)
            )

        case "CameraShake", "MetalCameraShake":
            let shake = evalParam("shakeIntensity", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
            let freq = evalParam("frequency", default: "16.0", step: step, config: config, progress: progress, localTime: localTime)
            let pulse = config.isBeatSynced ? EffectEngine.calculateBeatPulse(localTime: localTime, speed: config.speed) : 0.0
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_camera_shake", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(shake), p1: Float(freq), p2: Float(pulse)
            )

        default:
            return applyNatureMetalStep(
                step, to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect
            )
        }
    }

    func applyNatureMetalStep(
        _ step: CreativeFilterStep,
        to image: CIImage,
        config: EffectConfiguration,
        progress: Double,
        localTime: Double,
        canvasRect: CGRect
    ) -> CIImage? {
        let density = evalParam("density", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)
        let speed = evalParam("speed", default: "1.0", step: step, config: config, progress: progress, localTime: localTime)

        switch step.filterName {
        case "FallingLeaves", "MetalLeaves":
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_falling_leaves", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(density), p1: Float(speed)
            )
        case "Petals", "MetalPetals":
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_petals", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(density), p1: Float(speed)
            )
        case "FloatingDust", "MetalDust":
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_floating_dust", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(density), p1: Float(speed)
            )
        case "Fireflies", "MetalFireflies":
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_fireflies", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(density), p1: Float(speed)
            )
        case "Embers", "Sparks", "MetalEmbers":
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_embers_sparks", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(density), p1: Float(speed)
            )
        case "Bubbles", "MetalBubbles":
            return dispatchBuiltInMetal(
                kernelName: "metal_effect_floating_bubbles", to: image, config: config,
                progress: progress, localTime: localTime, canvasRect: canvasRect,
                p0: Float(density), p1: Float(speed)
            )
        default:
            return nil
        }
    }
}

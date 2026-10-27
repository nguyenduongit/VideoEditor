import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán 19 hiệu ứng biến mất (Out Animation) chuyên nghiệp
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R2.3 (thuần logic, không UI).
public enum TextOutAnimationEvaluator {

    public static func apply(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        outType: TextOutAnimationType,
        progress: Double,
        easedExit: Double,
        canvasSize: CGSize,
        blur: inout Double,
        pixelate: inout Double,
        rgbSplit: inout Double
    ) {
        guard outType != .none else { return }

        switch outType.category {
        case .fadeSlide:
            applyFadeSlide(
                config: &config, overlay: &overlay, outType: outType,
                progress: progress, easedExit: easedExit, canvasSize: canvasSize, blur: &blur
            )
        case .dissolveDrop:
            applyDissolveDrop(
                config: &config, overlay: &overlay, outType: outType,
                progress: progress, easedExit: easedExit, canvasSize: canvasSize,
                blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit
            )
        case .spinFlip:
            applySpinFlip(
                config: &config, overlay: &overlay, outType: outType,
                progress: progress, easedExit: easedExit, canvasSize: canvasSize
            )
        case .retroDigital:
            applyRetroDigital(
                config: &config, overlay: &overlay, outType: outType,
                progress: progress, easedExit: easedExit, rgbSplit: &rgbSplit
            )
        case .all:
            break
        }
        config.opacity *= progress
    }

    // MARK: - 1. Fade & Slide Out

    private static func applyFadeSlide(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        outType: TextOutAnimationType, progress: Double, easedExit: Double,
        canvasSize: CGSize, blur: inout Double
    ) {
        switch outType {
        case .fadeOut:
            break
        case .zoomOut:
            config.scale *= max(0.01, progress)
        case .zoomInOut:
            config.scale *= (1.0 + easedExit * 2.2)
            blur = max(blur, easedExit * 14.0)
        case .slideUp:
            config.positionY -= Double(easedExit * (canvasSize.height * 0.35))
        case .slideDown:
            config.positionY += Double(easedExit * (canvasSize.height * 0.35))
        case .slideLeft:
            config.positionX -= Double(easedExit * (canvasSize.width * 0.35))
        case .slideRight:
            config.positionX += Double(easedExit * (canvasSize.width * 0.35))
        default:
            break
        }
    }

    // MARK: - 2. Dissolve, Drop & Shrink

    private static func applyDissolveDrop(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        outType: TextOutAnimationType, progress: Double, easedExit: Double,
        canvasSize: CGSize, blur: inout Double, pixelate: inout Double, rgbSplit: inout Double
    ) {
        switch outType {
        case .dissolve:
            pixelate = max(pixelate, easedExit * 28.0)
            blur = max(blur, easedExit * 12.0)
        case .dropOut:
            config.positionY += Double(easedExit * (canvasSize.height * 0.6))
            config.rotation += Double(easedExit * 16.0)
        case .shrink:
            config.scale *= max(0.01, pow(progress, 2.0))
        case .vaporize:
            config.positionY -= Double(easedExit * 35.0)
            blur = max(blur, easedExit * 18.0)
        case .shatter:
            overlay.glitchSliceIntensity = max(overlay.glitchSliceIntensity, easedExit * 0.95)
            rgbSplit = max(rgbSplit, easedExit * 16.0)
            config.positionX += cos(easedExit * 35.0) * 15.0
        default:
            break
        }
    }

    // MARK: - 3. Spin, Flip & Close

    private static func applySpinFlip(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        outType: TextOutAnimationType, progress: Double, easedExit: Double, canvasSize: CGSize
    ) {
        switch outType {
        case .spinOut:
            config.rotation += easedExit * 360.0
            config.scale *= max(0.01, progress)
        case .rollOut:
            config.positionX += Double(easedExit * (canvasSize.width * 0.65))
            config.rotation += easedExit * 360.0
            config.scale *= max(0.01, progress)
        case .flipOut:
            overlay.perspectiveX = easedExit * 0.85
            overlay.scaleY *= max(0.05, progress)
        case .blinds:
            overlay.scaleY *= max(0.05, progress)
            overlay.skewX += easedExit * 0.25
        default:
            break
        }
    }

    // MARK: - 4. Retro & Digital

    private static func applyRetroDigital(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        outType: TextOutAnimationType, progress: Double, easedExit: Double, rgbSplit: inout Double
    ) {
        switch outType {
        case .tvOff:
            // Thu hẹp thành 1 vệt ngang rồi tắt hẳn
            if progress > 0.4 {
                let pY = (progress - 0.4) / 0.6
                overlay.scaleY *= max(0.05, pow(pY, 2.0))
            } else {
                overlay.scaleY = 0.05
                let pX = progress / 0.4
                overlay.scaleX *= max(0.02, pX)
            }
        case .glitchOut:
            rgbSplit = max(rgbSplit, easedExit * 18.0)
            overlay.glitchSliceIntensity = easedExit * 0.9
            config.positionX += sin(easedExit * 40.0) * 12.0
        case .scanOut:
            let len = config.content.count
            let count = max(0, min(len, Int(floor(Double(len) * progress))))
            config.content = String(config.content.prefix(count))
            overlay.lightSweepPhase = 1.0 - progress
        default:
            break
        }
    }
}

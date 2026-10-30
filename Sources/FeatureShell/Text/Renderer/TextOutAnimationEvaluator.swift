import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán 5 hoạt ảnh Biến mất (Out Animation) tinh tuyển chuẩn CapCut Pro
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
        rgbSplit: inout Double
    ) {
        guard outType != .none else { return }
        // exitProgress: 0.0 at outStart -> 1.0 at end of clip
        let exitProgress = min(1.0, max(0.0, 1.0 - progress))

        switch outType {
        case .none:
            break
        case .fadeOut:
            applyFadeOut(config: &config, exitProgress: exitProgress)
        case .zoomOut:
            applyZoomOut(config: &config, overlay: &overlay, exitProgress: exitProgress)
        case .dropDown:
            applyDropDown(config: &config, overlay: &overlay, exitProgress: exitProgress, canvasSize: canvasSize)
        case .whipOut:
            applyWhipOut(config: &config, overlay: &overlay, exitProgress: exitProgress, canvasSize: canvasSize)
        case .tvOff:
            applyTVOff(config: &config, overlay: &overlay, exitProgress: exitProgress)
        }
    }

    // MARK: - 1. Fade Out (Mờ dần êm dịu)
    private static func applyFadeOut(config: inout TextConfiguration, exitProgress: Double) {
        let rem = 1.0 - exitProgress
        // Smooth Hermite cubic interpolation for silky fade-out
        let alpha = rem * rem * (3.0 - 2.0 * rem)
        config.opacity *= alpha
    }

    // MARK: - 2. Zoom Out (Thu nhỏ lùi xa)
    private static func applyZoomOut(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        exitProgress: Double
    ) {
        config.opacity *= max(0.0, 1.0 - exitProgress * 1.25)
        let scaleP = 1.0 - 0.35 * pow(exitProgress, 1.8)
        overlay.scaleX *= scaleP
        overlay.scaleY *= scaleP
    }

    // MARK: - 3. Drop Down (Rơi tự do - Chuẩn CapCut out-1)
    private static func applyDropDown(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        exitProgress: Double,
        canvasSize: CGSize
    ) {
        let travelY = min(260.0, max(120.0, Double(canvasSize.height) * 0.35))
        // Gravitational acceleration (t^2.2) falling downward
        let fallProgress = pow(exitProgress, 2.2)
        config.positionY += travelY * fallProgress

        if exitProgress > 0.35 {
            let fadeP = (exitProgress - 0.35) / 0.65
            config.opacity *= max(0.0, 1.0 - fadeP)
        }
        overlay.motionBlurRadius = max(overlay.motionBlurRadius, min(12.0, exitProgress * 14.0))
    }

    // MARK: - 4. Whip Out (Trượt vút phải lấy đà - Chuẩn CapCut out-2)
    private static func applyWhipOut(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        exitProgress: Double,
        canvasSize: CGSize
    ) {
        let travelX = min(400.0, max(200.0, Double(canvasSize.width) * 0.45))
        let xOffset: Double
        if exitProgress < 0.20 {
            let t = exitProgress / 0.20
            xOffset = -0.06 * sin(t * Double.pi) * travelX
        } else {
            let t = (exitProgress - 0.20) / 0.80
            xOffset = pow(t, 2.6) * travelX
        }
        config.positionX += xOffset

        if exitProgress > 0.40 {
            let fadeP = (exitProgress - 0.40) / 0.60
            config.opacity *= max(0.0, 1.0 - fadeP)
        }
        let speed = exitProgress > 0.20 ? (exitProgress - 0.20) / 0.80 : 0.0
        overlay.motionBlurRadius = max(overlay.motionBlurRadius, min(16.0, speed * 18.0))
    }

    // MARK: - 5. TV Off (Tắt màn hình CRT)
    private static func applyTVOff(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        exitProgress: Double
    ) {
        if exitProgress < 0.60 {
            let t = exitProgress / 0.60
            overlay.scaleY *= max(0.04, 1.0 - pow(t, 2.0))
        } else {
            overlay.scaleY = 0.04
            let t = (exitProgress - 0.60) / 0.40
            overlay.scaleX *= max(0.0, 1.0 - t)
            config.opacity *= max(0.0, 1.0 - t * 2.0)
        }
    }
}

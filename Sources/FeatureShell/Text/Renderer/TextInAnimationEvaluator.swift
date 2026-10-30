import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán 6 hoạt ảnh Xuất hiện (In Animation) tinh tuyển chuẩn CapCut Pro
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R2.3 (thuần logic, không UI).
public enum TextInAnimationEvaluator {

    public static func apply(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        inType: TextInAnimationType,
        progress: Double,
        eased: Double,
        canvasSize: CGSize,
        blur: inout Double,
        pixelate: inout Double,
        rgbSplit: inout Double,
        isCursorVisible: Bool
    ) {
        guard inType != .none else { return }

        switch inType {
        case .none:
            break
        case .fadeIn:
            applyFadeIn(config: &config, progress: progress)
        case .zoomIn:
            applyZoomIn(config: &config, overlay: &overlay, progress: progress, eased: eased)
        case .slideUp:
            applySlideUp(config: &config, overlay: &overlay, progress: progress, canvasSize: canvasSize)
        case .whipRight:
            applyWhipRight(config: &config, overlay: &overlay, progress: progress, canvasSize: canvasSize, blur: &blur)
        case .kineticDrop:
            applyKineticDrop(config: &config, overlay: &overlay, progress: progress, canvasSize: canvasSize)
        case .typewriter:
            applyTypewriter(config: &config, progress: progress, isCursorVisible: isCursorVisible)
        }
    }

    // MARK: - 1. Fade In (Mờ dần kinh điển)
    private static func applyFadeIn(config: inout TextConfiguration, progress: Double) {
        let p = min(1.0, max(0.0, progress))
        // Smooth Hermite cubic interpolation for silky fade
        let alpha = p * p * (3.0 - 2.0 * p)
        config.opacity *= alpha
    }

    // MARK: - 2. Zoom In (Phóng to êm ái - Chuẩn CapCut Sample 1)
    private static func applyZoomIn(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        progress: Double,
        eased: Double
    ) {
        let p = min(1.0, max(0.0, progress))
        let alpha = min(1.0, p * 1.6)
        config.opacity *= alpha

        // CapCut curve: Starts at 0.72x, smoothly accelerates and docks into 1.0x with subtle spring
        let scaleP = 0.72 + 0.28 * sin(p * Double.pi / 2.0)
        overlay.scaleX *= scaleP
        overlay.scaleY *= scaleP
    }

    // MARK: - 3. Slide Up (Trượt lên đàn hồi - Chuẩn CapCut in-2)
    private static func applySlideUp(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        progress: Double,
        canvasSize: CGSize
    ) {
        let p = min(1.0, max(0.0, progress))
        let alpha = min(1.0, p * 2.2)
        config.opacity *= alpha

        let travelY = min(180.0, max(70.0, Double(canvasSize.height) * 0.25))
        if p >= 1.0 {
            // Settled at rest position
            return
        }
        // Anticipation (first 10%) then Spring Overshoot at 75% then settle
        let springCurve: Double
        if p < 0.12 {
            let t = p / 0.12
            springCurve = -0.04 * sin(t * Double.pi)
        } else {
            let t = (p - 0.12) / 0.88
            // Damped harmonic oscillation: overshoots slightly by 3.5%
            springCurve = 1.0 - exp(-4.5 * t) * cos(3.8 * t)
        }
        config.positionY += travelY * (1.0 - springCurve)
    }

    // MARK: - 4. Whip Right (Trượt vút phải lấy đà - Chuẩn CapCut in-3)
    private static func applyWhipRight(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        progress: Double,
        canvasSize: CGSize,
        blur: inout Double
    ) {
        let p = min(1.0, max(0.0, progress))
        let alpha = min(1.0, p * 2.5)
        config.opacity *= alpha

        let travelX = min(380.0, max(180.0, Double(canvasSize.width) * 0.40))
        if p >= 1.0 { return }

        // CapCut Whip motion: Quick slight back anticipation, then super-fast swoop across
        let xProgress: Double
        if p < 0.15 {
            let t = p / 0.15
            xProgress = -0.05 * sin(t * Double.pi)
        } else {
            let t = (p - 0.15) / 0.85
            xProgress = 1.0 - pow(1.0 - t, 3.5)
        }
        let currentOffset = travelX * (1.0 - xProgress)
        config.positionX -= currentOffset

        // Velocity-based directional motion blur during the peak swoop
        let velocity = abs(3.5 * pow(1.0 - min(1.0, p), 2.5))
        overlay.motionBlurRadius = max(overlay.motionBlurRadius, min(14.0, velocity * 2.8))
    }

    // MARK: - 5. Kinetic Drop (Rơi nảy từng chữ sống động)
    private static func applyKineticDrop(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        progress: Double,
        canvasSize: CGSize
    ) {
        let p = min(1.0, max(0.0, progress))
        config.opacity *= min(1.0, p * 3.0)

        let travelY = min(220.0, max(90.0, Double(canvasSize.height) * 0.30))
        if p >= 1.0 { return }

        // Classic physics drop with 2 elastic bounces at impact
        let dropP: Double
        if p < 0.60 {
            let t = p / 0.60
            dropP = t * t // Gravitational acceleration
        } else if p < 0.82 {
            let t = (p - 0.60) / 0.22
            dropP = 1.0 - 0.12 * sin(t * Double.pi) // First bounce rebound
        } else {
            let t = (p - 0.82) / 0.18
            dropP = 1.0 - 0.03 * sin(t * Double.pi) // Subtle settle bounce
        }
        config.positionY -= travelY * (1.0 - dropP)
    }

    // MARK: - 6. Typewriter (Máy đánh chữ mượt mà)
    private static func applyTypewriter(
        config: inout TextConfiguration,
        progress: Double,
        isCursorVisible: Bool
    ) {
        let text = config.content
        guard !text.isEmpty else { return }

        let p = min(1.0, max(0.0, progress))
        let totalChars = text.count
        let visibleCount = Int(floor(Double(totalChars) * p))
        let prefixText = String(text.prefix(max(0, min(totalChars, visibleCount))))

        if isCursorVisible && p < 1.0 {
            config.content = prefixText + "|"
        } else {
            config.content = prefixText
        }
    }
}

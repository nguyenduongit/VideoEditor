import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán các hoạt ảnh Vòng lặp (Loop Animation) tinh tuyển chuẩn CapCut Pro
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R2.3 (thuần logic, không UI).
public enum TextLoopAnimationEvaluator {

    public static func apply(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        loopType: TextLoopAnimationType,
        phase: Double,
        t: Double,
        loopSpeed: Double,
        blend: Double,
        hue: inout Double
    ) {
        guard loopType != .none, blend > 0.001 else { return }

        switch loopType {
        case .none:
            break
        case .pulse:
            applyPulse(config: &config, phase: phase, blend: blend)
        case .sway:
            applySway(config: &config, phase: phase, blend: blend)
        case .wobble:
            applyWobble(overlay: &overlay, phase: phase, blend: blend)
        case .bounce:
            applyBounce(config: &config, phase: phase, blend: blend)
        case .spin:
            applySpin(config: &config, phase: phase, blend: blend)
        case .float:
            applyFloat(config: &config, phase: phase, blend: blend)
        case .shake:
            applyShake(config: &config, overlay: &overlay, phase: phase, blend: blend)
        case .breathe:
            applyBreathe(config: &config, phase: phase, blend: blend)
        case .wave:
            applyWave(config: &config, phase: phase, blend: blend)
        case .flicker:
            applyFlicker(config: &config, phase: phase, blend: blend)
        }
    }

    // MARK: - 1. Pulse (Nhịp tim đập 2 nhịp nhanh rồi nghỉ)
    private static func applyPulse(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let beat = pow(sin(phase), 4.0) + 0.45 * pow(sin(phase + 0.35), 4.0)
        config.scale *= (1.0 + beat * 0.14 * blend)
    }

    // MARK: - 2. Sway (Đung đưa qua lại hình con lắc)
    private static func applySway(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let angle = sin(phase) * 12.0 * blend
        config.rotation += angle
    }

    // MARK: - 3. Wobble (Lắc lư biến dạng co dãn đa chiều)
    private static func applyWobble(
        overlay: inout TextTransformOverlay,
        phase: Double,
        blend: Double
    ) {
        let wobbleX = sin(phase) * 0.12 * blend
        let wobbleY = -sin(phase) * 0.12 * blend
        overlay.scaleX *= (1.0 + wobbleX)
        overlay.scaleY *= (1.0 + wobbleY)
    }

    // MARK: - 4. Bounce (Nhún nhảy nhịp nhàng theo phương đứng)
    private static func applyBounce(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let bounceY = -abs(sin(phase)) * 24.0 * blend
        config.positionY += bounceY
    }

    // MARK: - 5. Spin (Xoay tròn 360 độ tuần hoàn vô tận)
    private static func applySpin(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let fraction = (phase / (2.0 * .pi)).truncatingRemainder(dividingBy: 1.0)
        let normalizedFraction = fraction < 0 ? fraction + 1.0 : fraction
        config.rotation += normalizedFraction * 360.0 * blend
    }

    // MARK: - 6. Float (Bồng bềnh lơ lửng trong không gian)
    private static func applyFloat(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let floatY = sin(phase) * 16.0 * blend
        let floatX = cos(phase) * 8.0 * blend
        config.positionY += floatY
        config.positionX += floatX
    }

    // MARK: - 7. Shake (Rung lắc sôi động)
    private static func applyShake(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        phase: Double,
        blend: Double
    ) {
        let angle = sin(phase * 4.0) * 2.5 * blend
        let offsetX = cos(phase * 4.0) * 4.0 * blend
        config.rotation += angle
        config.positionX += offsetX
    }

    // MARK: - 8. Breathe (Thở nhẹ nhàng - co dãn êm dịu)
    private static func applyBreathe(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let breath = sin(phase) * 0.06 * blend
        config.scale *= (1.0 + breath)
    }

    // MARK: - 9. Wave (Lượn sóng dập dềnh)
    private static func applyWave(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let waveY = sin(phase * 1.2) * 10.0 * blend
        config.positionY += waveY
        config.rotation += sin(phase * 0.9) * 1.5 * blend
    }

    // MARK: - 10. Flicker (Chớp sáng Neon Retro)
    private static func applyFlicker(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let noise = sin(phase * 8.0) * cos(phase * 3.5)
        let flicker = noise > 0.4 ? 0.45 : 1.0
        let targetOpacity = 0.65 + 0.35 * flicker
        config.opacity *= (1.0 - blend + targetOpacity * blend)
    }
}

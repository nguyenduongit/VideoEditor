import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán 5 hoạt ảnh Vòng lặp (Loop Animation) tinh tuyển chuẩn CapCut Pro
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
        case .breathe:
            applyBreathe(config: &config, phase: phase, blend: blend)
        case .wave:
            applyWave(config: &config, phase: phase, blend: blend)
        case .pulse:
            applyPulse(config: &config, phase: phase, blend: blend)
        case .shake:
            applyShake(config: &config, overlay: &overlay, phase: phase, blend: blend)
        case .flicker:
            applyFlicker(config: &config, phase: phase, blend: blend)
        }
    }

    // MARK: - 1. Breathe (Thở nhẹ nhàng - co dãn êm dịu)
    private static func applyBreathe(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        // Slow silky sinusoidal breathing between 0.96x and 1.04x
        let breath = sin(phase * 0.8) * 0.045 * blend
        config.scale *= (1.0 + breath)
    }

    // MARK: - 2. Wave (Lượn sóng dập dềnh)
    private static func applyWave(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let waveY = sin(phase * 1.2) * 10.0 * blend
        config.positionY += waveY
        config.rotation += sin(phase * 0.9) * 1.5 * blend
    }

    // MARK: - 3. Pulse (Nhịp tim đập 2 nhịp nhanh rồi nghỉ)
    private static func applyPulse(
        config: inout TextConfiguration,
        phase: Double,
        blend: Double
    ) {
        let beat = pow(sin(phase), 4.0) + 0.45 * pow(sin(phase + 0.35), 4.0)
        config.scale *= (1.0 + beat * 0.14 * blend)
    }

    // MARK: - 4. Shake (Rung lắc sôi động)
    private static func applyShake(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        phase: Double,
        blend: Double
    ) {
        let angle = sin(phase * 4.2) * 2.2 * blend
        let offsetX = cos(phase * 5.0) * 3.5 * blend
        config.rotation += angle
        config.positionX += offsetX
    }

    // MARK: - 5. Flicker (Chớp sáng Neon Retro)
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

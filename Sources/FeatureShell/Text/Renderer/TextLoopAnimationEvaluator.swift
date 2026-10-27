import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán 14 hiệu ứng vòng lặp (Loop Animation) chuyên nghiệp
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

        switch loopType.category {
        case .dynamicMotion:
            applyDynamicMotion(
                config: &config, overlay: &overlay, loopType: loopType,
                phase: phase, blend: blend
            )
        case .lightGlow:
            applyLightGlow(
                config: &config, overlay: &overlay, loopType: loopType,
                phase: phase, t: t, loopSpeed: loopSpeed, blend: blend, hue: &hue
            )
        case .distortion:
            applyDistortion(
                config: &config, overlay: &overlay, loopType: loopType,
                phase: phase, t: t, loopSpeed: loopSpeed, blend: blend
            )
        case .all:
            break
        }
    }

    // MARK: - 1. Dynamic Motion

    private static func applyDynamicMotion(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        loopType: TextLoopAnimationType, phase: Double, blend: Double
    ) {
        switch loopType {
        case .pulse:
            let beat = pow(sin(phase), 4.0) + 0.45 * pow(sin(phase + 0.35), 4.0)
            config.scale *= (1.0 + beat * 0.14 * blend)
        case .breathe:
            let breath = sin(phase * 0.65) * 0.06 * blend
            config.scale *= (1.0 + breath)
        case .bounceLoop:
            let bounce = abs(sin(phase)) * 14.0 * blend
            config.positionY -= bounce
            let squash = (1.0 - abs(sin(phase))) * 0.09 * blend
            overlay.scaleX *= (1.0 + squash); overlay.scaleY *= (1.0 - squash)
        case .wobble:
            config.rotation += sin(phase * 1.5) * 4.5 * blend
            overlay.skewX += sin(phase * 1.5) * 0.08 * blend
        case .pendulumLoop:
            let s = sin(phase)
            config.rotation += s * 14.0 * blend
            overlay.perspectiveY += s * 0.35 * blend
        case .floating:
            config.positionY += sin(phase) * 9.0 * blend
            config.rotation += cos(phase * 0.7) * 2.0 * blend
        case .waveLoop:
            overlay.liquidWavePhase = phase
            let w = sin(phase) * 0.12 * blend
            overlay.scaleX *= (1.0 + w); overlay.scaleY *= (1.0 - w * 0.8)
        case .spinLoop:
            let deg = (phase * 180.0 / .pi).truncatingRemainder(dividingBy: 360.0)
            config.rotation += deg * blend
        default:
            break
        }
    }

    // MARK: - 2. Light & Glow

    private static func applyLightGlow(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        loopType: TextLoopAnimationType, phase: Double, t: Double,
        loopSpeed: Double, blend: Double, hue: inout Double
    ) {
        switch loopType {
        case .flash:
            let flashState = sin(phase * 3.0) > 0.1 ? 1.0 : 0.25
            config.opacity *= (1.0 - blend + flashState * blend)
        case .neonGlow:
            let flicker = (0.75 + 0.25 * abs(sin(phase * 2.4)))
            config.opacity *= (1.0 - blend + flicker * blend)
            config.scale *= (1.0 + sin(phase * 2.4) * 0.02 * blend)
        case .shine:
            overlay.lightSweepPhase = (t * loopSpeed * 0.65).truncatingRemainder(dividingBy: 1.0)
        case .rainbow:
            hue = (phase * blend).truncatingRemainder(dividingBy: 2.0 * .pi)
        default:
            break
        }
    }

    // MARK: - 3. Distortion

    private static func applyDistortion(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        loopType: TextLoopAnimationType, phase: Double, t: Double,
        loopSpeed: Double, blend: Double
    ) {
        switch loopType {
        case .glitchLoop:
            let tick = Int(t * loopSpeed * 8.0) % 8
            if tick == 2 {
                config.positionX += 6.0 * blend
                config.rotation += 1.5 * blend
                overlay.glitchSliceIntensity = 0.5 * blend
            } else if tick == 5 {
                config.positionX -= 5.0 * blend
                config.rotation -= 1.5 * blend
                overlay.glitchSliceIntensity = 0.4 * blend
            }
        case .ripple:
            let rippleX = sin(phase * 2.0) * 0.08 * blend
            let rippleY = cos(phase * 2.0) * 0.08 * blend
            overlay.scaleX *= (1.0 + rippleX)
            overlay.scaleY *= (1.0 + rippleY)
        default:
            break
        }
    }
}

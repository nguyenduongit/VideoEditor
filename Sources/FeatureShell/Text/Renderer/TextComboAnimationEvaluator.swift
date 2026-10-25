import Foundation
import CoreGraphics
import Domain

/// Bộ thông số biến đổi vật lý nâng cao (Squash & Stretch, Skew, 3D Perspective, Shader FX)
public struct TextTransformOverlay: Sendable, Equatable {
    public var scaleX: Double = 1.0
    public var scaleY: Double = 1.0
    public var skewX: Double = 0.0
    public var perspectiveX: Double = 0.0
    public var perspectiveY: Double = 0.0
    public var motionBlurRadius: Double = 0.0
    public var motionBlurAngle: Double = 0.0
    public var lightSweepPhase: Double = -1.0
    public var glitchSliceIntensity: Double = 0.0
    public var liquidWavePhase: Double = -1.0

    public init(
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        skewX: Double = 0.0,
        perspectiveX: Double = 0.0,
        perspectiveY: Double = 0.0,
        motionBlurRadius: Double = 0.0,
        motionBlurAngle: Double = 0.0,
        lightSweepPhase: Double = -1.0,
        glitchSliceIntensity: Double = 0.0,
        liquidWavePhase: Double = -1.0
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.skewX = skewX
        self.perspectiveX = perspectiveX
        self.perspectiveY = perspectiveY
        self.motionBlurRadius = motionBlurRadius
        self.motionBlurAngle = motionBlurAngle
        self.lightSweepPhase = lightSweepPhase
        self.glitchSliceIntensity = glitchSliceIntensity
        self.liquidWavePhase = liquidWavePhase
    }
}

/// Bộ tính toán hoạt ảnh kết hợp (Combo Animation) chạy đồng bộ suốt thời lượng clip.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public enum TextComboAnimationEvaluator: Sendable {
    public static func apply(
        config: inout TextConfiguration,
        comboType: TextComboAnimationType,
        t: Double,
        duration: Double,
        canvasSize: CGSize
    ) {
        var overlay = TextTransformOverlay()
        var rgbSplit: Double = 0.0
        applyPro(
            config: &config,
            overlay: &overlay,
            rgbSplit: &rgbSplit,
            comboType: comboType,
            t: t,
            duration: duration,
            canvasSize: canvasSize
        )
    }

    public static func applyPro(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        rgbSplit: inout Double,
        comboType: TextComboAnimationType,
        t: Double,
        duration: Double,
        canvasSize: CGSize
    ) {
        guard comboType != .none else { return }
        let progress = min(1.0, max(0.0, t / max(0.1, duration)))

        switch comboType {
        case .none:
            break
        case .karaokeBox, .karaokeGlow:
            applyKaraokePulse(config: &config, overlay: &overlay, t: t)
        case .elasticJelly:
            applyElasticJelly(config: &config, overlay: &overlay, t: t)
        case .flip3DSwing:
            applyFlip3DSwing(config: &config, overlay: &overlay, t: t)
        case .pendulum:
            applyPendulum(config: &config, overlay: &overlay, t: t)
        case .zoomShake:
            applyZoomShake(config: &config, overlay: &overlay, progress: progress, t: t)
        case .kineticBounce:
            applyKineticBounce(config: &config, overlay: &overlay, t: t)
        case .glitchPulse:
            applyGlitchPulse(config: &config, overlay: &overlay, rgbSplit: &rgbSplit, t: t)
        case .stopMotionJitter:
            applyStopMotionJitter(config: &config, overlay: &overlay, t: t)
        case .cyberScanline:
            applyCyberScanline(config: &config, overlay: &overlay, rgbSplit: &rgbSplit, t: t, progress: progress)
        }
    }

    private static func applyKaraokePulse(config: inout TextConfiguration, overlay: inout TextTransformOverlay, t: Double) {
        let beat = sin(t * 6.0) * 0.025
        config.scale *= (1.0 + beat)
        overlay.scaleX *= (1.0 + beat)
        overlay.scaleY *= (1.0 - beat * 0.5)
    }

    private static func applyElasticJelly(config: inout TextConfiguration, overlay: inout TextTransformOverlay, t: Double) {
        let wave = sin(t * 7.5) * 0.22
        overlay.scaleX *= (1.0 + wave)
        overlay.scaleY *= (1.0 - wave * 0.85)
        config.positionY += abs(cos(t * 7.5)) * 10.0
    }

    private static func applyFlip3DSwing(config: inout TextConfiguration, overlay: inout TextTransformOverlay, t: Double) {
        let swing = sin(t * 4.2)
        overlay.perspectiveX += swing * 0.55
        overlay.scaleY *= max(0.35, cos(swing * 0.85))
        config.rotation += swing * 4.5
        config.positionY += swing * 8.0
    }

    private static func applyPendulum(config: inout TextConfiguration, overlay: inout TextTransformOverlay, t: Double) {
        let angle = sin(t * 3.5) * 14.0 * exp(-t * 0.15)
        config.rotation += angle
        config.positionX += sin(t * 3.5) * 18.0
        overlay.skewX += sin(t * 3.5) * 0.08 * exp(-t * 0.15)
    }

    private static func applyZoomShake(config: inout TextConfiguration, overlay: inout TextTransformOverlay, progress: Double, t: Double) {
        let zoomPhase = sin(progress * .pi)
        config.scale *= (1.0 + zoomPhase * 0.25)
        let shake = sin(t * 28.0) * 4.0 * zoomPhase
        config.positionX += shake
        config.positionY += cos(t * 22.0) * 3.0 * zoomPhase
        overlay.motionBlurRadius = max(overlay.motionBlurRadius, abs(shake) * 1.5)
    }

    private static func applyKineticBounce(config: inout TextConfiguration, overlay: inout TextTransformOverlay, t: Double) {
        let phase = t * 5.0
        let bounce = abs(sin(phase))
        config.scale *= (0.92 + bounce * 0.2)
        config.positionY += bounce * 16.0
        // Squash khi chạm đáy (bounce gần 0), Stretch khi nảy lên đỉnh
        let squash = cos(phase * 2.0) * 0.12
        overlay.scaleX *= (1.0 + squash)
        overlay.scaleY *= (1.0 - squash * 0.8)
    }

    private static func applyGlitchPulse(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        rgbSplit: inout Double,
        t: Double
    ) {
        let tick = Int(t * 12.0) % 6
        if tick == 1 || tick == 4 {
            config.positionX += 7.0
            config.rotation += 2.0
            config.opacity *= 0.75
            overlay.glitchSliceIntensity = max(overlay.glitchSliceIntensity, 0.65)
            rgbSplit = max(rgbSplit, 6.0)
        } else if tick == 3 {
            config.positionX -= 6.0
            config.rotation -= 2.0
            config.opacity *= 0.85
            overlay.glitchSliceIntensity = max(overlay.glitchSliceIntensity, 0.45)
            rgbSplit = max(rgbSplit, 4.5)
        }
    }

    private static func applyStopMotionJitter(config: inout TextConfiguration, overlay: inout TextTransformOverlay, t: Double) {
        // Lượng tử hóa thời gian ở 8 FPS tạo hiệu ứng cắt dán thủ công (Ransom / Indie Cutout)
        let step = floor(t * 8.0)
        let dx = sin(step * 12.9898) * 4.5
        let dy = cos(step * 78.233) * 3.5
        let rot = sin(step * 37.719) * 3.8
        config.positionX += dx
        config.positionY += dy
        config.rotation += rot
        overlay.scaleX *= (1.0 + cos(step * 19.1) * 0.05)
        overlay.scaleY *= (1.0 - cos(step * 19.1) * 0.05)
    }

    private static func applyCyberScanline(
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        rgbSplit: inout Double,
        t: Double,
        progress: Double
    ) {
        overlay.lightSweepPhase = (t * 0.85).truncatingRemainder(dividingBy: 1.0)
        let pulse = sin(t * 16.0)
        if pulse > 0.75 {
            overlay.glitchSliceIntensity = max(overlay.glitchSliceIntensity, 0.4)
            rgbSplit = max(rgbSplit, 3.5)
            config.positionX += sin(progress * 40.0) * 3.0
        }
    }
}

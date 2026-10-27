import Foundation
import CoreGraphics
import Domain

/// Bộ đánh giá và tính toán 30 hiệu ứng xuất hiện (In Animation) chuyên nghiệp
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
        let invEased = 1.0 - eased

        switch inType.category {
        case .basicMotion:
            applyBasicMotion(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, eased: eased, invEased: invEased,
                canvasSize: canvasSize, blur: &blur
            )
        case .typewriterDrawing:
            applyTypewriterDrawing(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, isCursorVisible: isCursorVisible, blur: &blur
            )
        case .bounceSpring:
            applyBounceSpring(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, invEased: invEased, canvasSize: canvasSize
            )
        case .flipSpin:
            applyFlipSpin(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, eased: eased, invEased: invEased, canvasSize: canvasSize
            )
        case .glitchCinematic:
            applyGlitchCinematic(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, eased: eased, invEased: invEased,
                blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit
            )
        case .all:
            break
        }
        config.opacity *= progress
    }

    // MARK: - 1. Basic & Motion

    private static func applyBasicMotion(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, eased: Double,
        invEased: Double, canvasSize: CGSize, blur: inout Double
    ) {
        switch inType {
        case .fadeIn:
            break
        case .zoomIn:
            config.scale *= max(0.01, eased)
        case .zoomOutIn:
            config.scale *= (2.4 - 1.4 * eased)
            blur = max(blur, (1.0 - progress) * 8.0)
        case .slideUp:
            config.positionY += Double(invEased * (canvasSize.height * 0.35))
        case .slideDown:
            config.positionY -= Double(invEased * (canvasSize.height * 0.35))
        case .slideLeft:
            config.positionX += Double(invEased * (canvasSize.width * 0.35))
            overlay.skewX -= invEased * 0.22
        case .slideRight:
            config.positionX -= Double(invEased * (canvasSize.width * 0.35))
            overlay.skewX += invEased * 0.22
        case .moveIn:
            let smoothP = TextAnimationCurves.smoothEase(progress)
            config.positionX -= Double((1.0 - smoothP) * (canvasSize.width * 0.55))
            overlay.motionBlurRadius = (1.0 - smoothP) * 18.0
        case .wipe:
            let len = config.content.count
            let count = max(1, min(len, Int(ceil(Double(len) * progress))))
            config.content = String(config.content.prefix(count))
        default:
            break
        }
    }

    // MARK: - 2. Typewriter & Drawing

    private static func applyTypewriterDrawing(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, isCursorVisible: Bool, blur: inout Double
    ) {
        let len = config.content.count
        switch inType {
        case .typewriter1:
            let count = min(len, max(0, Int(Double(len) * progress)))
            var sub = String(config.content.prefix(count))
            if isCursorVisible && progress < 1.0 { sub.append("|") }
            config.content = sub
        case .typewriter2:
            let count = min(len, max(0, Int(Double(len) * progress)))
            config.content = String(config.content.prefix(count))
            let bounce = sin(progress * Double(len) * .pi).truncatingRemainder(dividingBy: 1.0)
            config.scale *= (1.0 + abs(bounce) * 0.06)
        case .handwriting:
            let count = max(1, min(len, Int(ceil(Double(len) * pow(progress, 1.2)))))
            config.content = String(config.content.prefix(count))
            overlay.skewX += sin(progress * 18.0) * (1.0 - progress) * 0.12
        case .inkSplash:
            config.scale *= (0.2 + 0.8 * TextAnimationCurves.springOvershoot(progress, tension: 1.8))
            blur = max(blur, (1.0 - progress) * 10.0)
        case .chalk:
            let count = max(1, min(len, Int(ceil(Double(len) * progress))))
            config.content = String(config.content.prefix(count))
            config.positionX += sin(progress * 60.0) * (1.0 - progress) * 2.5
        default:
            break
        }
    }

    // MARK: - 3. Bounce, Drop & Spring

    private static func applyBounceSpring(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, invEased: Double, canvasSize: CGSize
    ) {
        switch inType {
        case .drop:
            let bounceP = TextAnimationCurves.bounceEaseOut(progress)
            config.positionY -= Double((1.0 - bounceP) * (canvasSize.height * 0.55))
            let impact = TextAnimationCurves.impactSquash(progress: progress)
            overlay.scaleX *= impact.scaleX; overlay.scaleY *= impact.scaleY
        case .bounce:
            config.scale *= max(0.05, TextAnimationCurves.springOvershoot(progress, tension: 2.2))
            let jelly = TextAnimationCurves.jellySquashStretch(progress: progress, amplitude: 0.35, frequency: 4.5)
            overlay.scaleX *= jelly.scaleX; overlay.scaleY *= jelly.scaleY
        case .pendulum:
            config.rotation = sin(progress * .pi * 3.5) * (1.0 - progress) * 32.0
            config.scale *= (0.8 + 0.2 * progress)
        case .wobble:
            config.rotation = sin(progress * .pi * 5.0) * (1.0 - progress) * 16.0
            config.positionX += cos(progress * .pi * 5.0) * (1.0 - progress) * 12.0
        default:
            break
        }
    }

    // MARK: - 4. Flip & Spin

    private static func applyFlipSpin(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, eased: Double,
        invEased: Double, canvasSize: CGSize
    ) {
        switch inType {
        case .flipHorizontal:
            overlay.perspectiveY = invEased * 0.85
            overlay.scaleX *= max(0.08, cos(invEased * .pi * 0.5))
            config.scale *= max(0.01, eased)
        case .flipVertical:
            overlay.perspectiveX = invEased * 0.85
            overlay.scaleY *= max(0.08, cos(invEased * .pi * 0.5))
            config.scale *= max(0.01, eased)
        case .flip3D:
            overlay.perspectiveX = -invEased * 0.65
            overlay.perspectiveY = invEased * 0.65
            config.rotation += invEased * 35.0
            config.scale *= max(0.01, eased)
        case .spinIn:
            config.rotation += invEased * 360.0
            config.scale *= max(0.01, eased)
        case .rollIn:
            config.positionX -= Double(invEased * (canvasSize.width * 0.65))
            config.rotation -= invEased * 360.0
            config.scale *= max(0.01, eased)
        case .pageTurn:
            overlay.perspectiveY = -invEased * 0.92
            overlay.scaleX *= (0.15 + 0.85 * eased)
            config.positionX -= Double(invEased * 24.0)
        default:
            break
        }
    }

    // MARK: - 5. Glitch & Cinematic

    private static func applyGlitchCinematic(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, eased: Double,
        invEased: Double, blur: inout Double, pixelate: inout Double, rgbSplit: inout Double
    ) {
        switch inType {
        case .glitch:
            overlay.glitchSliceIntensity = (1.0 - progress) * 0.95
            rgbSplit = max(rgbSplit, (1.0 - progress) * 16.0)
            config.positionX += sin(progress * 50.0) * (1.0 - progress) * 15.0
        case .pixelate:
            pixelate = max(pixelate, (1.0 - progress) * 32.0)
        case .blurIn:
            blur = max(blur, (1.0 - progress) * 20.0)
            config.scale *= (0.9 + 0.1 * eased)
        case .lightStreak:
            overlay.lightSweepPhase = progress
            if progress < 0.65 {
                config.scale *= (1.0 + sin(progress * .pi / 0.65) * 0.12)
            }
        case .unfold:
            overlay.scaleY *= max(0.05, pow(progress, 1.8))
            overlay.scaleX *= max(0.1, eased)
        case .cascade:
            config.positionY += sin(progress * .pi * 2.5) * (1.0 - progress) * 28.0
            config.scale *= max(0.01, eased)
        default:
            break
        }
    }
}

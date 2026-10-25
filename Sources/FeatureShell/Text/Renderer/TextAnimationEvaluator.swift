import Foundation
import CoreGraphics
import Domain

/// Cung cấp logic tính toán biến đổi hoạt ảnh (In, Out, Loop, Combo) cho Text Clip dựa trên thời gian.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public struct TextAnimationEvaluator: Sendable {
    public struct EvaluationResult: Sendable {
        public let config: TextConfiguration
        public let blurRadius: Double
        public let hueAngle: Double
        public let pixelateScale: Double
        public let rgbSplitIntensity: Double
        public let overlay: TextTransformOverlay

        public init(
            config: TextConfiguration,
            blurRadius: Double = 0.0,
            hueAngle: Double = 0.0,
            pixelateScale: Double = 0.0,
            rgbSplitIntensity: Double = 0.0,
            overlay: TextTransformOverlay = TextTransformOverlay()
        ) {
            self.config = config
            self.blurRadius = blurRadius
            self.hueAngle = hueAngle
            self.pixelateScale = pixelateScale
            self.rgbSplitIntensity = rgbSplitIntensity
            self.overlay = overlay
        }
    }

    /// Tính toán cấu hình Text sau khi áp dụng hoạt ảnh tại mốc thời gian `localTime`.
    public static func evaluate(
        config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> EvaluationResult {
        guard !config.animation.isDefault else { return EvaluationResult(config: config) }

        var evaluated = config
        var blur: Double = 0.0
        var hue: Double = 0.0
        var pixelate: Double = 0.0
        var rgbSplit = config.animation.rgbSplitIntensity
        var overlay = TextTransformOverlay()
        let anim = config.animation
        let safeDur = max(0.1, duration)
        let t = max(0.0, min(safeDur, localTime))

        if anim.lightSweepIntensity > 0.01 {
            overlay.lightSweepPhase = (t * max(0.4, anim.loopSpeed) * 0.7).truncatingRemainder(dividingBy: 1.0)
        }
        if anim.inType != .none, t < anim.inDuration {
            let progress = min(1.0, max(0.0, t / max(0.05, anim.inDuration)))
            let eased = TextAnimationCurves.apply(progress: progress, easing: anim.motionEasing)
            applyInAnimation(
                config: &evaluated, overlay: &overlay, inType: anim.inType,
                progress: progress, eased: eased, canvasSize: canvasSize,
                blur: &blur, rgbSplit: &rgbSplit, isCursorVisible: anim.isTypewriterCursorVisible
            )
        }
        let outStart = max(0.0, safeDur - anim.outDuration)
        if anim.outType != .none, t > outStart {
            let progress = min(1.0, max(0.0, (safeDur - t) / max(0.05, anim.outDuration)))
            let easedExit = TextAnimationCurves.apply(progress: 1.0 - progress, easing: anim.motionEasing)
            applyOutAnimation(
                config: &evaluated, overlay: &overlay, outType: anim.outType,
                progress: progress, easedExit: easedExit, canvasSize: canvasSize,
                blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit
            )
        }
        if anim.loopType != .none {
            applyLoopAnimation(
                config: &evaluated, overlay: &overlay, loopType: anim.loopType,
                phase: t * anim.loopSpeed * 2.0 * .pi, t: t, loopSpeed: anim.loopSpeed, hue: &hue
            )
        }
        if anim.comboType != .none {
            TextComboAnimationEvaluator.applyPro(
                config: &evaluated, overlay: &overlay, rgbSplit: &rgbSplit,
                comboType: anim.comboType, t: t, duration: safeDur, canvasSize: canvasSize
            )
        }
        if !anim.isMotionBlurEnabled { overlay.motionBlurRadius = 0.0 }
        return EvaluationResult(
            config: evaluated, blurRadius: blur, hueAngle: hue,
            pixelateScale: pixelate, rgbSplitIntensity: rgbSplit, overlay: overlay
        )
    }

    private static func applyInAnimation(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, eased: Double,
        canvasSize: CGSize, blur: inout Double, rgbSplit: inout Double, isCursorVisible: Bool
    ) {
        let invEased = 1.0 - eased
        switch inType {
        case .none: return
        case .typewriter:
            applyTypewriterIn(config: &config, progress: progress, isCursorVisible: isCursorVisible)
            return
        case .fadeIn: break
        case .zoomIn: config.scale *= max(0.01, eased)
        case .blurIn: blur = max(blur, (1.0 - progress) * 16.0)
        case .popBounce:
            let b = progress < 0.7 ? (progress / 0.7) * 1.15 : 1.15 - ((progress - 0.7) / 0.3) * 0.15
            config.scale *= max(0.01, b)
            let jelly = TextAnimationCurves.jellySquashStretch(progress: progress, amplitude: 0.18)
            overlay.scaleX *= jelly.scaleX; overlay.scaleY *= jelly.scaleY
        case .elasticJellyIn, .whipPanLeft, .glitchSliceIn, .origamiUnfold, .swooshDrop:
            applyCapCutProIn(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, eased: eased, invEased: invEased, canvasSize: canvasSize, rgbSplit: &rgbSplit
            )
        case .waveBounce:
            config.positionY += sin(progress * .pi * 2.5) * (1.0 - progress) * 25.0
            config.scale *= max(0.01, eased)
        case .springDrop:
            let bounceP = TextAnimationCurves.bounceEaseOut(progress)
            config.positionY -= Double((1.0 - bounceP) * (canvasSize.height * 0.4))
            config.scale *= (0.8 + 0.2 * bounceP)
            let impact = TextAnimationCurves.impactSquash(progress: progress)
            overlay.scaleX *= impact.scaleX; overlay.scaleY *= impact.scaleY
        case .maskReveal: config.positionY += Double(invEased * (canvasSize.height * 0.2))
        case .trackingExpand: config.characterSpacing += (1.0 - eased) * (-15.0)
        default:
            if applySlideFlyOrVortexIn(
                config: &config, overlay: &overlay, inType: inType,
                progress: progress, eased: eased, invEased: invEased, canvasSize: canvasSize, blur: &blur
            ) { return }
        }
        config.opacity *= progress
    }

    private static func applyCapCutProIn(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, eased: Double,
        invEased: Double, canvasSize: CGSize, rgbSplit: inout Double
    ) {
        switch inType {
        case .elasticJellyIn:
            config.scale *= max(0.05, TextAnimationCurves.springOvershoot(progress, tension: 2.1))
            let jelly = TextAnimationCurves.jellySquashStretch(progress: progress, amplitude: 0.42, frequency: 4.0)
            overlay.scaleX *= jelly.scaleX; overlay.scaleY *= jelly.scaleY
        case .whipPanLeft:
            let whip = pow(1.0 - progress, 3.0)
            config.positionX -= Double(whip * canvasSize.width * 0.75)
            overlay.skewX += whip * 0.55 - sin(progress * .pi * 2.0) * (1.0 - progress) * 0.15
            overlay.motionBlurRadius = whip * 32.0; overlay.motionBlurAngle = 0.0
        case .glitchSliceIn:
            overlay.glitchSliceIntensity = (1.0 - progress) * 0.95
            rgbSplit = max(rgbSplit, (1.0 - progress) * 14.0)
            config.positionX += sin(progress * 45.0) * (1.0 - progress) * 18.0
        case .origamiUnfold:
            overlay.perspectiveX = -invEased * 0.85; overlay.scaleY *= max(0.08, eased)
            config.positionY -= Double(invEased * 28.0)
        case .swooshDrop:
            let bounceP = TextAnimationCurves.bounceEaseOut(progress)
            config.positionY += Double((1.0 - bounceP) * canvasSize.height * 0.55)
            config.rotation -= invEased * 24.0
            let impact = TextAnimationCurves.impactSquash(progress: progress)
            overlay.scaleX *= impact.scaleX; overlay.scaleY *= impact.scaleY
            overlay.motionBlurRadius = (1.0 - bounceP) * 20.0; overlay.motionBlurAngle = .pi / 2.0
        default: break
        }
    }

    private static func applySlideFlyOrVortexIn(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        inType: TextInAnimationType, progress: Double, eased: Double,
        invEased: Double, canvasSize: CGSize, blur: inout Double
    ) -> Bool {
        switch inType {
        case .slideUp: config.positionY -= Double(invEased * (canvasSize.height * 0.35))
        case .slideDown: config.positionY += Double(invEased * (canvasSize.height * 0.35))
        case .slideLeft: config.positionX += Double(invEased * (canvasSize.width * 0.35)); overlay.skewX -= invEased * 0.22
        case .slideRight: config.positionX -= Double(invEased * (canvasSize.width * 0.35)); overlay.skewX += invEased * 0.22
        case .flyInTop:
            config.positionY += Double(invEased * (canvasSize.height * 0.85))
            overlay.motionBlurRadius = invEased * 22.0; overlay.motionBlurAngle = .pi / 2.0
        case .flyInBottom:
            config.positionY -= Double(invEased * (canvasSize.height * 0.85))
            overlay.motionBlurRadius = invEased * 22.0; overlay.motionBlurAngle = .pi / 2.0
        case .flyInLeft:
            config.positionX -= Double(invEased * (canvasSize.width * 0.85))
            overlay.skewX += invEased * 0.35; overlay.motionBlurRadius = invEased * 26.0
        case .flyInRight:
            config.positionX += Double(invEased * (canvasSize.width * 0.85))
            overlay.skewX -= invEased * 0.35; overlay.motionBlurRadius = invEased * 26.0
        case .vortexSpin: config.rotation += invEased * 720.0; config.scale *= max(0.01, eased)
        case .shockwaveBlast:
            config.scale *= (1.0 + invEased * 2.5); blur = max(blur, (1.0 - progress) * 25.0)
            config.opacity *= (0.2 + 0.8 * progress); return true
        case .crashBounce:
            let bounceP = TextAnimationCurves.bounceEaseOut(progress)
            config.positionY += Double((1.0 - bounceP) * (canvasSize.height * 0.75))
            let impact = TextAnimationCurves.impactSquash(progress: progress)
            overlay.scaleX *= impact.scaleX; overlay.scaleY *= impact.scaleY
            config.opacity *= min(1.0, progress * 2.5); return true
        case .neonFlicker:
            let step = sin(progress * 30.0)
            config.opacity *= progress < 0.85 ? (step > 0 ? 0.95 : 0.15) : 1.0
            if progress < 0.65 { config.scale *= (1.0 + step * 0.04) }; return true
        case .flip3D:
            config.rotation += invEased * 18.0; config.scale *= max(0.01, eased)
            overlay.perspectiveY = invEased * 0.85; overlay.scaleX *= max(0.1, cos(invEased * 1.4))
        case .flipX3D:
            config.scale *= max(0.01, eased); config.rotation += invEased * 90.0
            overlay.perspectiveX = invEased * 0.85; overlay.scaleY *= max(0.1, cos(invEased * 1.4))
        default: break
        }
        return false
    }

    private static func applyTypewriterIn(config: inout TextConfiguration, progress: Double, isCursorVisible: Bool) {
        let len = config.content.count
        let count = min(len, max(0, Int(Double(len) * progress)))
        var sub = String(config.content.prefix(count))
        if isCursorVisible && progress < 1.0 { sub.append("|") }
        config.content = sub
    }

    private static func applyOutAnimation(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        outType: TextOutAnimationType, progress: Double, easedExit: Double,
        canvasSize: CGSize, blur: inout Double, pixelate: inout Double, rgbSplit: inout Double
    ) {
        guard outType != .none else { return }
        switch outType {
        case .none, .fadeOut: break
        case .zoomOut: config.scale *= max(0.01, progress)
        case .blurOut: blur = max(blur, (1.0 - progress) * 16.0)
        case .whipPanRight:
            config.positionX += Double(easedExit * canvasSize.width * 0.8)
            overlay.skewX -= easedExit * 0.55; overlay.motionBlurRadius = easedExit * 30.0
        case .elasticSnapOut:
            config.scale *= progress > 0.7 ? 1.0 + ((1.0 - progress) / 0.3) * 0.25 : max(0.02, progress / 0.7)
            overlay.scaleX *= (1.0 + easedExit * 0.3); overlay.scaleY *= max(0.1, 1.0 - easedExit * 0.4)
        case .shatterGlitch:
            overlay.glitchSliceIntensity = max(overlay.glitchSliceIntensity, easedExit * 0.95)
            rgbSplit = max(rgbSplit, easedExit * 15.0); config.positionX += cos(easedExit * 35.0) * 14.0
        case .foldDown3D: overlay.perspectiveX = easedExit * 0.85; overlay.scaleY *= max(0.05, progress)
        case .fallDown:
            config.positionY -= Double(easedExit * (canvasSize.height * 0.5)); config.rotation += Double(easedExit * 18.0)
        case .maskSink: config.positionY += Double(easedExit * (canvasSize.height * 0.2))
        case .trackingCollapse: config.characterSpacing -= easedExit * 20.0
        case .glitchDissolve:
            pixelate = max(pixelate, easedExit * 30.0); config.positionX += sin(easedExit * 25.0) * 10.0
        case .slideUp: config.positionY += Double(easedExit * (canvasSize.height * 0.35))
        case .slideDown: config.positionY -= Double(easedExit * (canvasSize.height * 0.35))
        case .slideLeft: config.positionX -= Double(easedExit * (canvasSize.width * 0.35))
        case .slideRight: config.positionX += Double(easedExit * (canvasSize.width * 0.35))
        case .flyOutTop: config.positionY += Double(easedExit * (canvasSize.height * 0.85)); overlay.motionBlurRadius = easedExit * 22.0
        case .flyOutBottom: config.positionY -= Double(easedExit * (canvasSize.height * 0.85)); overlay.motionBlurRadius = easedExit * 22.0
        case .flyOutLeft: config.positionX -= Double(easedExit * (canvasSize.width * 0.85)); overlay.motionBlurRadius = easedExit * 25.0
        case .flyOutRight: config.positionX += Double(easedExit * (canvasSize.width * 0.85)); overlay.motionBlurRadius = easedExit * 25.0
        case .spiralFlyAway: config.rotation += easedExit * 720.0; config.scale *= max(0.01, progress)
        case .shockwaveBlast: config.scale *= (1.0 + easedExit * 2.5); blur = max(blur, easedExit * 25.0)
        case .pixelateDissolve: pixelate = max(pixelate, easedExit * 35.0)
        }
        config.opacity *= progress
    }

    private static func applyLoopAnimation(
        config: inout TextConfiguration, overlay: inout TextTransformOverlay,
        loopType: TextLoopAnimationType, phase: Double, t: Double, loopSpeed: Double, hue: inout Double
    ) {
        switch loopType {
        case .none: break
        case .lightSweep: overlay.lightSweepPhase = (t * loopSpeed * 0.65).truncatingRemainder(dividingBy: 1.0)
        case .jellyWave:
            let w = sin(phase) * 0.16; overlay.scaleX *= (1.0 + w); overlay.scaleY *= (1.0 - w * 0.85)
        case .swing3D:
            let s = sin(phase); overlay.perspectiveY += s * 0.55; overlay.scaleX *= max(0.4, cos(s * 0.75)); config.rotation += s * 4.0
        case .liquidWave: overlay.liquidWavePhase = phase
        case .pulse: config.scale *= (1.0 + sin(phase) * 0.08)
        case .floating: config.positionY += sin(phase) * 8.0
        case .wiggle: config.rotation += sin(phase * 1.5) * 3.0; overlay.skewX += sin(phase * 1.5) * 0.08
        case .rainbow: hue = phase.truncatingRemainder(dividingBy: 2.0 * .pi)
        case .glitch:
            let tick = Int(t * loopSpeed * 8.0) % 8
            if tick == 2 { config.positionX += 6.0; config.rotation += 1.5; overlay.glitchSliceIntensity = 0.5 }
            else if tick == 5 { config.positionX -= 5.0; config.rotation -= 1.5; overlay.glitchSliceIntensity = 0.4 }
        case .heartbeat:
            let beat = pow(sin(phase), 4.0) + 0.5 * pow(sin(phase + 0.4), 4.0)
            config.scale *= (1.0 + beat * 0.12)
        case .neonPulse:
            config.opacity *= (0.8 + 0.2 * abs(sin(phase * 2.0))); config.scale *= (1.0 + sin(phase * 2.0) * 0.03)
        case .earthquake:
            config.positionX += sin(phase * 7.3) * 6.0; config.positionY += cos(phase * 8.7) * 5.0; config.rotation += sin(phase * 5.1) * 2.0
        }
    }
}

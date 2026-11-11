import Foundation
import CoreGraphics
import Domain

/// Tham số biến dạng hình học & VFX tức thời của hoạt ảnh (Scale X/Y, Skew, 3D Perspective, Motion Blur, Light Sweep).
public struct TextTransformOverlay: Sendable, Equatable {
    public var scaleX: Double
    public var scaleY: Double
    public var skewX: Double
    public var perspectiveX: Double
    public var perspectiveY: Double
    public var motionBlurRadius: Double
    public var motionBlurAngle: Double
    public var lightSweepPhase: Double
    public var glitchSliceIntensity: Double
    public var liquidWavePhase: Double
    public var revealProgress: Double
    public var trailingCursorOpacity: Double
    public var waveAmplitudeEm: Double
    public var waveFrequencyEm: Double
    public var wavePhaseRadians: Double
    public var clipRevealX: Double
    public var clipRevealY: Double
    public var trackingEmDelta: Double
    public var echoCount: Int
    public var echoOffsetXEm: Double
    public var echoOffsetYEm: Double

    public init(
        scaleX: Double = 1.0, scaleY: Double = 1.0, skewX: Double = 0.0,
        perspectiveX: Double = 0.0, perspectiveY: Double = 0.0,
        motionBlurRadius: Double = 0.0, motionBlurAngle: Double = 0.0,
        lightSweepPhase: Double = -1.0, glitchSliceIntensity: Double = 0.0,
        liquidWavePhase: Double = -1.0, revealProgress: Double = -1.0,
        trailingCursorOpacity: Double = 0.0,
        waveAmplitudeEm: Double = 0.0, waveFrequencyEm: Double = 0.0, wavePhaseRadians: Double = 0.0,
        clipRevealX: Double = 1.0, clipRevealY: Double = 1.0, trackingEmDelta: Double = 0.0,
        echoCount: Int = 0, echoOffsetXEm: Double = 0.0, echoOffsetYEm: Double = 0.0
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
        self.revealProgress = revealProgress
        self.trailingCursorOpacity = trailingCursorOpacity
        self.waveAmplitudeEm = waveAmplitudeEm
        self.waveFrequencyEm = waveFrequencyEm
        self.wavePhaseRadians = wavePhaseRadians
        self.clipRevealX = clipRevealX
        self.clipRevealY = clipRevealY
        self.trackingEmDelta = trackingEmDelta
        self.echoCount = echoCount
        self.echoOffsetXEm = echoOffsetXEm
        self.echoOffsetYEm = echoOffsetYEm
    }
}

/// Lõi điều phối tính toán hoạt ảnh Text thời gian thực (Real-time Text Animation Engine)
/// Hỗ trợ cả gói hoạt ảnh sáng tạo mở (`CreativeAnimationManifest`) và hoạt ảnh tương thích ngược.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm) của AGENTS.md.
public enum TextAnimationEvaluator {

    public struct EvaluationResult: Sendable {
        public var config: TextConfiguration
        public var blurRadius: Double
        public var hueAngle: Double
        public var pixelateScale: Double
        public var rgbSplitIntensity: Double
        public var overlay: TextTransformOverlay

        public init(
            config: TextConfiguration, blurRadius: Double = 0.0, hueAngle: Double = 0.0,
            pixelateScale: Double = 0.0, rgbSplitIntensity: Double = 0.0,
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
        config: TextConfiguration, localTime: Double, duration: Double,
        canvasSize: CGSize, charIndex: Int = 0, charCount: Int = 1
    ) -> EvaluationResult {
        guard !config.animation.isDefault else { return EvaluationResult(config: config) }

        var evaluated = config
        var blur: Double = 0.0, hue: Double = 0.0, pixelate: Double = 0.0
        var rgbSplit = config.animation.rgbSplitIntensity
        var overlay = TextTransformOverlay()
        let anim = config.animation
        let safeDur = max(0.1, duration)
        let t = max(0.0, min(safeDur, localTime))

        // 0. Kịch bản hoạt ảnh chạy suốt thời lượng do Dev thiết kế (Script-Driven Animation)
        if anim.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: anim.scriptId) {
            return evaluateScriptAnimation(
                script: script, baseConfig: config, t: t,
                totalDuration: safeDur, charIndex: charIndex, charCount: charCount
            )
        }

        if anim.lightSweepIntensity > 0.01 {
            overlay.lightSweepPhase = (t * max(0.4, anim.loopSpeed) * 0.7).truncatingRemainder(dividingBy: 1.0)
        }

        // 1. Hiệu ứng Vào (In Animation)
        let inDuration = anim.hasInAnimation ? anim.inDuration : 0.0
        if anim.hasInAnimation, t < inDuration {
            let progress = min(1.0, max(0.0, t / max(0.05, inDuration)))
            if let manifest = anim.inManifest {
                let vars = OpenAnimationRuntimeEngine.Variables(
                    progress: progress, anim: anim, manifest: manifest,
                    charIndex: charIndex, charCount: charCount
                )
                OpenAnimationRuntimeEngine.applyManifest(
                    manifest, variables: vars, config: &evaluated, overlay: &overlay,
                    blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit, hue: &hue
                )
            } else {
                let eased = TextAnimationCurves.apply(progress: progress, easing: anim.motionEasing)
                TextInAnimationEvaluator.apply(
                    config: &evaluated, overlay: &overlay, inType: anim.inType,
                    progress: progress, eased: eased, canvasSize: canvasSize,
                    blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit,
                    isCursorVisible: anim.isTypewriterCursorVisible
                )
            }
        }

        // 2. Hiệu ứng Ra (Out Animation)
        let outDuration = anim.hasOutAnimation ? anim.outDuration : 0.0
        let outStart = max(inDuration, safeDur - outDuration)
        if anim.hasOutAnimation, t > outStart {
            let progress = min(1.0, max(0.0, (safeDur - t) / max(0.05, outDuration)))
            if let manifest = anim.outManifest {
                let vars = OpenAnimationRuntimeEngine.Variables(
                    progress: progress, anim: anim, manifest: manifest,
                    charIndex: charIndex, charCount: charCount
                )
                OpenAnimationRuntimeEngine.applyManifest(
                    manifest, variables: vars, config: &evaluated, overlay: &overlay,
                    blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit, hue: &hue
                )
            } else {
                let easedExit = TextAnimationCurves.apply(progress: 1.0 - progress, easing: anim.motionEasing)
                TextOutAnimationEvaluator.apply(
                    config: &evaluated, overlay: &overlay, outType: anim.outType,
                    progress: progress, easedExit: easedExit, canvasSize: canvasSize,
                    blur: &blur, rgbSplit: &rgbSplit
                )
            }
        }

        // 3. Hiệu ứng Vòng lặp (Loop Animation)
        if anim.hasLoopAnimation {
            let blend = calculateLoopBlend(t: t, inEnd: inDuration, outStart: outStart)
            if blend > 0.001 {
                let loopTime = max(0.0, t - inDuration)
                let phase = loopTime * anim.loopSpeed * 2.0 * .pi
                if let manifest = anim.loopManifest {
                    let vars = OpenAnimationRuntimeEngine.Variables(
                        progress: 1.0, phase: phase, blend: blend, anim: anim, manifest: manifest,
                        charIndex: charIndex, charCount: charCount
                    )
                    OpenAnimationRuntimeEngine.applyManifest(
                        manifest, variables: vars, config: &evaluated, overlay: &overlay,
                        blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit, hue: &hue
                    )
                } else {
                    TextLoopAnimationEvaluator.apply(
                        config: &evaluated, overlay: &overlay, loopType: anim.loopType,
                        phase: phase, t: t, loopSpeed: anim.loopSpeed, blend: blend, hue: &hue
                    )
                }
            }
        }

        if !anim.isMotionBlurEnabled { overlay.motionBlurRadius = 0.0 }
        return EvaluationResult(
            config: evaluated, blurRadius: blur, hueAngle: hue,
            pixelateScale: pixelate, rgbSplitIntensity: rgbSplit, overlay: overlay
        )
    }

    private static func evaluateScriptAnimation(
        script: any TextAnimationScript,
        baseConfig: TextConfiguration,
        t: Double,
        totalDuration: Double,
        charIndex: Int,
        charCount: Int
    ) -> EvaluationResult {
        var evaluated = baseConfig
        var overlay = TextTransformOverlay()
        let phase = script.resolvePhase(anim: baseConfig.animation, localTime: t, duration: totalDuration)
        let delta = script.evaluatePhase(base: baseConfig, phase: phase, unitIndex: charIndex, unitTotal: charCount)

        evaluated.positionX += delta.offsetX
        evaluated.positionY += delta.offsetY
        overlay.scaleX *= delta.scaleX
        overlay.scaleY *= delta.scaleY
        evaluated.skewX += delta.skewX
        evaluated.skewY += delta.skewY
        evaluated.rotation += delta.rotation
        evaluated.opacity = max(0.0, min(1.0, evaluated.opacity * delta.opacity))
        overlay.trailingCursorOpacity = delta.trailingCursorOpacity
        overlay.waveAmplitudeEm = delta.waveAmplitudeEm
        overlay.waveFrequencyEm = delta.waveFrequencyEm
        overlay.wavePhaseRadians = delta.wavePhaseRadians
        overlay.clipRevealX = delta.clipRevealX
        overlay.clipRevealY = delta.clipRevealY
        overlay.trackingEmDelta = delta.trackingEmDelta
        overlay.echoCount = delta.echoCount
        overlay.echoOffsetXEm = delta.echoOffsetXEm
        overlay.echoOffsetYEm = delta.echoOffsetYEm
        if let anchorOverride = delta.anchorOverride {
            evaluated.animation.anchorPoint = anchorOverride
        }

        // Bảo toàn 100% Fill (Solid/Gradient) và Dual Stroke của người dùng;
        // chỉ điều biến tương đối Glow/Shadow khi người dùng đã chủ động bật trong Style.
        if delta.glowIntensityDelta != 0.0, baseConfig.glow.isActive {
            evaluated.glow.intensity = max(0.0, min(100.0, baseConfig.glow.intensity + delta.glowIntensityDelta))
        }
        if delta.shadowDistanceDelta != 0.0, baseConfig.shadow.isActive {
            evaluated.shadow.distance = max(0.0, baseConfig.shadow.distance + delta.shadowDistanceDelta)
        }
        let blur = max(0.0, delta.blurRadius)
        let rgbSplit = max(baseConfig.animation.rgbSplitIntensity, delta.glitchIntensity)
        return EvaluationResult(
            config: evaluated, blurRadius: blur, hueAngle: 0.0,
            pixelateScale: 0.0, rgbSplitIntensity: rgbSplit, overlay: overlay
        )
    }

    private static func calculateLoopBlend(t: Double, inEnd: Double, outStart: Double) -> Double {
        if t < inEnd || t > outStart {
            return 0.0
        }
        let fadeWindow = 0.12
        var blend = 1.0
        if inEnd > 0.0, t < inEnd + fadeWindow {
            blend = min(blend, (t - inEnd) / fadeWindow)
        }
        if outStart < 1000.0, t > outStart - fadeWindow {
            blend = min(blend, (outStart - t) / fadeWindow)
        }
        return max(0.0, min(1.0, blend))
    }
}

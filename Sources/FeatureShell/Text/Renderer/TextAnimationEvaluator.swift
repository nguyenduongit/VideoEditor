import Foundation
import CoreGraphics
import Domain

/// Lõi điều phối tính toán hoạt ảnh Text thời gian thực (Real-time Text Animation Engine)
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

        // 1. Hiệu ứng Vào (In Animation)
        let inDuration = anim.inType != .none ? anim.inDuration : 0.0
        if anim.inType != .none, t < inDuration {
            let progress = min(1.0, max(0.0, t / max(0.05, inDuration)))
            let eased = TextAnimationCurves.apply(progress: progress, easing: anim.motionEasing)
            TextInAnimationEvaluator.apply(
                config: &evaluated, overlay: &overlay, inType: anim.inType,
                progress: progress, eased: eased, canvasSize: canvasSize,
                blur: &blur, pixelate: &pixelate, rgbSplit: &rgbSplit,
                isCursorVisible: anim.isTypewriterCursorVisible
            )
        }

        // 2. Hiệu ứng Ra (Out Animation)
        let outDuration = anim.outType != .none ? anim.outDuration : 0.0
        let outStart = max(inDuration, safeDur - outDuration)
        if anim.outType != .none, t > outStart {
            let progress = min(1.0, max(0.0, (safeDur - t) / max(0.05, outDuration)))
            let easedExit = TextAnimationCurves.apply(progress: 1.0 - progress, easing: anim.motionEasing)
            TextOutAnimationEvaluator.apply(
                config: &evaluated, overlay: &overlay, outType: anim.outType,
                progress: progress, easedExit: easedExit, canvasSize: canvasSize,
                blur: &blur, rgbSplit: &rgbSplit
            )
        }

        // 3. Hiệu ứng Vòng lặp (Loop Animation)
        // Chạy trong khoảng thời gian giữa điểm kết thúc của In và điểm bắt đầu của Out
        if anim.loopType != .none {
            let blend = calculateLoopBlend(t: t, inEnd: inDuration, outStart: outStart)
            if blend > 0.001 {
                let loopTime = max(0.0, t - inDuration)
                let phase = loopTime * anim.loopSpeed * 2.0 * .pi
                TextLoopAnimationEvaluator.apply(
                    config: &evaluated, overlay: &overlay, loopType: anim.loopType,
                    phase: phase, t: t, loopSpeed: anim.loopSpeed, blend: blend, hue: &hue
                )
            }
        }

        if !anim.isMotionBlurEnabled { overlay.motionBlurRadius = 0.0 }
        return EvaluationResult(
            config: evaluated, blurRadius: blur, hueAngle: hue,
            pixelateScale: pixelate, rgbSplitIntensity: rgbSplit, overlay: overlay
        )
    }

    /// Tính hệ số hòa quyện (Blend) cho Loop Animation
    /// Loop chỉ chạy toàn phần giữa [inEnd, outStart], có fade êm dịu 0.1s ở ranh giới
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

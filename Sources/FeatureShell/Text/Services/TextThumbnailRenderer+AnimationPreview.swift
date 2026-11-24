import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

extension TextThumbnailRenderer {
    private static let animationPreviewFrameCache = LRUCache<String, NSImage>(capacity: 480)

    /// Snappy continuous loop duration for Inspector animation cards (`Intro -> Loop -> Outro`).
    public static func scriptPreviewDuration(for script: any TextAnimationScript) -> Double {
        2.8
    }

    /// Computes hover/active preview local time starting cleanly from `t = 0.0` (beginning of Intro).
    public static func scriptPreviewLocalTime(startDate: Date, currentDate: Date, duration: Double) -> Double {
        let safeDuration = max(0.2, duration)
        let elapsed = max(0.0, currentDate.timeIntervalSince(startDate))
        return elapsed.truncatingRemainder(dividingBy: safeDuration)
    }

    /// Renders a 1:1 canvas-accurate animated preview frame for a unified `TextAnimationScript`.
    public static func renderScriptPreviewFrame(
        scriptId: String,
        localTime: Double,
        duration: Double = 5.0,
        targetSize: CGSize = CGSize(width: 260, height: 120)
    ) -> NSImage? {
        let clampedTime = min(duration, max(0.0, localTime))
        let frameBucket = Int((clampedTime * 24.0).rounded())
        let durBucket = Int((duration * 10.0).rounded())
        let sizeBucket = "\(Int(targetSize.width.rounded()))x\(Int(targetSize.height.rounded()))"
        let frameKey = "script_unified_\(scriptId)_\(durBucket)_\(sizeBucket)_\(frameBucket)"
        if let cached = animationPreviewFrameCache[frameKey] {
            return cached
        }

        let script = TextAnimationScriptRegistry.shared.script(for: scriptId)
        let sampleContent: String
        switch script?.scope {
        case .perLine: sampleContent = "Line 1\nLine 2"
        case .perWord: sampleContent = "New Text"
        default: sampleContent = "Text"
        }
        var config = TextConfiguration(
            content: sampleContent,
            fontName: "Helvetica-Bold",
            fontSize: script?.scope == .perLine ? 28.0 : 36.0,
            textColorHex: "#FFFFFF",
            isBold: true
        )
        config.animation.scriptId = scriptId
        config.animation.scriptInDuration = script?.defaultInDuration ?? 1.0
        config.animation.scriptLoopDuration = script?.defaultLoopDuration ?? 3.0
        config.animation.scriptOutDuration = script?.defaultOutDuration ?? 1.0
        config.animation.scriptDuration = duration

        let effectiveTime = min(duration, max(0.0, Double(frameBucket) / 24.0))
        guard let ciImage = sharedEngine.renderAnimatedImage(
            for: config,
            localTime: effectiveTime,
            duration: duration,
            canvasSize: targetSize
        ),
        let cgImage = ciContext.createCGImage(ciImage, from: CGRect(origin: .zero, size: targetSize)) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: targetSize)
        animationPreviewFrameCache[frameKey] = image
        return image
    }

    private static let heroPreviewTimeMap: [String: Double] = [
        "title_wave_float": 1.25, "typewriter_cursor": 0.55, "kinetic_drop_glow": 0.35,
        "curved_arc_roller": 1.15, "neon_cyber_shift": 0.42, "liquid_wave_pulse": 1.20,
        "glitch_rgb_pop": 0.32, "smooth_word_glide": 0.38, "elastic_flip_3d": 0.36,
        "pop_up_hinge_3d": 0.38, "whip_echo_slam": 0.34, "tornado_spiral_pop": 0.42,
        "trailer_tracking_expand": 0.35, "pendulum_hinge_swing": 0.40,
        "anamorphic_split_reveal": 0.42, "ripple_drop_wave": 1.18, "dna_helix_twist": 1.15,
        "jelly_trampoline_wave": 1.22, "hologram_scan_beam": 0.40, "vhs_tracking_drift": 0.32,
        "quantum_teleport_flicker": 0.36, "cyber_shutter_slice": 0.40,
        "curtain_baseline_rise": 0.42, "shutter_blind_reveal": 0.44,
        "soft_breathe_cascade": 0.40, "flip_counter_roll": 0.42, "karaoke_glow_flow": 1.35,
        "line_cascade_rise": 0.48, "blur_focus_dissolve": 0.36, "beat_pulse_slam": 1.25,
        "three_d_tumble_drop": 0.42, "three_d_swinging_door": 0.40, "three_d_depth_rush": 0.45,
        "fx_pixel_dissolve": 0.36, "slide_directional_whip": 0.32, "slide_zipper_cross": 0.34,
        "wave_flag_flutter": 1.30, "wave_liquid_ripple": 1.28, "typewriter_neon_draw": 0.58,
        "typewriter_cipher_decode": 0.42, "three_d_card_carousel": 0.38,
        "fade_diagonal_slash": 0.42, "slide_center_split": 0.42, "pop_collision_slam": 0.36,
        "slide_up_up": 0.34, "slide_down_down": 0.34, "slide_up_down": 0.34, "slide_down_up": 0.34,
        "slide_left_left": 0.34, "slide_left_right": 0.34, "slide_right_left": 0.34, "slide_right_right": 0.34
    ]

    /// Thời điểm đặc trưng (Hero Frame) để hiển thị ảnh thu nhỏ tĩnh trung thực cho từng Script
    public static func heroPreviewTime(for scriptId: String) -> Double {
        heroPreviewTimeMap[scriptId] ?? 0.50
    }

    public static func clearAnimationPreviewCache() {
        animationPreviewFrameCache.removeAll()
    }
}

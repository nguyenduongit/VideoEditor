import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

extension TextThumbnailRenderer {
    private static let animationPreviewFrameCache = LRUCache<String, NSImage>(capacity: 360)

    /// Renders a 1:1 canvas-accurate animated preview frame for a unified `TextAnimationScript`.
    public static func renderScriptPreviewFrame(
        scriptId: String,
        localTime: Double,
        duration: Double = 5.0,
        targetSize: CGSize = CGSize(width: 260, height: 120)
    ) -> NSImage? {
        let frameBucket = Int((localTime * 24.0).rounded())
        let frameKey = "script_unified_\(scriptId)_\(frameBucket)"
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

        let effectiveTime = Double(frameBucket) / 24.0
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

    /// Thời điểm đặc trưng (Hero Frame) để hiển thị ảnh thu nhỏ tĩnh trung thực cho từng Script
    public static func heroPreviewTime(for scriptId: String) -> Double {
        switch scriptId {
        case "title_wave_float": return 1.25
        case "typewriter_cursor": return 0.55
        case "kinetic_drop_glow": return 0.35
        case "curved_arc_roller": return 1.15
        case "neon_cyber_shift": return 0.42
        case "liquid_wave_pulse": return 1.20
        case "glitch_rgb_pop": return 0.32
        case "smooth_word_glide": return 0.38
        case "elastic_flip_3d": return 0.36
        case "pop_up_hinge_3d": return 0.38
        case "whip_echo_slam": return 0.34
        case "tornado_spiral_pop": return 0.42
        case "trailer_tracking_expand": return 0.35
        case "pendulum_hinge_swing": return 0.40
        case "anamorphic_split_reveal": return 0.42
        case "ripple_drop_wave": return 1.18
        case "dna_helix_twist": return 1.15
        case "jelly_trampoline_wave": return 1.22
        case "hologram_scan_beam": return 0.40
        case "vhs_tracking_drift": return 0.32
        case "quantum_teleport_flicker": return 0.36
        case "cyber_shutter_slice": return 0.40
        case "curtain_baseline_rise": return 0.42
        case "shutter_blind_reveal": return 0.44
        case "soft_breathe_cascade": return 0.40
        case "flip_counter_roll": return 0.42
        case "karaoke_box_pop": return 1.35
        case "karaoke_glow_flow": return 1.35
        case "line_cascade_rise": return 0.48
        case "blur_focus_dissolve": return 0.36
        case "beat_pulse_slam": return 1.25
        case "three_d_tumble_drop": return 0.42
        case "three_d_swinging_door": return 0.40
        case "three_d_depth_rush": return 0.45
        case "fx_metallic_sweep": return 1.48
        case "fx_pixel_dissolve": return 0.36
        case "fx_neon_ignition": return 1.40
        case "fx_chromatic_vapor": return 0.42
        case "slide_directional_whip": return 0.32
        case "slide_zipper_cross": return 0.34
        case "wave_flag_flutter": return 1.30
        case "wave_liquid_ripple": return 1.28
        case "glitch_crt_slice_tear": return 0.36
        default: return 0.50
        }
    }

    public static func clearAnimationPreviewCache() {
        animationPreviewFrameCache.removeAll()
    }
}

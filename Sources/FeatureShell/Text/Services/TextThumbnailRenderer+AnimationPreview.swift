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

    public static func scriptPreviewDuration(for item: TextAnimationCatalogItem) -> Double {
        2.8
    }

    /// Computes hover/active preview local time starting cleanly from `t = 0.0` (beginning of Intro).
    public static func scriptPreviewLocalTime(startDate: Date, currentDate: Date, duration: Double) -> Double {
        let safeDuration = max(0.2, duration)
        let elapsed = max(0.0, currentDate.timeIntervalSince(startDate))
        return elapsed.truncatingRemainder(dividingBy: safeDuration)
    }

    /// Renders a 1:1 canvas-accurate animated preview frame for a unified `TextAnimationScript` or `TextAnimationGraph`.
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

        let catalogItem = TextAnimationCatalogItem.item(for: scriptId)
        let graph = catalogItem?.graphValue ?? TextAnimationGraphLibrary.graph(for: scriptId)
        let script = TextAnimationScriptRegistry.shared.script(for: scriptId)
        let resolvedScope = graph?.scope ?? script?.scope
        let sampleContent: String
        switch resolvedScope {
        case .perLine: sampleContent = "Line 1\nLine 2"
        case .perWord: sampleContent = "New Text"
        default: sampleContent = "Text"
        }
        var config = TextConfiguration(
            content: sampleContent,
            fontName: "Helvetica-Bold",
            fontSize: resolvedScope == .perLine ? 28.0 : 36.0,
            textColorHex: "#FFFFFF",
            isBold: true
        )
        config.animation.scriptId = scriptId
        config.animation.graph = graph
        config.animation.scriptInDuration = script?.defaultInDuration ?? 1.0
        config.animation.scriptLoopDuration = script?.defaultLoopDuration ?? 3.0
        config.animation.scriptOutDuration = script?.defaultOutDuration ?? 1.0
        config.animation.scriptDuration = duration

        let effectiveTime = min(duration, max(0.0, Double(frameBucket) / 24.0))
        let isAudioPreset = scriptId == "graph_audio_beat_pulse" || scriptId == "graph_audio_eq_bounce"
        let simulatedBeat = isAudioPreset ? (0.45 + 0.45 * abs(sin(effectiveTime * .pi * 2.0))) : 0.0
        let simulatedTreble = isAudioPreset ? (0.35 + 0.50 * abs(cos(effectiveTime * .pi * 3.0))) : 0.0
        let inputs: [String: Double] = isAudioPreset
            ? [
                TextAnimationChannel.audioRMS: simulatedBeat,
                TextAnimationChannel.audioBass: simulatedBeat,
                TextAnimationChannel.audioTreble: simulatedTreble,
                TextAnimationChannel.audioBeat: simulatedBeat
            ]
            : [:]
        guard let ciImage = sharedEngine.renderAnimatedImage(
            for: config,
            localTime: effectiveTime,
            duration: duration,
            canvasSize: targetSize,
            animationInputs: inputs
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
        "elastic_flip_3d": 0.36, "pop_up_hinge_3d": 0.38, "tornado_spiral_pop": 0.42,
        "pendulum_hinge_swing": 0.40, "ripple_drop_wave": 1.18, "dna_helix_twist": 1.15,
        "curtain_baseline_rise": 0.42, "flip_counter_roll": 0.42, "karaoke_glow_flow": 1.35,
        "blur_focus_dissolve": 0.36, "beat_pulse_slam": 1.25, "three_d_tumble_drop": 0.42,
        "fx_pixel_dissolve": 0.36, "wave_liquid_ripple": 1.28, "typewriter_neon_draw": 0.58,
        "typewriter_cipher_decode": 0.42, "three_d_card_carousel": 0.38,
        "fade_diagonal_slash": 0.42, "slide_center_split": 0.42, "pop_collision_slam": 0.36,
        "slide_up_up": 0.34, "slide_down_down": 0.34, "slide_up_down": 0.34, "slide_down_up": 0.34,
        "slide_left_left": 0.34, "slide_left_right": 0.34, "slide_right_left": 0.34, "slide_right_right": 0.34,
        "graph_chrome_bevel_3d": 1.20, "graph_quantum_particles": 0.48, "graph_audio_beat_pulse": 1.15,
        "graph_door_hinge_3d": 0.34, "graph_orbit_carousel_3d": 1.35, "graph_bezier_ribbon_fly": 0.42,
        "graph_flag_mesh_flutter": 1.25, "graph_arc_bend_bounce": 0.32, "graph_tracked_expand": 0.42,
        "graph_origami_corner_unfold": 0.36, "graph_spiral_vortex_orbit": 0.44, "graph_ribbon_twist_snap": 0.34,
        "graph_lens_bubble_pop": 0.30, "graph_domino_bottom_cascade": 0.40, "graph_audio_eq_bounce": 1.20,
        "graph_slalom_spline_glide": 0.42, "graph_right_hinge_trapdoor": 0.36, "graph_jelly_mercury_wave": 1.25,
        "graph_pendulum_top_corner": 0.38, "graph_iris_laser_carve": 0.48, "graph_cipher_scramble_draw": 0.45
    ]

    /// Thời điểm đặc trưng (Hero Frame) để hiển thị ảnh thu nhỏ tĩnh trung thực cho từng Script
    public static func heroPreviewTime(for scriptId: String) -> Double {
        heroPreviewTimeMap[scriptId] ?? 0.50
    }

    public static func clearAnimationPreviewCache() {
        animationPreviewFrameCache.removeAll()
    }
}

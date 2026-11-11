import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

extension TextThumbnailRenderer {
    private static let animationPreviewFrameCache = LRUCache<String, NSImage>(capacity: 360)

    /// Kết xuất khung hình hoạt ảnh chân thực 1:1 cho AnimationPreset trên chữ mẫu "Text"
    /// Sử dụng trực tiếp `TextRendererEngine` và `TextSegmentRenderer` để phản ánh đúng per-character,
    /// độ trễ stagger, mặt nạ quét (reveal) và đường cong gia tốc toán học.
    public static func renderAnimationPreviewFrame(
        preset: AnimationPreset,
        localTime: Double,
        duration: Double,
        targetSize: CGSize = CGSize(width: 320, height: 160)
    ) -> NSImage? {
        let frameBucket = Int((localTime * 30.0).rounded())
        let frameKey = "anim_thumb_\(preset.id)_\(frameBucket)"
        if let cached = animationPreviewFrameCache[frameKey] {
            return cached
        }

        var config = TextConfiguration(
            content: "Text",
            fontName: "Helvetica-Bold",
            fontSize: 38.0,
            textColorHex: "#FFFFFF",
            isBold: true
        )
        config.positionX = 0.0
        config.positionY = 0.0
        config.scale = 1.0
        config.rotation = 0.0
        config.opacity = 1.0

        switch preset.phase {
        case .inAnimation:
            config.animation.inManifest = preset.manifest
            config.animation.inDuration = 1.0
            config.animation.scope = preset.manifest.defaultScope
            config.animation.staggerDirection = preset.manifest.defaultStaggerDirection
        case .loopAnimation:
            config.animation.loopManifest = preset.manifest
            config.animation.loopSpeed = 1.0
            config.animation.scope = preset.manifest.defaultScope
            config.animation.staggerDirection = preset.manifest.defaultStaggerDirection
        case .outAnimation:
            config.animation.outManifest = preset.manifest
            config.animation.outDuration = 1.0
            config.animation.scope = preset.manifest.defaultScope
            config.animation.staggerDirection = preset.manifest.defaultStaggerDirection
        }

        let effectiveTime = Double(frameBucket) / 30.0
        guard let ciImage = sharedEngine.renderAnimatedImage(
            for: config,
            localTime: effectiveTime,
            duration: max(0.5, duration),
            canvasSize: targetSize
        ),
        let cgImage = ciContext.createCGImage(ciImage, from: CGRect(origin: .zero, size: targetSize)) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: targetSize)
        animationPreviewFrameCache[frameKey] = image
        return image
    }

    /// Kết xuất khung hình xem trước đồng nhất 100% với Canvas cho Kịch bản Hoạt ảnh (`TextAnimationScript`).
    /// Không thêm bất kỳ màu/viền giả lập nào để Thumbnail phản ánh trung thực tuyệt đối chuyển động thực tế.
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
        let isPerWord = script?.scope == .perWord
        let sampleContent = isPerWord ? "New Text" : "Text"
        var config = TextConfiguration(
            content: sampleContent,
            fontName: "Helvetica-Bold",
            fontSize: 36.0,
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
        default: return 0.50
        }
    }

    public static func clearAnimationPreviewCache() {
        animationPreviewFrameCache.removeAll()
    }
}

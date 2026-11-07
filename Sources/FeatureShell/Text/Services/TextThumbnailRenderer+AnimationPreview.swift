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

    public static func clearAnimationPreviewCache() {
        animationPreviewFrameCache.removeAll()
    }
}

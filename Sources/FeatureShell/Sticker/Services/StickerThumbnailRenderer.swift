import Foundation
import AppKit
import CoreImage
import Domain

/// High-performance 1:1 preview thumbnail renderer for Sticker Animation cards using LRU caching.
@MainActor
public enum StickerThumbnailRenderer {
    private static let cache = LRUCache<String, NSImage>(capacity: 240)
    private static let engine = StickerRendererEngine()
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let canvasSize = CGSize(width: 140, height: 84)
    public static let previewClipDuration: Double = 2.4

    /// Returns a representative frame time inside the animation so static thumbnails look unmistakable.
    public static func heroPreviewTime(for script: any StickerAnimationScript) -> Double {
        switch script.category {
        case .fade: return 0.30
        case .motion: return 0.24
        case .glitch: return 0.28
        case .pop, .bounce, .swing: return 0.88
        }
    }

    /// Renders (or retrieves from LRU cache) a preview `NSImage` for the given script and source sticker config.
    public static func renderThumbnail(
        for script: (any StickerAnimationScript)?,
        sourceConfig: StickerConfiguration,
        time: Double
    ) -> NSImage {
        let resolvedId = script?.id ?? "none"
        let frameBucket = Int((max(0.0, time) * 24.0).rounded())
        let symbolKey = sourceConfig.systemSymbolFallback ?? "star.fill"
        let cacheKey = "\(resolvedId)_\(symbolKey)_\(sourceConfig.format.rawValue)_\(frameBucket)"
        if let cached = cache.get(cacheKey) {
            return cached
        }

        let previewCfg = buildPreviewConfig(for: script, from: sourceConfig)
        let ciImage = engine.renderStickerImage(
            config: previewCfg,
            clipProperties: [:],
            localTime: time,
            duration: previewClipDuration,
            canvasSize: canvasSize
        )

        let image = rasterize(ciImage)
        cache.set(image, for: cacheKey)
        return image
    }

    private static func buildPreviewConfig(
        for script: (any StickerAnimationScript)?,
        from source: StickerConfiguration
    ) -> StickerConfiguration {
        var cfg = source
        cfg.flipHorizontal = false
        cfg.flipVertical = false
        if let script {
            var anim = StickerAnimationConfiguration(scriptId: script.id)
            anim.applyUnifiedScriptTiming(baseLoopSeconds: 1.4, speed: 1.0, defaultIn: 0.5, defaultOut: 0.5)
            cfg.animation = anim
        } else {
            cfg.animation = StickerAnimationConfiguration()
        }
        return cfg
    }

    private static func rasterize(_ ciImage: CIImage?) -> NSImage {
        guard let ciImage else {
            return NSImage(size: NSSize(width: canvasSize.width, height: canvasSize.height))
        }
        let rect = CGRect(origin: .zero, size: canvasSize)
        guard let cg = ciContext.createCGImage(ciImage, from: rect) else {
            return NSImage(size: NSSize(width: canvasSize.width, height: canvasSize.height))
        }
        return NSImage(cgImage: cg, size: NSSize(width: canvasSize.width, height: canvasSize.height))
    }
}

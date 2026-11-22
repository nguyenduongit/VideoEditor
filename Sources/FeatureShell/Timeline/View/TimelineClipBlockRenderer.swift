import SwiftUI
import AppKit
import AVFoundation
import CoreMedia
import Domain
import DesignSystem

@MainActor
public enum TimelineClipBlockRenderer {
    public static let minBlockWidth: CGFloat = 28.0
    public static let maxBlockWidth: CGFloat = 800.0

    private static let imageCache = LRUCache<String, NSImage>(capacity: 96)
    private static let quickThumbnailCache = LRUCache<URL, NSImage>(capacity: 64)
    private static let dragThumbnailCache = LRUCache<URL, NSImage>(capacity: 64)
    private static let dragKindThumbnailCache = LRUCache<String, NSImage>(capacity: 32)

    public static func blockDimensions(
        for kind: ClipKind,
        duration: CMTime,
        pixelsPerSecond: CGFloat
    ) -> (width: CGFloat, height: CGFloat) {
        let targetH = kind.presentation.defaultLayerHeight - 6.0
        let rawW = CGFloat(CMTimeGetSeconds(duration)) * pixelsPerSecond
        let targetW = max(minBlockWidth, min(maxBlockWidth, rawW))
        return (targetW, targetH)
    }

    public static func renderImage(
        name: String,
        duration: CMTime,
        kind: ClipKind,
        width: CGFloat,
        height: CGFloat,
        thumbnail: NSImage?
    ) -> NSImage? {
        let clampedW = max(minBlockWidth, min(maxBlockWidth, width))
        let cacheKey = "\(name)_\(kind.rawValue)_\(Int(clampedW))_\(Int(height))_\(thumbnail != nil)"
        if let cached = imageCache[cacheKey] {
            return cached
        }

        let view = TimelineClipBlockPreviewView(
            name: name,
            duration: duration,
            kind: kind,
            width: clampedW,
            height: height,
            thumbnail: thumbnail
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        guard let image = renderer.nsImage else { return nil }
        imageCache[cacheKey] = image
        return image
    }

    public static func registerThumbnail(_ image: NSImage, for url: URL) {
        quickThumbnailCache[url] = image
        dragThumbnailCache.remove(for: url)
    }

    public static func cachedThumbnail(for url: URL) -> NSImage? {
        quickThumbnailCache[url]
    }

    public static func quickThumbnail(for url: URL) -> NSImage? {
        if let cached = quickThumbnailCache[url] {
            return cached
        }
        Task {
            _ = await loadThumbnailAsync(for: url)
        }
        return nil
    }

    public static func loadThumbnailAsync(for url: URL) async -> NSImage? {
        if let cached = quickThumbnailCache[url] {
            return cached
        }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 120)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let (cgImg, _) = try await generator.image(at: time)
            let img = NSImage(cgImage: cgImg, size: NSSize(width: 60, height: 60))
            quickThumbnailCache[url] = img
            dragThumbnailCache.remove(for: url)
            return img
        } catch {
            return nil
        }
    }

    public static func dragThumbnail(for url: URL, type: MediaType) -> NSImage {
        if let cached = dragThumbnailCache[url] {
            return cached
        }
        let thumb: NSImage? = {
            switch type {
            case .video:
                return quickThumbnail(for: url)
            case .image:
                if let cached = quickThumbnailCache[url] {
                    return cached
                }
                if let img = NSImage(contentsOf: url) {
                    quickThumbnailCache[url] = img
                    return img
                }
                return nil
            case .audio:
                return nil
            }
        }()

        let view = MediaDragThumbnailCardView(
            name: url.lastPathComponent,
            type: type,
            thumbnail: thumb
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let img = renderer.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
        dragThumbnailCache[url] = img
        return img
    }

    public static func dragThumbnail(for payload: TimelineDragPayload) -> NSImage {
        switch payload {
        case .media(let asset):
            return dragThumbnail(for: asset.url, type: asset.type)
        case .transition(let preset):
            return TransitionDragSourceNSView.renderCyanOverlayImage(for: preset, width: 100, height: 32)
        case .transitionID:
            return TransitionDragSourceNSView.renderCyanOverlayImage(width: 100, height: 32)
        default:
            let kind = payload.clipKind ?? .effect
            let key = "kind_\(kind.rawValue)"
            if let cached = dragKindThumbnailCache[key] {
                return cached
            }
            let view = MediaDragThumbnailCardView(name: payload.displayName, kind: kind)
            let renderer = ImageRenderer(content: view)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let img = renderer.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
            dragKindThumbnailCache[key] = img
            return img
        }
    }

    public static func clearCache() {
        imageCache.removeAll()
        quickThumbnailCache.removeAll()
        dragThumbnailCache.removeAll()
        dragKindThumbnailCache.removeAll()
    }
}

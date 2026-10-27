import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import Domain

/// Resolves pixel dimensions of video and image assets for auto aspect ratio matching.
public enum TimelineMediaDimensionResolver: Sendable {
    private static let dimensionCache = LRUCache<URL, CGSize>(capacity: 256)
    private static let videoMetadataCache = VideoMetadataCache()

    public static func cachedDimension(for url: URL) -> CGSize? {
        dimensionCache.get(url)
    }

    public static func cacheDimension(_ size: CGSize, for url: URL) {
        dimensionCache.set(size, for: url)
    }

    public static func clearCache() {
        dimensionCache.removeAll()
    }

    public static func resolveDimension(for url: URL, type: MediaType) -> CGSize? {
        if let cached = cachedDimension(for: url) {
            return cached
        }
        switch type {
        case .image:
            if let size = resolveImageDimension(for: url) {
                cacheDimension(size, for: url)
                return size
            }
        case .video:
            if let meta = videoMetadataCache.metadata(for: url) {
                let oriented = meta.naturalSize.applying(meta.transform)
                let size = CGSize(width: abs(oriented.width), height: abs(oriented.height))
                if size.width > 0, size.height > 0 {
                    cacheDimension(size, for: url)
                    return size
                }
            }
            if let size = resolveVideoDimensionSynchronously(for: url) {
                cacheDimension(size, for: url)
                return size
            }
        case .audio:
            return nil
        }
        return nil
    }

    public static func resolveDimensionAsync(for url: URL, type: MediaType) async -> CGSize? {
        if let cached = cachedDimension(for: url) {
            return cached
        }
        switch type {
        case .image:
            return resolveDimension(for: url, type: type)
        case .video:
            if let meta = videoMetadataCache.metadata(for: url) {
                let oriented = meta.naturalSize.applying(meta.transform)
                let size = CGSize(width: abs(oriented.width), height: abs(oriented.height))
                if size.width > 0, size.height > 0 {
                    cacheDimension(size, for: url)
                    return size
                }
            }
            let avAsset = AVURLAsset(url: url)
            if let track = try? await avAsset.loadTracks(withMediaType: .video).first {
                let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
                let transform = (try? await track.load(.preferredTransform)) ?? .identity
                let oriented = naturalSize.applying(transform)
                let size = CGSize(width: abs(oriented.width), height: abs(oriented.height))
                if size.width > 0, size.height > 0 {
                    cacheDimension(size, for: url)
                    let meta = VideoTrackMetadata(transform: transform, naturalSize: naturalSize)
                    videoMetadataCache.store(meta, for: url)
                    return size
                }
            }
        case .audio:
            return nil
        }
        return nil
    }

    private static func resolveImageDimension(for url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        guard let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return nil
        }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let isRotated = orientation >= 5 && orientation <= 8
        return CGSize(width: isRotated ? height : width, height: isRotated ? width : height)
    }

    private static func resolveVideoDimensionSynchronously(for url: URL) -> CGSize? {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let oriented = track.naturalSize.applying(track.preferredTransform)
        let size = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        if size.width > 0, size.height > 0 {
            let meta = VideoTrackMetadata(transform: track.preferredTransform, naturalSize: track.naturalSize)
            videoMetadataCache.store(meta, for: url)
            return size
        }
        return nil
    }
}

import Foundation
import AVFoundation
import AppKit
import Domain

public actor MediaThumbnailService: AssetThumbnailServiceProtocol {
    private let cache = LRUCache<UUID, Data>(capacity: 100)
    private let targetDimension: CGFloat = 200

    public init() {}

    public func generateThumbnailData(for asset: MediaAsset) async throws -> Data? {
        if let cached = cache[asset.id] {
            return cached
        }

        try Task.checkCancellation()

        let data: Data?
        switch asset.type {
        case .video:
            data = try await generateVideoThumbnail(from: asset.url)
        case .image:
            data = generateImageThumbnail(from: asset.url)
        case .audio:
            data = nil
        }

        if let data {
            cache[asset.id] = data
        }
        return data
    }

    private func generateVideoThumbnail(from url: URL) async throws -> Data? {
        let avAsset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: targetDimension, height: targetDimension)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: time)

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    private func generateImageThumbnail(from url: URL) -> Data? {
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        guard nsImage.size.width > 0 && nsImage.size.height > 0 else { return nil }

        let aspectWidth = targetDimension / nsImage.size.width
        let aspectHeight = targetDimension / nsImage.size.height
        let scale = min(aspectWidth, aspectHeight, 1.0)
        let targetSize = NSSize(
            width: max(1, nsImage.size.width * scale),
            height: max(1, nsImage.size.height * scale)
        )

        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        nsImage.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: nsImage.size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}

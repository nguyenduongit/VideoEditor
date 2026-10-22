import Foundation
import AVFoundation
import AppKit
import CoreMedia
import Domain

public actor TimelineThumbnailService: TimelineThumbnailServiceProtocol {
    private let cache = LRUCache<String, Data>(capacity: 128)

    public init() {}

    public func generateThumbnail(for url: URL, at time: CMTime, targetHeight: CGFloat) async -> Data? {
        let key = cacheKey(url: url, time: time)
        if let cached = cache[key] {
            return cached
        }

        if Task.isCancelled { return nil }

        let avAsset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        let height = max(20.0, targetHeight)
        generator.maximumSize = CGSize(width: height * 2.0, height: height)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            if Task.isCancelled { return nil }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.75])
            if let data {
                cache[key] = data
            }
            return data
        } catch {
            return nil
        }
    }

    private func cacheKey(url: URL, time: CMTime) -> String {
        let roundedSeconds = Int((CMTimeGetSeconds(time) * 10).rounded())
        return "\(url.path)_\(roundedSeconds)"
    }
}

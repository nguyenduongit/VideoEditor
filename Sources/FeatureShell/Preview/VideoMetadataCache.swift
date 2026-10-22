import Foundation
import CoreGraphics

struct VideoTrackMetadata: Sendable {
    let transform: CGAffineTransform
    let naturalSize: CGSize
}

final class VideoMetadataCache: @unchecked Sendable {
    static let shared = VideoMetadataCache()
    private let lock = NSLock()
    private var cache: [URL: VideoTrackMetadata] = [:]

    func metadata(for url: URL) -> VideoTrackMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }

    func store(_ meta: VideoTrackMetadata, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache[url] = meta
    }
}

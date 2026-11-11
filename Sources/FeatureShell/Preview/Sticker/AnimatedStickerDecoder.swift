import Foundation
import CoreGraphics
import CoreMedia
import ImageIO
import Domain

/// Bộ giải mã khung hình động GIF và APNG sử dụng ImageIO framework gốc của Apple.
/// Hỗ trợ trích xuất khung hình chính xác theo CMTime, chế độ lặp (Loop/Once) và tốc độ phát.
/// Tuân thủ quy tắc R2.1 (100% Apple SDK), R3.1 và R8.3 của AGENTS.md.
public final class AnimatedStickerDecoder: @unchecked Sendable {
    public struct Frame: Sendable {
        public let image: CGImage
        public let durationSeconds: Double
    }

    private let lock = NSLock()
    private var frames: [Frame] = []
    public private(set) var totalDurationSeconds: Double = 0.0

    public init(data: Data) {
        loadFrames(from: data)
    }

    public init(url: URL) {
        if let data = try? Data(contentsOf: url) {
            loadFrames(from: data)
        }
    }

    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return frames.isEmpty
    }

    private func loadFrames(from data: Data) {
        lock.lock()
        defer { lock.unlock() }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let count = CGImageSourceGetCount(source)
        var loaded: [Frame] = []
        loaded.reserveCapacity(count)
        var total: Double = 0.0
        let frameOptions: CFDictionary = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, frameOptions) else { continue }
            var frameDuration = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] {
                if let gifDict = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    if let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
                        frameDuration = unclamped
                    } else if let delay = gifDict[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
                        frameDuration = delay
                    }
                } else if let pngDict = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
                    if let unclamped = pngDict[kCGImagePropertyAPNGUnclampedDelayTime] as? Double, unclamped > 0 {
                        frameDuration = unclamped
                    } else if let delay = pngDict[kCGImagePropertyAPNGDelayTime] as? Double, delay > 0 {
                        frameDuration = delay
                    }
                }
            }
            if abs(frameDuration - (1.0 / 60.0)) < 0.0002 {
                frameDuration = 1.0 / 60.0
            } else if abs(frameDuration - (1.0 / 30.0)) < 0.0002 {
                frameDuration = 1.0 / 30.0
            }
            let duration = max(0.008, frameDuration)
            loaded.append(Frame(image: cgImage, durationSeconds: duration))
            total += duration
        }

        self.frames = loaded
        let snappedTotal = (total * 60.0).rounded() / 60.0
        self.totalDurationSeconds = max(0.05, abs(total - snappedTotal) < 0.002 ? snappedTotal : total)
    }

    /// Lấy khung hình CGImage tại thời điểm playbackTime trên Timeline
    public func frame(at time: CMTime, loopMode: StickerLoopMode = .loop, speed: Double = 1.0) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }

        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else { return frames.first?.image }

        let adjustedSpeed = max(0.1, speed)
        var elapsed = max(0.0, time.seconds) * adjustedSpeed

        if loopMode == .loop {
            elapsed = elapsed.truncatingRemainder(dividingBy: totalDurationSeconds)
            if elapsed < 0 { elapsed += totalDurationSeconds }
        } else if elapsed >= totalDurationSeconds {
            return frames.last?.image
        }

        let sampleTime = elapsed + 1e-5
        var running: Double = 0.0
        for f in frames {
            running += f.durationSeconds
            if sampleTime < running {
                return f.image
            }
        }
        return frames.first?.image
    }
}


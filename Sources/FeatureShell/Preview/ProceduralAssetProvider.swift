import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import os

/// Tạo và cung cấp URL cho các tài nguyên video thuật toán (procedural video assets) như Màn hình đen (Black Screen).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Func <= 50 dòng) và R8.3 (Thread-safe).
public final class ProceduralAssetProvider: @unchecked Sendable {
    public static let shared = ProceduralAssetProvider()
    private static let logger = Logger(subsystem: "com.videoeditor", category: "ProceduralAssetProvider")
    private let lock = NSLock()
    private var cachedBlackVideoURL: URL?

    public init() {}

    public func blackVideoURL() -> URL {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedBlackVideoURL, FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("procedural_assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let fileURL = cacheDir.appendingPathComponent("black_screen.mp4")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            cachedBlackVideoURL = fileURL
            return fileURL
        }

        generateBlackVideo(at: fileURL)
        cachedBlackVideoURL = fileURL
        return fileURL
    }

    private func generateBlackVideo(at outputURL: URL) {
        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            Self.logger.error("Failed to create AVAssetWriter for black video")
            return
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)

        guard writer.startWriting() else {
            Self.logger.error("AVAssetWriter startWriting failed")
            return
        }
        writer.startSession(atSourceTime: .zero)

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        if let pb = pixelBuffer {
            adaptor.append(pb, withPresentationTime: .zero)
            let frameDuration = CMTime(value: 15, timescale: 30) // 0.5s
            adaptor.append(pb, withPresentationTime: frameDuration)
        }
        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
    }
}

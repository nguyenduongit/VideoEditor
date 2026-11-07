import Foundation
@preconcurrency import AVFoundation
import os

/// Quản lý nạp và cache các file âm thanh đếm số từ `Sources/Voice/` (`number_1.wav` đến `number_99.wav`).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R3.3 (Dịch vụ cache trong FeatureShell).
public final class VoiceAssetCache: @unchecked Sendable {
    public static let shared = VoiceAssetCache()
    private static let logger = Logger(subsystem: "VideoEditor", category: "VoiceAssetCache")

    private let lock = NSLock()
    private var assetCache: [Int: AVURLAsset] = [:]
    private var resolvedVoiceDirectory: URL?

    public init() {
        self.resolvedVoiceDirectory = locateVoiceDirectory()
    }

    /// Trả về đường dẫn file `.wav` cho số tương ứng (1..99).
    public func voiceURL(for number: Int) -> URL? {
        guard let voiceDir = resolvedVoiceDirectory else { return nil }
        let fileURL = voiceDir.appendingPathComponent("number_\(number).wav")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    /// Trả về `AVURLAsset` cho số tương ứng, có cache trong bộ nhớ.
    public func voiceAsset(for number: Int) -> AVURLAsset? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = assetCache[number] {
            return cached
        }

        guard let url = voiceURL(for: number) else {
            Self.logger.warning("Voice file for number \(number) not found")
            return nil
        }

        let asset = AVURLAsset(url: url)
        assetCache[number] = asset
        return asset
    }

    /// Tìm thư mục chứa các file voice.
    private func locateVoiceDirectory() -> URL? {
        let cwd = FileManager.default.currentDirectoryPath
        let projectVoiceDir = URL(fileURLWithPath: cwd).appendingPathComponent("Sources/Voice")
        if FileManager.default.fileExists(atPath: projectVoiceDir.path) {
            return projectVoiceDir
        }

        if let bundleResources = Bundle.main.resourceURL {
            let bundleVoiceDir = bundleResources.appendingPathComponent("Voice")
            if FileManager.default.fileExists(atPath: bundleVoiceDir.path) {
                return bundleVoiceDir
            }
        }

        let contentsResources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Voice")
        if FileManager.default.fileExists(atPath: contentsResources.path) {
            return contentsResources
        }

        return nil
    }
}


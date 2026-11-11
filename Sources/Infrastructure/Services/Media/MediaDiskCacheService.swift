import Foundation
import OSLog

private let cacheLogger = Logger(subsystem: "VideoEditor", category: "MediaDiskCacheService")

/// Dịch vụ lưu trữ đệm tạm thời cho các tài nguyên Audio & Video từ Supabase Storage.
/// Giúp phát và scrub mượt mà 60/120fps trên Timeline mà không gián đoạn do độ trễ mạng.
/// Tuân thủ AGENTS.md (Pure Infrastructure Service, Sendable, File <= 300 dòng).
public final class MediaDiskCacheService: @unchecked Sendable {
    public static let shared = MediaDiskCacheService()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let lock = NSLock()

    public init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheDirectory = caches.appendingPathComponent("CloudMediaCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Trả về URL tệp đã tải về trên đĩa nếu tồn tại.
    public func localCachedURL(for remoteURL: URL) -> URL? {
        let destination = cacheDestination(for: remoteURL)
        return fileManager.fileExists(atPath: destination.path) ? destination : nil
    }

    /// Tải tệp tài nguyên về bộ nhớ đệm nếu chưa có và trả về URL cục bộ.
    public func prepareMediaLocally(from remoteURL: URL) async throws -> URL {
        if let existing = localCachedURL(for: remoteURL) {
            return existing
        }

        let destination = cacheDestination(for: remoteURL)
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        try storeDownloadedItem(from: tempURL, to: destination)
        cacheLogger.info("Đã cache thành công tài nguyên từ \(remoteURL.lastPathComponent) vào đĩa.")
        return destination
    }

    private func storeDownloadedItem(from tempURL: URL, to destination: URL) throws {
        try lock.withLock {
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)
        }
    }

    /// Xóa toàn bộ bộ nhớ đệm đám mây để giải phóng dung lượng đĩa khi cần.
    public func clearCache() {
        lock.withLock {
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func cacheDestination(for url: URL) -> URL {
        let hash = String(format: "%08x", url.absoluteString.hashValue)
        let ext = url.pathExtension.isEmpty ? "media" : url.pathExtension
        let filename = "\(hash)_\(url.lastPathComponent)"
        let sanitized = filename.hasSuffix(".\(ext)") ? filename : "\(filename).\(ext)"
        return cacheDirectory.appendingPathComponent(sanitized)
    }
}


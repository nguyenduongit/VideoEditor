import Foundation
import Domain
import os

/// Dịch vụ quản lý Security-Scoped Bookmarks tuân thủ chuẩn Apple Sandbox trên macOS.
/// Đảm bảo mọi tệp tin mở ngoài Sandbox đều được duy trì quyền truy cập lâu dài.
public final class SecurityScopedBookmarkService: SecurityScopedBookmarkServiceProtocol, @unchecked Sendable {
    public static let shared = SecurityScopedBookmarkService()

    private let lock = NSLock()
    private var activeURLs = Set<URL>()
    private static let logger = Logger(subsystem: "com.videoeditor", category: "SecurityBookmarks")

    public init() {}

    /// Tạo bookmark dữ liệu có cờ bảo mật (Security-Scoped) từ URL đã được cấp quyền.
    public func createBookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Phục hồi URL từ bookmark data đã lưu, tự động cập nhật nếu bookmark bị cũ (stale).
    public func resolveBookmarkData(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (resolvedURL, isStale)
    }

    /// Kích hoạt quyền truy cập tệp bảo mật trước khi thực hiện I/O.
    public func startAccessing(url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let success = url.startAccessingSecurityScopedResource()
        if success {
            activeURLs.insert(url)
            Self.logger.debug("Started security-scoped access: \(url.lastPathComponent, privacy: .public)")
        } else {
            Self.logger.warning("Failed to start security-scoped access for: \(url.path, privacy: .public)")
        }
        return success
    }

    /// Giải phóng quyền truy cập tệp bảo mật khi hoàn tất I/O.
    public func stopAccessing(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        if activeURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            activeURLs.remove(url)
            Self.logger.debug("Stopped security-scoped access: \(url.lastPathComponent, privacy: .public)")
        }
    }
}

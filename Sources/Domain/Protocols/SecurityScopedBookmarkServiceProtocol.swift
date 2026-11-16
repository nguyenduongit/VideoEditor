import Foundation

/// Giao thức quản lý Security-Scoped Bookmarks cho macOS App Sandbox (AGENTS.md Điều 4 & 13).
/// Cho phép tạo, lưu trữ và duy trì quyền truy cập tệp bên ngoài sandbox của ứng dụng.
public protocol SecurityScopedBookmarkServiceProtocol: Sendable {
    func createBookmarkData(for url: URL) throws -> Data
    func resolveBookmarkData(_ data: Data) throws -> (url: URL, isStale: Bool)
    func startAccessing(url: URL) -> Bool
    func stopAccessing(url: URL)
}

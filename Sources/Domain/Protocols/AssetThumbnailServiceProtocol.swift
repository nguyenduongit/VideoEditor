import Foundation

public protocol AssetThumbnailServiceProtocol: Sendable {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data?
}

import Foundation

public struct MediaAsset: Identifiable, Sendable, Hashable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let type: MediaType
    public let createdAt: Date
    public var bookmarkBase64: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        type: MediaType,
        createdAt: Date = Date(),
        bookmarkBase64: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.type = type
        self.createdAt = createdAt
        self.bookmarkBase64 = bookmarkBase64
    }
}

import Foundation

/// Đại diện cho một tài nguyên mẫu trong Thư viện mẫu trực tuyến (Stock Library từ Supabase).
/// Lưu trữ các thuộc tính phân loại, đường dẫn preview, thời lượng và thẻ tag tìm kiếm FTS/JSONB.
public struct StockLibraryItem: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let title: String
    public let category: String
    public let mediaType: String
    public let previewURL: String?
    public let duration: Double?
    public let tags: [String]
    public let isPro: Bool

    public init(
        id: String,
        title: String,
        category: String,
        mediaType: String = "video",
        previewURL: String? = nil,
        duration: Double? = nil,
        tags: [String] = [],
        isPro: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.mediaType = mediaType
        self.previewURL = previewURL
        self.duration = duration
        self.tags = tags
        self.isPro = isPro
    }
}

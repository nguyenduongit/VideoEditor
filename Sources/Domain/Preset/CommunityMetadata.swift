import Foundation

/// Phân loại tài nguyên trong Kho Thư viện Cộng đồng Mở (Unified Community Asset Hub).
/// Hỗ trợ hiện tại: Text, Adjustment, Effect; sẵn sàng mở rộng: Transition, Sticker.
public enum CommunityAssetType: String, Codable, Sendable, CaseIterable, Identifiable {
    case text = "text"
    case adjustment = "adjustment"
    case effect = "effect"
    case transition = "transition"
    case sticker = "sticker"

    public var id: String { rawValue }
}

/// Tùy chọn sắp xếp và lọc danh sách trong Kho Thư viện Cộng đồng.
public enum CommunitySortOption: String, Codable, Sendable, CaseIterable, Identifiable {
    case popular = "Phổ biến"
    case newest = "Mới nhất"
    case mine = "Của tôi"

    public var id: String { rawValue }
}

/// Siêu dữ liệu đóng góp cộng đồng gắn kèm mỗi Preset (Text, Adjustment, Effect, Transition, Sticker).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R5.6 (Tương thích ngược & tiến).
public struct CommunityMetadata: Codable, Sendable, Equatable {
    public var authorID: String
    public var authorName: String
    public var downloadsCount: Int
    public var likesCount: Int
    public var isVerified: Bool
    public var previewURL: String?
    public var assetBundleURL: String?
    public var createdAtTimestamp: Double

    public init(
        authorID: String = "",
        authorName: String = "Cộng đồng",
        downloadsCount: Int = 0,
        likesCount: Int = 0,
        isVerified: Bool = false,
        previewURL: String? = nil,
        assetBundleURL: String? = nil,
        createdAtTimestamp: Double = Date().timeIntervalSince1970
    ) {
        self.authorID = authorID
        self.authorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Cộng đồng" : authorName
        self.downloadsCount = max(0, downloadsCount)
        self.likesCount = max(0, likesCount)
        self.isVerified = isVerified
        self.previewURL = previewURL
        self.assetBundleURL = assetBundleURL
        self.createdAtTimestamp = createdAtTimestamp
    }

    public static let systemDefault = CommunityMetadata(
        authorID: "system",
        authorName: "Hệ thống",
        downloadsCount: 100,
        likesCount: 50,
        isVerified: true,
        createdAtTimestamp: 1700000000
    )

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.authorID = (try? c.decodeIfPresent(String.self, forKey: .authorID)) ?? ""
        let rawName = (try? c.decodeIfPresent(String.self, forKey: .authorName)) ?? "Cộng đồng"
        self.authorName = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Cộng đồng" : rawName
        self.downloadsCount = max(0, (try? c.decodeIfPresent(Int.self, forKey: .downloadsCount)) ?? 0)
        self.likesCount = max(0, (try? c.decodeIfPresent(Int.self, forKey: .likesCount)) ?? 0)
        self.isVerified = (try? c.decodeIfPresent(Bool.self, forKey: .isVerified)) ?? false
        self.previewURL = try? c.decodeIfPresent(String.self, forKey: .previewURL)
        self.assetBundleURL = try? c.decodeIfPresent(String.self, forKey: .assetBundleURL)
        self.createdAtTimestamp = (try? c.decodeIfPresent(Double.self, forKey: .createdAtTimestamp)) ?? 1700000000
    }

    private static let tagPrefix = "__cm:"

    /// Đóng gói siêu dữ liệu cộng đồng thành tag ẩn để tương thích 100% với mọi bảng Supabase hiện có
    public func encodeToTag() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return Self.tagPrefix + data.base64EncodedString()
    }

    /// Tách danh sách tags hiển thị và khôi phục `CommunityMetadata` từ mảng tags lưu trên Supabase
    public static func extract(from rawTags: [String]?, isSystem: Bool) -> (cleanTags: [String], metadata: CommunityMetadata) {
        let list = rawTags ?? []
        var clean: [String] = []
        var decodedMeta: CommunityMetadata?

        for item in list {
            if item.hasPrefix(Self.tagPrefix) {
                let b64 = String(item.dropFirst(Self.tagPrefix.count))
                if let data = Data(base64Encoded: b64),
                   let meta = try? JSONDecoder().decode(CommunityMetadata.self, from: data) {
                    decodedMeta = meta
                }
            } else {
                clean.append(item)
            }
        }

        let finalMeta = decodedMeta ?? (isSystem ? .systemDefault : CommunityMetadata())
        return (clean, finalMeta)
    }
}

/// Quản lý định danh người đóng góp trên thiết bị (Author ID & Author Name) an toàn luồng.
public enum CommunityIdentity {
    private static let authorIDKey = "com.videoeditor.community.authorID"
    private static let authorNameKey = "com.videoeditor.community.authorName"

    public static var currentAuthorID: String {
        if let existing = UserDefaults.standard.string(forKey: authorIDKey), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: authorIDKey)
        return generated
    }

    public static var currentAuthorName: String {
        get {
            let saved = UserDefaults.standard.string(forKey: authorNameKey) ?? ""
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Creator" : trimmed
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                UserDefaults.standard.set(trimmed, forKey: authorNameKey)
            }
        }
    }
}

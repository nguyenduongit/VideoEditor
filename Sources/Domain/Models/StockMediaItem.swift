import Foundation

/// Entity representing a Stock Media Item in the Left Sidebar Media Library.
/// Refers to cloud media assets on Supabase Storage via HTTPS URLs.
/// Complies with AGENTS.md rules (Pure Domain, Sendable, Codable, File <= 300 lines).
public struct StockMediaItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var category: String
    public var type: MediaType
    public var mediaURL: URL
    public var thumbnailURL: URL?
    public var icon: String

    public init(
        id: String,
        name: String,
        category: String,
        type: MediaType,
        mediaURL: URL,
        thumbnailURL: URL? = nil,
        icon: String = "film.fill"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.type = type
        self.mediaURL = mediaURL
        self.thumbnailURL = thumbnailURL
        self.icon = icon
    }

    /// Built-in fallback catalog for offline mode and initial seeding.
    public static let builtInCatalog: [StockMediaItem] = [
        StockMediaItem(
            id: "stock_video_intro",
            name: "Cinematic Intro",
            category: "Stock Videos",
            type: .video,
            mediaURL: URL(string: "https://assets.mixkit.co/videos/preview/mixkit-set-of-plateaus-seen-from-the-sky-in-a-sunset-26070-large.mp4")!,
            icon: "film.fill"
        )
    ]
}


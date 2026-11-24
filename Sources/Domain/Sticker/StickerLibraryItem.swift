import Foundation

/// Dev-authored system sticker entry (`StickerLibraryItem`) supporting inline Vector SVG and animated SVG/GIF/APNG assets.
/// Strictly read-only to end users per AGENTS.md Article 15 (no user preset save/delete or Supabase sync).
/// Complies with AGENTS.md (Pure Domain, 1 Primary Type per file, Sendable, Equatable).
public struct StickerLibraryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: StickerCategory
    public var format: StickerFormat
    public var tags: [String]
    public var defaultDuration: Double
    public var assetPath: String?
    public var systemSymbolFallback: String
    public var config: StickerConfiguration

    public init(
        id: String,
        schemaVersion: Int = 2,
        name: String,
        description: String,
        category: StickerCategory = .emoji,
        format: StickerFormat = .svg,
        tags: [String] = [],
        defaultDuration: Double = 3.0,
        assetPath: String? = nil,
        systemSymbolFallback: String = "face.smiling",
        config: StickerConfiguration? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.category = category
        self.format = format
        self.tags = tags
        self.defaultDuration = max(0.5, min(30.0, defaultDuration))
        self.assetPath = assetPath
        self.systemSymbolFallback = systemSymbolFallback
        self.config = config ?? StickerConfiguration(
            format: format,
            loopMode: .loop,
            playbackSpeed: 1.0,
            sourceURLString: assetPath,
            systemSymbolFallback: systemSymbolFallback
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, name, description, category, format, tags
        case defaultDuration, assetPath, systemSymbolFallback, config
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 2
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Sticker"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(StickerCategory.self, forKey: .category)) ?? .emoji
        let decodedFormat = (try? c.decodeIfPresent(StickerFormat.self, forKey: .format)) ?? .svg
        self.format = decodedFormat
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        let rawDur = (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 3.0
        self.defaultDuration = max(0.5, min(30.0, rawDur))
        let path = try? c.decodeIfPresent(String.self, forKey: .assetPath)
        self.assetPath = path
        let fallback = (try? c.decodeIfPresent(String.self, forKey: .systemSymbolFallback)) ?? "face.smiling"
        self.systemSymbolFallback = fallback
        self.config = (try? c.decodeIfPresent(StickerConfiguration.self, forKey: .config)) ?? StickerConfiguration(
            format: decodedFormat,
            sourceURLString: path,
            systemSymbolFallback: fallback
        )
    }

    public static let systemItems: [StickerLibraryItem] = [
        StickerLibraryItem(
            id: "sticker_animated_flower_leaf",
            name: "Animated Flower & Leaves (SVG)",
            description: "Swaying plant and falling petals animated with pure CSS vector SVG",
            category: .natureHoliday,
            format: .svg,
            tags: ["flower", "leaf", "nature", "animated", "svg", "css"],
            defaultDuration: 3.0,
            systemSymbolFallback: "sparkles",
            config: StickerConfiguration(
                format: .svg,
                loopMode: .loop,
                playbackSpeed: 1.0,
                sourceURLString: "sticker_animated_flower_leaf.apng",
                svgMarkup: animatedFlowerSVGMarkup,
                systemSymbolFallback: "sparkles",
                hasShadow: false,
                shadowColorHex: "#00000040",
                shadowBlur: 10.0,
                shadowDistance: 4.0
            )
        ),
        StickerLibraryItem(
            id: "sticker_animated_xmas_tree",
            name: "Christmas Tree (SVG)",
            description: "Swaying Christmas tree with blinking multicolor lights and falling snow in CSS SVG",
            category: .natureHoliday,
            format: .svg,
            tags: ["xmas", "tree", "christmas", "holiday", "noel", "animated", "svg"],
            defaultDuration: 3.0,
            systemSymbolFallback: "sparkles",
            config: StickerConfiguration(
                format: .svg,
                loopMode: .loop,
                playbackSpeed: 1.0,
                sourceURLString: "sticker_animated_xmas_tree.apng",
                svgMarkup: animatedXmasTreeSVGMarkup,
                systemSymbolFallback: "sparkles",
                hasShadow: false,
                shadowColorHex: "#00000040",
                shadowBlur: 10.0,
                shadowDistance: 4.0
            )
        )
    ] + emojiItems + audioVisualizerItems

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> StickerLibraryItem? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StickerLibraryItem.self, from: data)
    }
}

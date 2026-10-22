import Foundation

public struct ProjectMetadata: Codable, Sendable, Hashable, Equatable {
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        title: String = "Untitled Project",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// The top-level declarative project script representation.
/// Encapsulates metadata, canvas settings, layers, and blocks.
/// Serves as the primary JSON bridge for disk storage, headless scripting, and MCP agents.
public struct ProjectScript: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var metadata: ProjectMetadata
    public var fps: Int32
    public var aspectRatio: CanvasAspectRatio
    public var layers: [LayerScript]
    public var history: [TimelineHistoryRecord]
    public var historyIndex: Int

    public init(
        title: String = "Untitled Project",
        fps: Int32 = TimeRational.defaultFPS,
        aspectRatio: CanvasAspectRatio = .ratio16x9,
        layers: [LayerScript] = [],
        history: [TimelineHistoryRecord] = [],
        historyIndex: Int = 0
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.metadata = ProjectMetadata(title: title)
        self.fps = fps
        self.aspectRatio = aspectRatio
        self.layers = layers
        self.history = history
        self.historyIndex = historyIndex
    }

    public init(
        title: String = "Untitled Project",
        fps: Int32 = TimeRational.defaultFPS,
        aspectRatio: CanvasAspectRatio = .ratio16x9,
        timelineLayers: [TimelineLayer],
        history: [TimelineHistoryRecord] = [],
        historyIndex: Int = 0
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.metadata = ProjectMetadata(title: title)
        self.fps = fps
        self.aspectRatio = aspectRatio
        self.layers = timelineLayers.map { LayerScript(from: $0) }
        self.history = history
        self.historyIndex = historyIndex
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, metadata, fps, aspectRatio, layers, history, historyIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        self.metadata = try container.decodeIfPresent(ProjectMetadata.self, forKey: .metadata) ?? ProjectMetadata()
        self.fps = try container.decodeIfPresent(Int32.self, forKey: .fps) ?? TimeRational.defaultFPS
        self.aspectRatio = try container.decodeIfPresent(CanvasAspectRatio.self, forKey: .aspectRatio) ?? .ratio16x9
        self.layers = try container.decodeIfPresent([LayerScript].self, forKey: .layers) ?? []
        self.history = try container.decodeIfPresent([TimelineHistoryRecord].self, forKey: .history) ?? []
        self.historyIndex = try container.decodeIfPresent(Int.self, forKey: .historyIndex) ?? self.history.count
    }

    public func toTimelineLayers() -> [TimelineLayer] {
        layers.map { $0.toTimelineLayer() }
    }

    public var totalDuration: RationalTime {
        var maxTime = RationalTime.zero
        for layer in layers {
            for clip in layer.clips {
                if clip.timelineRange.end > maxTime {
                    maxTime = clip.timelineRange.end
                }
            }
        }
        return maxTime
    }

    public func findClip(by id: UUID) -> (clip: ClipScript, layerID: UUID)? {
        for layer in layers {
            if let clip = layer.clips.first(where: { $0.id == id }) {
                return (clip, layer.id)
            }
        }
        return nil
    }

    public func toData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(self)
    }

    public func toJSONString(prettyPrinted: Bool = true) throws -> String {
        let data = try toData(prettyPrinted: prettyPrinted)
        return String(decoding: data, as: UTF8.self)
    }

    public static func from(data: Data) throws -> ProjectScript {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectScript.self, from: data)
    }

    public static func from(jsonString: String) throws -> ProjectScript {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid UTF-8 string encoding"
                )
            )
        }
        return try from(data: data)
    }

    public func extractSourceURLs() -> [URL] {
        var urls: [URL] = []
        var seen = Set<URL>()
        for layer in layers {
            for clip in layer.clips {
                if case .file(let url) = clip.source {
                    if !seen.contains(url) {
                        seen.insert(url)
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
}

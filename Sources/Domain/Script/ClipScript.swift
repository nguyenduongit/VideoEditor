import Foundation
import CoreMedia

/// The declarative script model for an individual block on a timeline layer.
/// Fully serializable to/from JSON for project files, automation, and MCP agents.
public struct ClipScript: Identifiable, Codable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var name: String
    public let kind: ClipKind
    public var source: ClipSource
    public var timelineRange: RationalTimeRange
    public var sourceStartTime: RationalTime
    public var maxDuration: RationalTime?
    public var opacity: Double
    public var volume: Double
    public var properties: [String: PropertyValue]

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, source, timelineRange, sourceStartTime, maxDuration, opacity, volume, properties
    }

    public init(
        id: UUID = UUID(),
        name: String,
        kind: ClipKind,
        source: ClipSource,
        timelineRange: RationalTimeRange,
        sourceStartTime: RationalTime = .zero,
        maxDuration: RationalTime? = nil,
        opacity: Double = 1.0,
        volume: Double = 1.0,
        properties: [String: PropertyValue]? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.source = source
        self.timelineRange = timelineRange
        self.sourceStartTime = sourceStartTime
        self.maxDuration = maxDuration
        self.opacity = opacity
        self.volume = volume
        var resolvedProps = properties ?? BuiltInClipPropertyDefaults.properties(for: kind)
        if resolvedProps["opacity"] == nil { resolvedProps["opacity"] = .number(opacity) }
        if resolvedProps["volume"] == nil { resolvedProps["volume"] = .number(volume) }
        self.properties = resolvedProps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(ClipKind.self, forKey: .kind)
        self.source = try container.decode(ClipSource.self, forKey: .source)
        self.timelineRange = try container.decode(RationalTimeRange.self, forKey: .timelineRange)
        self.sourceStartTime = try container.decode(RationalTime.self, forKey: .sourceStartTime)
        self.maxDuration = try container.decodeIfPresent(RationalTime.self, forKey: .maxDuration)
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        self.volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0

        if let decodedProps = try container.decodeIfPresent([String: PropertyValue].self, forKey: .properties) {
            self.properties = decodedProps
        } else {
            var defaults = BuiltInClipPropertyDefaults.properties(for: kind)
            defaults["opacity"] = .number(self.opacity)
            defaults["volume"] = .number(self.volume)
            self.properties = defaults
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(source, forKey: .source)
        try container.encode(timelineRange, forKey: .timelineRange)
        try container.encode(sourceStartTime, forKey: .sourceStartTime)
        try container.encodeIfPresent(maxDuration, forKey: .maxDuration)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(volume, forKey: .volume)
        try container.encode(properties, forKey: .properties)
    }

    public init(from clip: TimelineClip) {
        self.id = clip.id
        self.name = clip.name
        self.kind = clip.kind
        if let mediaURL = clip.mediaURL {
            self.source = .file(url: mediaURL)
        } else {
            switch clip.kind {
            case .text:
                self.source = .text(content: clip.name, style: TextStyleDescriptor())
            case .adjustment:
                self.source = .adjustment
            default:
                self.source = .file(url: URL(fileURLWithPath: "/"))
            }
        }
        self.timelineRange = RationalTimeRange(cmTimeRange: clip.timeRange)
        self.sourceStartTime = RationalTime(cmTime: clip.sourceStartTime)
        self.maxDuration = clip.maxDuration.map { RationalTime(cmTime: $0) }
        self.opacity = clip.properties["opacity"]?.asNumber ?? 1.0
        self.volume = clip.properties["volume"]?.asNumber ?? 1.0
        self.properties = clip.properties
    }

    public func toTimelineClip() -> TimelineClip {
        let mediaURL: URL? = {
            if case .file(let url) = source {
                return url
            }
            return nil
        }()

        return TimelineClip(
            id: id,
            assetID: nil,
            name: name,
            kind: kind,
            timeRange: timelineRange.cmTimeRange,
            maxDuration: maxDuration?.cmTime,
            mediaURL: mediaURL,
            sourceStartTime: sourceStartTime.cmTime,
            properties: properties
        )
    }
}

extension TimelineClip {
    public func toScript() -> ClipScript {
        ClipScript(from: self)
    }
}

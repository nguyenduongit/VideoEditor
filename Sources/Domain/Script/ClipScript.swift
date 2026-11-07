import Foundation
import CoreMedia

/// The declarative script model for an individual block on a timeline layer.
/// Fully serializable to/from JSON for project files, automation, and MCP agents,
/// preserving `mediaURL == nil` (`ClipSource.generated`), `assetID`, `originPresetID`, and `beatMarkers`.
public struct ClipScript: Identifiable, Codable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var assetID: UUID?
    public var name: String
    public let kind: ClipKind
    public var source: ClipSource
    public var timelineRange: RationalTimeRange
    public var sourceStartTime: RationalTime
    public var maxDuration: RationalTime?
    public var opacity: Double
    public var volume: Double
    public var originPresetID: String?
    public var beatMarkers: [AudioBeatMarker]
    public var properties: [String: PropertyValue]

    private enum CodingKeys: String, CodingKey {
        case id, assetID, name, kind, source, timelineRange, sourceStartTime, maxDuration
        case opacity, volume, originPresetID, beatMarkers, properties
    }

    public init(
        id: UUID = UUID(),
        assetID: UUID? = nil,
        name: String,
        kind: ClipKind,
        source: ClipSource,
        timelineRange: RationalTimeRange,
        sourceStartTime: RationalTime = .zero,
        maxDuration: RationalTime? = nil,
        opacity: Double = 1.0,
        volume: Double = 1.0,
        originPresetID: String? = nil,
        beatMarkers: [AudioBeatMarker] = [],
        properties: [String: PropertyValue]? = nil
    ) {
        self.id = id
        self.assetID = assetID
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
        let resolvedOrigin = originPresetID ?? resolvedProps["originPresetId"]?.asString
        if let resolvedOrigin, !resolvedOrigin.isEmpty {
            resolvedProps["originPresetId"] = .string(resolvedOrigin)
        }
        self.originPresetID = resolvedOrigin

        if !beatMarkers.isEmpty, resolvedProps[AudioBeatConfiguration.propertyKey] == nil {
            let beatCfg = AudioBeatConfiguration(mode: .majorOnly, markers: beatMarkers, isVisible: true)
            if let json = beatCfg.encodeToJSON() {
                resolvedProps[AudioBeatConfiguration.propertyKey] = .string(json)
            }
            self.beatMarkers = beatMarkers
        } else if let rawBeat = resolvedProps[AudioBeatConfiguration.propertyKey]?.asString,
                  let decodedBeat = AudioBeatConfiguration.decode(from: rawBeat) {
            self.beatMarkers = decodedBeat.markers
        } else {
            self.beatMarkers = beatMarkers
        }
        self.properties = resolvedProps
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try c.decode(UUID.self, forKey: .id)
        let decodedAssetID = try c.decodeIfPresent(UUID.self, forKey: .assetID)
        let decodedName = try c.decode(String.self, forKey: .name)
        let decodedKind = try c.decode(ClipKind.self, forKey: .kind)
        let decodedSource = try c.decode(ClipSource.self, forKey: .source)
        let decodedRange = try c.decode(RationalTimeRange.self, forKey: .timelineRange)
        let decodedSrcStart = try c.decode(RationalTime.self, forKey: .sourceStartTime)
        let decodedMaxDur = try c.decodeIfPresent(RationalTime.self, forKey: .maxDuration)
        let decodedOpacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        let decodedVolume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        let explicitOrigin = try c.decodeIfPresent(String.self, forKey: .originPresetID)
        let explicitBeats = try c.decodeIfPresent([AudioBeatMarker].self, forKey: .beatMarkers) ?? []
        let decodedProps = try c.decodeIfPresent([String: PropertyValue].self, forKey: .properties)

        self.init(
            id: decodedID,
            assetID: decodedAssetID,
            name: decodedName,
            kind: decodedKind,
            source: decodedSource,
            timelineRange: decodedRange,
            sourceStartTime: decodedSrcStart,
            maxDuration: decodedMaxDur,
            opacity: decodedOpacity,
            volume: decodedVolume,
            originPresetID: explicitOrigin,
            beatMarkers: explicitBeats,
            properties: decodedProps
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(assetID, forKey: .assetID)
        try c.encode(name, forKey: .name)
        try c.encode(kind, forKey: .kind)
        try c.encode(source, forKey: .source)
        try c.encode(timelineRange, forKey: .timelineRange)
        try c.encode(sourceStartTime, forKey: .sourceStartTime)
        try c.encodeIfPresent(maxDuration, forKey: .maxDuration)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(volume, forKey: .volume)
        try c.encodeIfPresent(originPresetID, forKey: .originPresetID)
        if !beatMarkers.isEmpty {
            try c.encode(beatMarkers, forKey: .beatMarkers)
        }
        try c.encode(properties, forKey: .properties)
    }

    public init(from clip: TimelineClip) {
        let resolvedSource: ClipSource
        if let mediaURL = clip.mediaURL, mediaURL.path != "/", !mediaURL.path.isEmpty {
            resolvedSource = .file(url: mediaURL)
        } else {
            switch clip.kind {
            case .text:
                resolvedSource = .text(content: clip.name, style: TextStyleDescriptor())
            case .adjustment:
                resolvedSource = .adjustment
            default:
                resolvedSource = .generated
            }
        }
        let beats = AudioBeatConfiguration.from(clip: clip)?.markers ?? []
        self.init(
            id: clip.id,
            assetID: clip.assetID,
            name: clip.name,
            kind: clip.kind,
            source: resolvedSource,
            timelineRange: RationalTimeRange(cmTimeRange: clip.timeRange),
            sourceStartTime: RationalTime(cmTime: clip.sourceStartTime),
            maxDuration: clip.maxDuration.map { RationalTime(cmTime: $0) },
            opacity: clip.properties["opacity"]?.asNumber ?? 1.0,
            volume: clip.properties["volume"]?.asNumber ?? 1.0,
            originPresetID: clip.originPresetID,
            beatMarkers: beats,
            properties: clip.properties
        )
    }

    public func toTimelineClip() -> TimelineClip {
        let mediaURL: URL? = {
            if case .file(let url) = source, url.path != "/", !url.path.isEmpty {
                return url
            }
            return nil
        }()

        var syncedProps = properties
        if let originPresetID, !originPresetID.isEmpty, syncedProps["originPresetId"] == nil {
            syncedProps["originPresetId"] = .string(originPresetID)
        }
        if !beatMarkers.isEmpty, syncedProps[AudioBeatConfiguration.propertyKey] == nil {
            let beatCfg = AudioBeatConfiguration(mode: .majorOnly, markers: beatMarkers, isVisible: true)
            if let json = beatCfg.encodeToJSON() {
                syncedProps[AudioBeatConfiguration.propertyKey] = .string(json)
            }
        }

        return TimelineClip(
            id: id,
            assetID: assetID,
            name: name,
            kind: kind,
            timeRange: timelineRange.cmTimeRange,
            maxDuration: maxDuration?.cmTime,
            mediaURL: mediaURL,
            sourceStartTime: sourceStartTime.cmTime,
            properties: syncedProps
        )
    }
}

extension TimelineClip {
    public func toScript() -> ClipScript {
        ClipScript(from: self)
    }
}

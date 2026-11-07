import Foundation

/// The declarative script model for a timeline track/layer.
/// Contains track status (`isLocked`, `isHidden`, `isMuted`), all contained clip blocks, and `CutTransition` nodes.
public struct LayerScript: Identifiable, Codable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var name: String
    public let kind: ClipKind
    public var isLocked: Bool
    public var isHidden: Bool
    public var isMuted: Bool
    public var clips: [ClipScript]
    public var transitions: [CutTransition]

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        kind: ClipKind,
        isLocked: Bool = false,
        isHidden: Bool = false,
        isMuted: Bool = false,
        clips: [ClipScript] = [],
        transitions: [CutTransition] = []
    ) {
        self.id = id
        self.name = name ?? "\(kind.title) Track"
        self.kind = kind
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.isMuted = isMuted
        self.clips = clips
            .filter { $0.kind == kind }
            .sorted { $0.timelineRange.start < $1.timelineRange.start }
        self.transitions = transitions
    }

    public init(from layer: TimelineLayer) {
        self.id = layer.id
        self.name = layer.name
        self.kind = layer.kind
        self.isLocked = layer.isLocked
        self.isHidden = layer.isHidden
        self.isMuted = layer.isMuted
        self.clips = layer.clips.map { ClipScript(from: $0) }
        self.transitions = layer.transitions
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        let decodedKind = try c.decode(ClipKind.self, forKey: .kind)
        self.kind = decodedKind
        self.isLocked = (try? c.decodeIfPresent(Bool.self, forKey: .isLocked)) ?? false
        self.isHidden = (try? c.decodeIfPresent(Bool.self, forKey: .isHidden)) ?? false
        self.isMuted = (try? c.decodeIfPresent(Bool.self, forKey: .isMuted)) ?? false
        let rawClips = (try? c.decodeIfPresent([ClipScript].self, forKey: .clips)) ?? []
        self.clips = rawClips
            .filter { $0.kind == decodedKind }
            .sorted { $0.timelineRange.start < $1.timelineRange.start }
        self.transitions = (try? c.decodeIfPresent([CutTransition].self, forKey: .transitions)) ?? []
    }

    public func toTimelineLayer() -> TimelineLayer {
        TimelineLayer(
            id: id,
            name: name,
            kind: kind,
            isLocked: isLocked,
            isHidden: isHidden,
            isMuted: isMuted,
            clips: clips.map { $0.toTimelineClip() },
            transitions: transitions
        )
    }
}

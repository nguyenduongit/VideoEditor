import Foundation

/// The declarative script model for a timeline track/layer.
/// Contains track status (isLocked, isHidden, isMuted) and all contained clip blocks.
public struct LayerScript: Identifiable, Codable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var name: String
    public let kind: ClipKind
    public var isLocked: Bool
    public var isHidden: Bool
    public var isMuted: Bool
    public var clips: [ClipScript]

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        kind: ClipKind,
        isLocked: Bool = false,
        isHidden: Bool = false,
        isMuted: Bool = false,
        clips: [ClipScript] = []
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
    }

    public init(from layer: TimelineLayer) {
        self.id = layer.id
        self.name = layer.name
        self.kind = layer.kind
        self.isLocked = layer.isLocked
        self.isHidden = layer.isHidden
        self.isMuted = layer.isMuted
        self.clips = layer.clips.map { ClipScript(from: $0) }
    }

    public func toTimelineLayer() -> TimelineLayer {
        TimelineLayer(
            id: id,
            name: name,
            kind: kind,
            isLocked: isLocked,
            isHidden: isHidden,
            isMuted: isMuted,
            clips: clips.map { $0.toTimelineClip() }
        )
    }
}

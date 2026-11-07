import Foundation
import CoreMedia

public struct TimelineLayer: Identifiable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var name: String
    public let kind: ClipKind
    public var isLocked: Bool
    public var isHidden: Bool
    public var isMuted: Bool
    public var clips: [TimelineClip]
    public var transitions: [CutTransition]

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        kind: ClipKind,
        isLocked: Bool = false,
        isHidden: Bool = false,
        isMuted: Bool = false,
        clips: [TimelineClip] = [],
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
            .sorted { $0.timeRange.start < $1.timeRange.start }
        self.transitions = transitions
        pruneInvalidTransitions()
    }

    public mutating func sortClips() {
        clips.sort { $0.timeRange.start < $1.timeRange.start }
    }

    /// Checks if a given time range collides with any existing clip on this layer.
    public func hasCollision(with range: CMTimeRange, excludingClipID: UUID? = nil) -> Bool {
        for clip in clips where clip.id != excludingClipID {
            if clip.timeRange.intersection(range).duration > .zero {
                return true
            }
        }
        return false
    }

    /// Clamps proposed start time between previous clip end and next clip start on this layer.
    public func clampStartWithinNeighbors(
        for clipID: UUID,
        proposedStart: CMTime,
        duration: CMTime
    ) -> CMTime {
        let (prev, next) = neighbors(of: clipID)
        var minStart = CMTime.zero
        if let prevEnd = prev?.timeRange.end {
            minStart = CMTimeMaximum(minStart, prevEnd)
        }
        var maxStart = CMTime(seconds: 86400 * 365, preferredTimescale: 600)
        if let nextStart = next?.timeRange.start {
            maxStart = CMTimeSubtract(nextStart, duration)
            if maxStart < minStart {
                maxStart = minStart
            }
        }
        if proposedStart < minStart {
            return minStart
        }
        if proposedStart > maxStart {
            return maxStart
        }
        return proposedStart
    }

    @discardableResult
    public mutating func appendClip(_ clip: TimelineClip) -> Bool {
        guard clip.kind == self.kind else { return false }
        guard !hasCollision(with: clip.timeRange, excludingClipID: clip.id) else { return false }
        clips.append(clip)
        sortClips()
        return true
    }

    public mutating func removeClip(by id: UUID) -> TimelineClip? {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = clips.remove(at: index)
        pruneInvalidTransitions()
        return removed
    }

    /// Tự động loại bỏ các transition mồ côi hoặc không còn nối 2 clip liền kề
    public mutating func pruneInvalidTransitions() {
        let clipIDs = Set(clips.map(\.id))
        transitions.removeAll { t in
            guard clipIDs.contains(t.leadingClipID), clipIDs.contains(t.trailingClipID) else {
                return true
            }
            guard let idx = clips.firstIndex(where: { $0.id == t.leadingClipID }),
                  idx + 1 < clips.count,
                  clips[idx + 1].id == t.trailingClipID else {
                return true
            }
            return false
        }
    }

    public mutating func addOrUpdateTransition(_ transition: CutTransition) {
        if let idx = transitions.firstIndex(where: { $0.id == transition.id || ($0.leadingClipID == transition.leadingClipID && $0.trailingClipID == transition.trailingClipID) }) {
            transitions[idx] = transition
        } else {
            transitions.append(transition)
        }
        pruneInvalidTransitions()
    }

    public mutating func removeTransition(by id: UUID) {
        transitions.removeAll { $0.id == id }
    }

    public func transition(between leadingID: UUID, and trailingID: UUID) -> CutTransition? {
        transitions.first { $0.leadingClipID == leadingID && $0.trailingClipID == trailingID }
    }

    public func transition(by id: UUID) -> CutTransition? {
        transitions.first { $0.id == id }
    }

    /// Returns the immediate neighboring clips along the time axis.
    public func neighbors(of clipID: UUID) -> (previous: TimelineClip?, next: TimelineClip?) {
        guard let currentIndex = clips.firstIndex(where: { $0.id == clipID }) else {
            return (nil, nil)
        }
        let prev = currentIndex > 0 ? clips[currentIndex - 1] : nil
        let next = currentIndex + 1 < clips.count ? clips[currentIndex + 1] : nil
        return (prev, next)
    }
}

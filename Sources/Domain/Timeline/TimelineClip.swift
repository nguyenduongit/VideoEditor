import Foundation
import CoreMedia

public struct TimelineClip: Identifiable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var assetID: UUID?
    public var name: String
    public let kind: ClipKind
    public var timeRange: CMTimeRange
    public let maxDuration: CMTime?
    public var mediaURL: URL?
    public var sourceStartTime: CMTime
    public var properties: [String: PropertyValue]

    public static let minDuration = CMTime(value: 1, timescale: 10) // 0.1s

    public init(
        id: UUID = UUID(),
        assetID: UUID? = nil,
        name: String,
        kind: ClipKind,
        timeRange: CMTimeRange,
        maxDuration: CMTime? = nil,
        mediaURL: URL? = nil,
        sourceStartTime: CMTime = .zero,
        properties: [String: PropertyValue]? = nil
    ) {
        self.id = id
        self.assetID = assetID
        self.name = name
        self.kind = kind
        self.timeRange = timeRange
        self.maxDuration = maxDuration
        self.mediaURL = mediaURL
        self.sourceStartTime = sourceStartTime.timescale > 1 ? sourceStartTime : CMTime(seconds: CMTimeGetSeconds(sourceStartTime), preferredTimescale: 600)
        self.properties = properties ?? BuiltInClipPropertyDefaults.properties(for: kind)
    }

    public mutating func trim(newStart: CMTime, newDuration: CMTime, newSourceStart: CMTime? = nil) {
        let validStart = CMTimeMaximum(newStart, .zero)
        var clampedSourceStart = self.sourceStartTime
        if let newSourceStart {
            clampedSourceStart = CMTimeMaximum(newSourceStart, .zero)
        }

        var clampedDuration = CMTimeMaximum(newDuration, Self.minDuration)
        if let maxDuration {
            let speed = max(0.01, properties["speed"]?.asNumber ?? 1.0)
            let remainingSource = CMTimeMaximum(.zero, maxDuration - clampedSourceStart)
            let maxTimelineSec = CMTimeGetSeconds(remainingSource) / speed
            let maxAvailable = CMTime(seconds: maxTimelineSec, preferredTimescale: max(600, maxDuration.timescale))
            clampedDuration = CMTimeMinimum(clampedDuration, maxAvailable)
            clampedDuration = CMTimeMaximum(clampedDuration, Self.minDuration)
        }

        self.timeRange = CMTimeRange(start: validStart, duration: clampedDuration)
        self.sourceStartTime = clampedSourceStart
    }

    public mutating func shift(to newStart: CMTime) {
        let validStart = CMTimeMaximum(newStart, .zero)
        self.timeRange = CMTimeRange(start: validStart, duration: self.timeRange.duration)
    }

    public func split(at timelineTime: CMTime, newRightID: UUID? = nil) -> (TimelineClip, TimelineClip)? {
        let snappedTime = TimeRational.snapToFrame(time: timelineTime)
        guard snappedTime > timeRange.start && snappedTime < timeRange.end else { return nil }

        let leftDuration = snappedTime - timeRange.start
        let rightDuration = timeRange.end - snappedTime

        guard leftDuration >= Self.minDuration && rightDuration >= Self.minDuration else { return nil }

        var left = self
        left.timeRange = CMTimeRange(start: timeRange.start, duration: leftDuration)

        let speed = max(0.01, properties["speed"]?.asNumber ?? 1.0)
        let rightSourceStart: CMTime
        let isProcedural = properties["isProcedural"]?.asBool ?? false
        if kind.hasFixedSourceDuration && !isProcedural {
            if abs(speed - 1.0) < 0.0001 {
                rightSourceStart = sourceStartTime + leftDuration
            } else {
                let ts = max(600, max(sourceStartTime.timescale, leftDuration.timescale))
                let consumedSourceSec = CMTimeGetSeconds(leftDuration) * speed
                let consumedSource = CMTime(seconds: consumedSourceSec, preferredTimescale: ts)
                rightSourceStart = sourceStartTime + consumedSource
            }
        } else {
            rightSourceStart = .zero
        }
        let right = TimelineClip(
            id: newRightID ?? UUID(),
            assetID: assetID,
            name: name,
            kind: kind,
            timeRange: CMTimeRange(start: snappedTime, duration: rightDuration),
            maxDuration: maxDuration,
            mediaURL: mediaURL,
            sourceStartTime: rightSourceStart,
            properties: properties
        )

        return (left, right)
    }
}

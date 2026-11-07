import Foundation
import CoreMedia

/// Engine tính toán giới hạn co/giãn (trim) đồng loạt cho một nhóm clip được chọn trên Timeline.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ CoreMedia/Foundation) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum TimelineGroupTrimEngine: Sendable {
    public struct TrimLimits: Sendable, Equatable {
        public let minDelta: CMTime
        public let maxDelta: CMTime

        public init(minDelta: CMTime, maxDelta: CMTime) {
            self.minDelta = minDelta
            self.maxDelta = maxDelta
        }

        public var canTrim: Bool {
            minDelta <= maxDelta && (minDelta < .zero || maxDelta > .zero)
        }
    }

    /// Tính toán giới hạn dời phím Trim Trái (Left Trim) cho toàn bộ các clip được chọn.
    /// delta > 0: thu ngắn clip từ bên trái (start tăng, duration giảm).
    /// delta < 0: mở rộng clip về bên trái (start giảm, duration tăng).
    public static func calculateLeftLimits(
        layers: [TimelineLayer],
        selectedClipIDs: Set<UUID>,
        minDuration: CMTime = TimeRational.time(forFrame: 1)
    ) -> TrimLimits {
        guard !selectedClipIDs.isEmpty else {
            return TrimLimits(minDelta: .zero, maxDelta: .zero)
        }

        var groupMinDelta = CMTime(seconds: -86400 * 365, preferredTimescale: 600)
        var groupMaxDelta = CMTime(seconds: 86400 * 365, preferredTimescale: 600)

        for layer in layers {
            let selectedClips = layer.clips.filter { selectedClipIDs.contains($0.id) }
            guard !selectedClips.isEmpty else { continue }
            if layer.isLocked {
                return TrimLimits(minDelta: .zero, maxDelta: .zero)
            }

            for clip in selectedClips {
                let start = clip.timeRange.start
                let dur = clip.timeRange.duration
                let (prev, _) = layer.neighbors(of: clip.id)

                // Thu ngắn tối đa (delta > 0)
                let clipMaxDelta = CMTimeMaximum(.zero, CMTimeSubtract(dur, minDuration))

                // Mở rộng tối đa về trái (delta < 0)
                var clipMinDelta = CMTimeSubtract(.zero, start)
                if let prevEnd = prev?.timeRange.end {
                    let prevBoundaryDelta = CMTimeSubtract(prevEnd, start)
                    clipMinDelta = CMTimeMaximum(clipMinDelta, prevBoundaryDelta)
                }

                if let sourceMinDelta = calculateSourceLeftMinDelta(clip: clip) {
                    clipMinDelta = CMTimeMaximum(clipMinDelta, sourceMinDelta)
                }

                groupMinDelta = CMTimeMaximum(groupMinDelta, clipMinDelta)
                groupMaxDelta = CMTimeMinimum(groupMaxDelta, clipMaxDelta)
            }
        }

        if groupMinDelta > groupMaxDelta {
            return TrimLimits(minDelta: .zero, maxDelta: .zero)
        }
        return TrimLimits(minDelta: groupMinDelta, maxDelta: groupMaxDelta)
    }

    /// Tính toán giới hạn dời phím Trim Phải (Right Trim) cho toàn bộ các clip được chọn.
    /// delta > 0: mở rộng clip về bên phải (duration tăng).
    /// delta < 0: thu ngắn clip từ bên phải (duration giảm).
    public static func calculateRightLimits(
        layers: [TimelineLayer],
        selectedClipIDs: Set<UUID>,
        minDuration: CMTime = TimeRational.time(forFrame: 1)
    ) -> TrimLimits {
        guard !selectedClipIDs.isEmpty else {
            return TrimLimits(minDelta: .zero, maxDelta: .zero)
        }

        var groupMinDelta = CMTime(seconds: -86400 * 365, preferredTimescale: 600)
        var groupMaxDelta = CMTime(seconds: 86400 * 365, preferredTimescale: 600)

        for layer in layers {
            let selectedClips = layer.clips.filter { selectedClipIDs.contains($0.id) }
            guard !selectedClips.isEmpty else { continue }
            if layer.isLocked {
                return TrimLimits(minDelta: .zero, maxDelta: .zero)
            }

            for clip in selectedClips {
                let dur = clip.timeRange.duration
                let end = clip.timeRange.end
                let (_, next) = layer.neighbors(of: clip.id)

                // Thu ngắn tối đa (delta < 0)
                let clipMinDelta = CMTimeSubtract(minDuration, dur)

                // Mở rộng tối đa về phải (delta > 0)
                var clipMaxDelta = CMTime(seconds: 86400 * 365, preferredTimescale: 600)
                if let nextStart = next?.timeRange.start {
                    let nextBoundaryDelta = CMTimeSubtract(nextStart, end)
                    clipMaxDelta = CMTimeMinimum(clipMaxDelta, nextBoundaryDelta)
                }

                if let sourceMaxDelta = calculateSourceRightMaxDelta(clip: clip) {
                    clipMaxDelta = CMTimeMinimum(clipMaxDelta, sourceMaxDelta)
                }

                groupMinDelta = CMTimeMaximum(groupMinDelta, clipMinDelta)
                groupMaxDelta = CMTimeMinimum(groupMaxDelta, clipMaxDelta)
            }
        }

        if groupMinDelta > groupMaxDelta {
            return TrimLimits(minDelta: .zero, maxDelta: .zero)
        }
        return TrimLimits(minDelta: groupMinDelta, maxDelta: groupMaxDelta)
    }

    /// Giới hạn delta thời gian trong khoảng cho phép.
    public static func clamp(delta: CMTime, limits: TrimLimits) -> CMTime {
        guard limits.minDelta <= limits.maxDelta else { return .zero }
        if delta < limits.minDelta { return limits.minDelta }
        if delta > limits.maxDelta { return limits.maxDelta }
        return delta
    }

    // MARK: - Private Helpers

    private static func calculateSourceLeftMinDelta(clip: TimelineClip) -> CMTime? {
        let isProcedural = (clip.properties["isProcedural"]?.asBool ?? false) || (clip.properties["isBeatCounter"]?.asBool ?? false)
        guard clip.kind.hasFixedSourceDuration && !isProcedural else { return nil }
        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let sourceStartTimelineSec = CMTimeGetSeconds(clip.sourceStartTime) / speed
        return CMTime(seconds: -sourceStartTimelineSec, preferredTimescale: 600)
    }

    private static func calculateSourceRightMaxDelta(clip: TimelineClip) -> CMTime? {
        let isProcedural = (clip.properties["isProcedural"]?.asBool ?? false) || (clip.properties["isBeatCounter"]?.asBool ?? false)
        guard clip.kind.hasFixedSourceDuration && !isProcedural, let maxDuration = clip.maxDuration else { return nil }
        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let sourceDurationTimelineSec = CMTimeGetSeconds(clip.timeRange.duration) * speed
        let currentSourceEndSec = CMTimeGetSeconds(clip.sourceStartTime) + sourceDurationTimelineSec
        let remainingSourceSec = max(0.0, CMTimeGetSeconds(maxDuration) - currentSourceEndSec)
        let remainTimelineSec = max(0.0, remainingSourceSec / speed)
        return CMTime(seconds: remainTimelineSec, preferredTimescale: 600)
    }
}


import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public var totalDuration: CMTime {
        var maxEnd: CMTime = .zero
        for layer in layers {
            for clip in layer.clips {
                if clip.timeRange.end > maxEnd {
                    maxEnd = clip.timeRange.end
                }
            }
        }
        return maxEnd
    }

    public func activeVisualClip(at time: CMTime) -> TimelineClip? {
        for layer in layers where !layer.isHidden && layer.kind != .audio {
            for clip in layer.clips {
                let start = clip.timeRange.start
                let end = clip.timeRange.end
                if time >= start && time < end {
                    return clip
                }
            }
        }
        return nil
    }

    public func hasActiveVideoClip(at time: CMTime) -> Bool {
        for layer in layers where !layer.isHidden && layer.kind == .video {
            for clip in layer.clips {
                if time >= clip.timeRange.start && time < clip.timeRange.end {
                    return true
                }
            }
        }
        return false
    }

    public func activeImageClip(at time: CMTime) -> TimelineClip? {
        for layer in layers where !layer.isHidden && layer.kind == .image {
            for clip in layer.clips {
                if time >= clip.timeRange.start && time < clip.timeRange.end {
                    return clip
                }
            }
        }
        return nil
    }
}

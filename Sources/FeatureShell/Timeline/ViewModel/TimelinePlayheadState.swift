import Foundation
import CoreMedia
import Observation
import Domain

@Observable
@MainActor
public final class TimelinePlayheadState {
    public var currentTime: CMTime = .zero
    public var isPlaying: Bool = false
    public var isScrubbing: Bool = false
    public var pixelsPerSecond: CGFloat = 60.0
    public let fps: Int32 = TimeRational.defaultFPS

    public var onSeek: ((CMTime) -> Void)?
    public var onPlayPause: ((Bool) -> Void)?

    public init(initialTime: CMTime = .zero, pixelsPerSecond: CGFloat = 60.0) {
        self.currentTime = TimeRational.snapToFrame(time: initialTime, fps: fps)
        self.pixelsPerSecond = pixelsPerSecond
    }

    public func seek(to time: CMTime, force: Bool = false) {
        let snapped = TimeRational.snapToFrame(time: time, fps: fps)
        if !force {
            guard snapped != currentTime else { return }
        }
        currentTime = snapped
        onSeek?(snapped)
    }

    public func progressTime(to time: CMTime) {
        let snapped = TimeRational.snapToFrame(time: time, fps: fps)
        guard snapped != currentTime else { return }
        currentTime = snapped
    }

    public func stepFrame(by count: Int64) {
        let currentFrame = TimeRational.frameIndex(for: currentTime, fps: fps)
        let targetFrame = max(0, currentFrame + count)
        seek(to: TimeRational.time(forFrame: targetFrame, fps: fps))
    }

    public func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        onPlayPause?(playing)
    }

    public func togglePlayPause() {
        setPlaying(!isPlaying)
    }

    public var timecodeString: String {
        TimeRational.formatTimecode(time: currentTime, fps: fps)
    }

    public var currentX: CGFloat {
        let seconds = CMTimeGetSeconds(currentTime)
        guard seconds.isFinite && !seconds.isNaN else { return 0 }
        return max(0, CGFloat(seconds) * pixelsPerSecond)
    }
}

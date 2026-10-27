import Foundation
import CoreMedia

public enum TimeRational {
    public static let defaultFPS: Int32 = 30
}

/// Tiện ích định dạng Timecode và căn chỉnh khung hình theo FPS.
public typealias TimecodeUtils = TimeRational
public typealias FrameTimeHelper = TimeRational

extension TimeRational {

    public static func snapToFrame(time: CMTime, fps: Int32 = defaultFPS) -> CMTime {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite && !seconds.isNaN else {
            return .zero
        }
        let totalFrames = Int64(round(max(0, seconds) * Double(fps)))
        return CMTime(value: totalFrames, timescale: fps)
    }

    public static func frameIndex(for time: CMTime, fps: Int32 = defaultFPS) -> Int64 {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite && !seconds.isNaN else {
            return 0
        }
        return Int64(round(max(0, seconds) * Double(fps)))
    }

    public static func time(forFrame frame: Int64, fps: Int32 = defaultFPS) -> CMTime {
        CMTime(value: max(0, frame), timescale: fps)
    }

    public static func formatTimecode(time: CMTime, fps: Int32 = defaultFPS) -> String {
        let seconds = max(0, CMTimeGetSeconds(time))
        guard seconds.isFinite && !seconds.isNaN else {
            return "00:00:00:00"
        }

        let totalFrames = Int64(round(seconds * Double(fps)))
        let frames = Int(totalFrames % Int64(fps))
        let totalSeconds = Int(totalFrames / Int64(fps))
        let secs = totalSeconds % 60
        let mins = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        return String(format: "%02d:%02d:%02d:%02d", hours, mins, secs, frames)
    }

    public static func isFrameLevelZoom(pixelsPerSecond: CGFloat, fps: Int32 = defaultFPS) -> Bool {
        let pixelsPerFrame = pixelsPerSecond / CGFloat(fps)
        return pixelsPerFrame >= 6.0
    }
}

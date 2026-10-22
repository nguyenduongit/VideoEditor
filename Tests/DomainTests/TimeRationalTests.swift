import Foundation
import CoreMedia
import Testing
@testable import Domain

struct TimeRationalTests {
    @Test func testSnapToFrame() {
        let t0 = CMTime.zero
        let snapped0 = TimeRational.snapToFrame(time: t0, fps: 30)
        #expect(snapped0.value == 0)
        #expect(snapped0.timescale == 30)

        // 0.0333s is ~1 frame at 30fps
        let t1 = CMTime(seconds: 0.0333, preferredTimescale: 600)
        let snapped1 = TimeRational.snapToFrame(time: t1, fps: 30)
        #expect(snapped1.value == 1)
        #expect(snapped1.timescale == 30)

        // 0.01s * 30 = 0.3 -> snaps to 0
        let tSmall = CMTime(seconds: 0.01, preferredTimescale: 600)
        let snappedSmall = TimeRational.snapToFrame(time: tSmall, fps: 30)
        #expect(snappedSmall.value == 0)

        // 0.02s * 30 = 0.6 -> snaps to 1
        let tRoundUp = CMTime(seconds: 0.02, preferredTimescale: 600)
        let snappedRoundUp = TimeRational.snapToFrame(time: tRoundUp, fps: 30)
        #expect(snappedRoundUp.value == 1)

        // 1.0s at 30fps -> 30 frames
        let t1s = CMTime(seconds: 1.0, preferredTimescale: 600)
        let snapped1s = TimeRational.snapToFrame(time: t1s, fps: 30)
        #expect(snapped1s.value == 30)
    }

    @Test func testFrameIndexAndTimeForFrame() {
        let timeHalfSec = CMTime(seconds: 0.5, preferredTimescale: 600)
        let frameIdx = TimeRational.frameIndex(for: timeHalfSec, fps: 30)
        #expect(frameIdx == 15)

        let reconstructed = TimeRational.time(forFrame: 15, fps: 30)
        #expect(CMTimeGetSeconds(reconstructed) == 0.5)

        let negative = TimeRational.time(forFrame: -5, fps: 30)
        #expect(negative.value == 0)
    }

    @Test func testFormatTimecode() {
        #expect(TimeRational.formatTimecode(time: .zero, fps: 30) == "00:00:00:00")

        let t1Frame = TimeRational.time(forFrame: 1, fps: 30)
        #expect(TimeRational.formatTimecode(time: t1Frame, fps: 30) == "00:00:00:01")

        let t1Sec = TimeRational.time(forFrame: 30, fps: 30)
        #expect(TimeRational.formatTimecode(time: t1Sec, fps: 30) == "00:00:01:00")

        let tComplex = TimeRational.time(forFrame: (3661 * 30) + 12, fps: 30)
        #expect(TimeRational.formatTimecode(time: tComplex, fps: 30) == "01:01:01:12")
    }

    @Test func testIsFrameLevelZoom() {
        // At 30fps: 60 pps = 2 px/frame < 6.0
        #expect(TimeRational.isFrameLevelZoom(pixelsPerSecond: 60, fps: 30) == false)

        // At 30fps: 180 pps = 6.0 px/frame >= 6.0
        #expect(TimeRational.isFrameLevelZoom(pixelsPerSecond: 180, fps: 30) == true)

        // At 30fps: 300 pps = 10.0 px/frame >= 6.0
        #expect(TimeRational.isFrameLevelZoom(pixelsPerSecond: 300, fps: 30) == true)
    }
}

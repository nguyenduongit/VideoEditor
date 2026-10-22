import Testing
import CoreMedia
@testable import Domain

@Suite("TimelineSnapEngineTests")
struct TimelineSnapEngineTests {

    @Test("thresholdTime calculates correctly from pixels and pixelsPerSecond")
    func testThresholdTimeCalculatesCorrectly() {
        let t1 = TimelineSnapEngine.thresholdTime(pixels: 10, pixelsPerSecond: 100)
        #expect(abs(CMTimeGetSeconds(t1) - 0.1) < 0.001)

        let t2 = TimelineSnapEngine.thresholdTime(pixels: 10, pixelsPerSecond: 50)
        #expect(abs(CMTimeGetSeconds(t2) - 0.2) < 0.001)

        let tZero = TimelineSnapEngine.thresholdTime(pixels: 10, pixelsPerSecond: 0)
        #expect(abs(CMTimeGetSeconds(tZero) - 0.1) < 0.001)
    }

    @Test("snapPoint snaps to candidate when within threshold")
    func testSnapPointSnapsWithinThreshold() {
        let candidates = [
            CMTime(seconds: 0.0, preferredTimescale: 600),
            CMTime(seconds: 5.0, preferredTimescale: 600),
            CMTime(seconds: 10.0, preferredTimescale: 600)
        ]
        let threshold = CMTime(seconds: 0.1, preferredTimescale: 600)

        // Point at 4.95 is within 0.1s of 5.0 -> snaps to 5.0
        let (snapped1, didSnap1) = TimelineSnapEngine.snapPoint(
            time: CMTime(seconds: 4.95, preferredTimescale: 600),
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnap1)
        #expect(snapped1 == CMTime(seconds: 5.0, preferredTimescale: 600))

        // Point at 5.06 is within 0.1s of 5.0 -> snaps to 5.0
        let (snapped2, didSnap2) = TimelineSnapEngine.snapPoint(
            time: CMTime(seconds: 5.06, preferredTimescale: 600),
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnap2)
        #expect(snapped2 == CMTime(seconds: 5.0, preferredTimescale: 600))
    }

    @Test("snapPoint does not snap when outside threshold")
    func testSnapPointDoesNotSnapOutsideThreshold() {
        let candidates = [
            CMTime(seconds: 5.0, preferredTimescale: 600)
        ]
        let threshold = CMTime(seconds: 0.1, preferredTimescale: 600)
        let target = CMTime(seconds: 5.15, preferredTimescale: 600)

        let (snapped, didSnap) = TimelineSnapEngine.snapPoint(
            time: target,
            candidates: candidates,
            threshold: threshold
        )
        #expect(!didSnap)
        #expect(snapped == target)
    }

    @Test("snapClipMove snaps START edge to matching candidate")
    func testSnapClipMoveStartEdge() {
        let candidates = [
            CMTime(seconds: 0.0, preferredTimescale: 600),
            CMTime(seconds: 12.0, preferredTimescale: 600)
        ]
        let threshold = CMTime(seconds: 0.15, preferredTimescale: 600)

        // Proposed start is 12.08, duration is 5s
        let (snappedStart, didSnap) = TimelineSnapEngine.snapClipMove(
            proposedStart: CMTime(seconds: 12.08, preferredTimescale: 600),
            duration: CMTime(seconds: 5.0, preferredTimescale: 600),
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnap)
        #expect(snappedStart == CMTime(seconds: 12.0, preferredTimescale: 600))
    }

    @Test("snapClipMove snaps END edge when start does not snap")
    func testSnapClipMoveEndEdge() {
        let candidates = [
            CMTime(seconds: 10.0, preferredTimescale: 600)
        ]
        let threshold = CMTime(seconds: 0.15, preferredTimescale: 600)

        // Proposed start is 5.92, duration is 4.0 -> proposed end is 9.92 (0.08s away from 10.0)
        let (snappedStart, didSnap) = TimelineSnapEngine.snapClipMove(
            proposedStart: CMTime(seconds: 5.92, preferredTimescale: 600),
            duration: CMTime(seconds: 4.0, preferredTimescale: 600),
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnap)
        // End snaps to 10.0, so start should be 10.0 - 4.0 = 6.0
        #expect(abs(CMTimeGetSeconds(snappedStart) - 6.0) < 0.001)
    }

    @Test("snapTrimStart respects min and max bounds")
    func testSnapTrimStartRespectsBounds() {
        let candidates = [CMTime(seconds: 2.0, preferredTimescale: 600)]
        let threshold = CMTime(seconds: 0.2, preferredTimescale: 600)

        let result = TimelineSnapEngine.snapTrimStart(
            proposedStart: CMTime(seconds: 2.05, preferredTimescale: 600),
            candidates: candidates,
            threshold: threshold,
            minStart: CMTime(seconds: 0.0, preferredTimescale: 600),
            maxStart: CMTime(seconds: 5.0, preferredTimescale: 600)
        )
        #expect(result == CMTime(seconds: 2.0, preferredTimescale: 600))
    }

    @Test("snapTrimEnd respects min and max bounds")
    func testSnapTrimEndRespectsBounds() {
        let candidates = [CMTime(seconds: 8.0, preferredTimescale: 600)]
        let threshold = CMTime(seconds: 0.2, preferredTimescale: 600)

        let result = TimelineSnapEngine.snapTrimEnd(
            proposedEnd: CMTime(seconds: 7.95, preferredTimescale: 600),
            candidates: candidates,
            threshold: threshold,
            minEnd: CMTime(seconds: 3.0, preferredTimescale: 600),
            maxEnd: CMTime(seconds: 10.0, preferredTimescale: 600)
        )
        #expect(result == CMTime(seconds: 8.0, preferredTimescale: 600))
    }
}

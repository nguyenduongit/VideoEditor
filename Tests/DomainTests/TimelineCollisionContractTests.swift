import Foundation
import CoreMedia
import Testing
@testable import Domain

struct TimelineCollisionContractTests {
    @Test func testAdjacentAbuttingRangesDoNotCollide() {
        // [0, 5] and [5, 10] abut at 5.0s, which is not a collision
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )
        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])

        let abuttingRange = CMTimeRange(
            start: CMTime(seconds: 5, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        #expect(!layer.hasCollision(with: abuttingRange))
    }

    @Test func testOverlappingRangeDetectedAsCollision() {
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 2, preferredTimescale: 600),
                duration: CMTime(seconds: 6, preferredTimescale: 600)
            )
        )
        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])

        // [3, 5] completely inside [2, 8]
        let insideRange = CMTimeRange(
            start: CMTime(seconds: 3, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )
        #expect(layer.hasCollision(with: insideRange))

        // [0, 3] overlaps head of [2, 8]
        let headOverlap = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        #expect(layer.hasCollision(with: headOverlap))

        // [7, 10] overlaps tail of [2, 8]
        let tailOverlap = CMTimeRange(
            start: CMTime(seconds: 7, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        #expect(layer.hasCollision(with: tailOverlap))
    }

    @Test func testExcludingSelfClipIgnoresSelfCollision() {
        let clipID = UUID()
        let clip1 = TimelineClip(
            id: clipID,
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 2, preferredTimescale: 600),
                duration: CMTime(seconds: 4, preferredTimescale: 600)
            )
        )
        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])

        #expect(!layer.hasCollision(with: clip1.timeRange, excludingClipID: clipID))
    }

    @Test func testEmptyLayerHasZeroCollisions() {
        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [])
        let range = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 100, preferredTimescale: 600)
        )
        #expect(!layer.hasCollision(with: range))
    }

    @Test func testGroupMoveSingleSourceOfTruthInvariants() {
        // Test that group move respects boundary limits strictly
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 10, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )
        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])

        let limits = TimelineGroupMoveEngine.calculateLimits(
            layers: [layer],
            selectedClipIDs: [clip1.id]
        )

        #expect(limits.canMove)
        #expect(CMTimeGetSeconds(limits.minDelta) == -10.0)

        // Cannot move past zero
        let clamped = TimelineGroupMoveEngine.clamp(
            delta: CMTime(seconds: -15, preferredTimescale: 600),
            limits: limits
        )
        #expect(CMTimeGetSeconds(clamped) == -10.0)
    }
}

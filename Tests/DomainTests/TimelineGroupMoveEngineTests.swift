import Foundation
import CoreMedia
import Testing
@testable import Domain

struct TimelineGroupMoveEngineTests {
    @Test func testTwoClipsInDifferentLayersClearPath() {
        let clip1 = TimelineClip(name: "V1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)))
        let clip2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 3, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)))

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [clip2])

        let limits = TimelineGroupMoveEngine.calculateLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [clip1.id, clip2.id]
        )

        // Clip 2 starts at 3s, so group cannot move left more than 3s (hits t=0)
        #expect(CMTimeGetSeconds(limits.minDelta) == -3.0)
        // No obstacles to the right
        #expect(CMTimeGetSeconds(limits.maxDelta) > 1000.0)
        #expect(limits.canMove)

        // Clamping check
        let clampedProposed = TimelineGroupMoveEngine.clamp(
            delta: CMTime(seconds: -10, preferredTimescale: 600),
            limits: limits
        )
        #expect(CMTimeGetSeconds(clampedProposed) == -3.0)
    }

    @Test func testBlockedByUnselectedClipInOneLayer() {
        // Layer 0: S1 [5, 10], U1 [12, 16] -> S1 maxDelta = +2s
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)))
        let u1 = TimelineClip(name: "U1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 12, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)))

        // Layer 1: S2 [3, 8], U2 [25, 30] -> S2 maxDelta = +17s
        let s2 = TimelineClip(name: "S2", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 3, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)))
        let u2 = TimelineClip(name: "U2", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 25, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)))

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [s1, u1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [s2, u2])

        let limits = TimelineGroupMoveEngine.calculateLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [s1.id, s2.id]
        )

        // S1 is blocked at +2s by U1. S2 has +17s. Group maxDelta MUST be +2s!
        #expect(abs(CMTimeGetSeconds(limits.maxDelta) - 2.0) < 0.001)
        // Min delta is -3s (S2 reaches 0s)
        #expect(abs(CMTimeGetSeconds(limits.minDelta) - (-3.0)) < 0.001)

        let clampedExceeded = TimelineGroupMoveEngine.clamp(
            delta: CMTime(seconds: 5, preferredTimescale: 600),
            limits: limits
        )
        #expect(abs(CMTimeGetSeconds(clampedExceeded) - 2.0) < 0.001)
    }

    @Test func testTwoSelectedClipsInSameLayerDoNotBlockEachOther() {
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))) // [2, 5]
        let s2 = TimelineClip(name: "S2", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 6, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))) // [6, 10]
        let u1 = TimelineClip(name: "U1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 14, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600))) // [14, 16]

        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [s1, s2, u1])

        let limits = TimelineGroupMoveEngine.calculateLimits(
            layers: [layer],
            selectedClipIDs: [s1.id, s2.id]
        )

        // S2 is closest to U1: 14 - 10 = +4s maxDelta. S1 does not block S2 and S2 does not block S1.
        #expect(abs(CMTimeGetSeconds(limits.maxDelta) - 4.0) < 0.001)
        // Left limit: S1 starts at 2s, so minDelta is -2s.
        #expect(abs(CMTimeGetSeconds(limits.minDelta) - (-2.0)) < 0.001)
    }

    @Test func testUnselectedClipTrappedBetweenSelectedClipsBlocksMovement() {
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))) // [2, 5]
        let u1 = TimelineClip(name: "U1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600))) // [5, 7]
        let s2 = TimelineClip(name: "S2", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 7, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))) // [7, 10]

        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [s1, u1, s2])

        let limits = TimelineGroupMoveEngine.calculateLimits(
            layers: [layer],
            selectedClipIDs: [s1.id, s2.id]
        )

        // S1 touches U1 on right (maxDelta = 0). S2 touches U1 on left (minDelta = 0).
        #expect(limits.minDelta == .zero)
        #expect(limits.maxDelta == .zero)
        #expect(!limits.canMove)
    }

    @Test func testLockedLayerBlocksGroupMove() {
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)))
        let s2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 3, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)))

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, isLocked: true, clips: [s1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, isLocked: false, clips: [s2])

        let limits = TimelineGroupMoveEngine.calculateLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [s1.id, s2.id]
        )

        #expect(!limits.canMove)
        #expect(limits.minDelta == .zero)
        #expect(limits.maxDelta == .zero)
    }
}

import Testing
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("TimelinePlayheadSnapTests")
@MainActor
struct TimelinePlayheadSnapTests {

    private func makeViewModelWithClip() -> (TimelineViewModel, TimelineClip, UUID) {
        let vm = TimelineViewModel()
        let clipRange = CMTimeRange(
            start: CMTime(value: 5, timescale: 1),
            duration: CMTime(value: 10, timescale: 1)
        )
        let clip = TimelineClip(
            assetID: UUID(),
            name: "Clip 1",
            kind: .video,
            timeRange: clipRange,
            mediaURL: nil
        )
        let layer = TimelineLayer(name: "Video 1", kind: .video, clips: [clip])
        vm.layers = [layer]
        return (vm, clip, layer.id)
    }

    @Test func testSnapCandidatesIncludesPlayheadTime() {
        let (vm, clip, _) = makeViewModelWithClip()
        let playhead = CMTime(value: 8, timescale: 1)

        // When includePlayhead is true and playheadTime is provided
        let candidatesWithPlayhead = vm.snapCandidateTimes(
            excludingClipID: clip.id,
            playheadTime: playhead,
            includePlayhead: true
        )
        #expect(candidatesWithPlayhead.contains(playhead))
        #expect(candidatesWithPlayhead.contains(.zero))

        // When includePlayhead is false (for playhead scrubbing)
        let candidatesForPlayhead = vm.snapCandidateTimes(
            excludingClipID: nil,
            playheadTime: playhead,
            includePlayhead: false
        )
        #expect(!candidatesForPlayhead.contains(playhead))
        #expect(candidatesForPlayhead.contains(clip.timeRange.start))
        #expect(candidatesForPlayhead.contains(clip.timeRange.end))
        #expect(candidatesForPlayhead.contains(.zero))
    }

    @Test func testPlayheadSnapsToClipEdges() {
        let (vm, clip, _) = makeViewModelWithClip()
        let pps: CGFloat = 100.0 // 100 pixels per second -> 10px = 0.1s threshold
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pps)
        let candidates = vm.snapCandidateTimes(includePlayhead: false)

        // 1. Playhead near clip START (5.0s): 5.05s is within 0.1s threshold
        let nearStart = CMTime(seconds: 5.05, preferredTimescale: 600)
        let (snappedStart, didSnapStart) = TimelineSnapEngine.snapPoint(
            time: nearStart,
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnapStart)
        #expect(snappedStart == clip.timeRange.start)

        // 2. Playhead near clip END (15.0s): 14.96s is within 0.1s threshold
        let nearEnd = CMTime(seconds: 14.96, preferredTimescale: 600)
        let (snappedEnd, didSnapEnd) = TimelineSnapEngine.snapPoint(
            time: nearEnd,
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnapEnd)
        #expect(snappedEnd == clip.timeRange.end)

        // 3. Playhead far from clip edges (7.0s): beyond 0.1s threshold
        let far = CMTime(seconds: 7.0, preferredTimescale: 600)
        let (snappedFar, didSnapFar) = TimelineSnapEngine.snapPoint(
            time: far,
            candidates: candidates,
            threshold: threshold
        )
        #expect(!didSnapFar)
        #expect(snappedFar == far)
    }

    @Test func testClipMoveSnapsToPlayhead() {
        let vm = TimelineViewModel()
        let playhead = CMTime(value: 8, timescale: 1) // Playhead at 8s
        let pps: CGFloat = 100.0
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pps)

        let movingClipID = UUID()
        let clipDuration = CMTime(value: 4, timescale: 1) // 4s clip
        let candidates = vm.snapCandidateTimes(
            excludingClipID: movingClipID,
            playheadTime: playhead,
            includePlayhead: true
        )

        // 1. Moving clip START near playhead (proposedStart = 8.04s)
        let proposedStartNearPlayhead = CMTime(seconds: 8.04, preferredTimescale: 600)
        let (snappedStart, didSnapStart) = TimelineSnapEngine.snapClipMove(
            proposedStart: proposedStartNearPlayhead,
            duration: clipDuration,
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnapStart)
        #expect(snappedStart == playhead)

        // 2. Moving clip END near playhead (proposedStart = 4.05s -> proposedEnd = 8.05s)
        let proposedStartForEndNearPlayhead = CMTime(seconds: 4.05, preferredTimescale: 600)
        let (snappedForEnd, didSnapEnd) = TimelineSnapEngine.snapClipMove(
            proposedStart: proposedStartForEndNearPlayhead,
            duration: clipDuration,
            candidates: candidates,
            threshold: threshold
        )
        #expect(didSnapEnd)
        #expect(snappedForEnd + clipDuration == playhead)
    }

    @Test func testClipTrimSnapsToPlayhead() {
        let playhead = CMTime(value: 12, timescale: 1) // Playhead at 12s
        let candidates = [.zero, playhead]
        let pps: CGFloat = 100.0
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pps)

        // Trim left to near playhead (11.95s -> 12.0s)
        let proposedTrimStart = CMTime(seconds: 11.95, preferredTimescale: 600)
        let snappedStart = TimelineSnapEngine.snapTrimStart(
            proposedStart: proposedTrimStart,
            candidates: candidates,
            threshold: threshold,
            minStart: .zero,
            maxStart: CMTime(value: 20, timescale: 1)
        )
        #expect(snappedStart == playhead)

        // Trim right to near playhead (12.05s -> 12.0s)
        let proposedTrimEnd = CMTime(seconds: 12.05, preferredTimescale: 600)
        let snappedEnd = TimelineSnapEngine.snapTrimEnd(
            proposedEnd: proposedTrimEnd,
            candidates: candidates,
            threshold: threshold,
            minEnd: CMTime(value: 5, timescale: 1),
            maxEnd: CMTime(value: 30, timescale: 1)
        )
        #expect(snappedEnd == playhead)
    }
}

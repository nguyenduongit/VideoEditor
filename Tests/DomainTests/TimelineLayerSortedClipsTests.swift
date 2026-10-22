import Testing
import CoreMedia
import Foundation
@testable import Domain
@testable import FeatureShell

@Suite("TimelineLayerSortedClipsTests")
@MainActor
struct TimelineLayerSortedClipsTests {

    private func makeClip(startSeconds: Double, durationSeconds: Double = 5.0, name: String = "Clip") -> TimelineClip {
        TimelineClip(
            name: name,
            kind: .video,
            timeRange: CMTimeRange(
                start: CMTime(seconds: startSeconds, preferredTimescale: 600),
                duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
            )
        )
    }

    @Test func testInitSortsClipsChronologically() {
        let clip10s = makeClip(startSeconds: 10.0, name: "Clip10")
        let clip2s = makeClip(startSeconds: 2.0, name: "Clip2")
        let clip25s = makeClip(startSeconds: 25.0, name: "Clip25")
        let clip0s = makeClip(startSeconds: 0.0, name: "Clip0")

        let layer = TimelineLayer(
            kind: .video,
            clips: [clip10s, clip2s, clip25s, clip0s]
        )

        #expect(layer.clips.count == 4)
        #expect(layer.clips[0].id == clip0s.id)
        #expect(layer.clips[1].id == clip2s.id)
        #expect(layer.clips[2].id == clip10s.id)
        #expect(layer.clips[3].id == clip25s.id)
    }

    @Test func testAppendClipMaintainsSortedOrder() {
        let clip10s = makeClip(startSeconds: 10.0, name: "Clip10")
        var layer = TimelineLayer(kind: .video, clips: [clip10s])

        let clip2s = makeClip(startSeconds: 2.0, name: "Clip2")
        let added = layer.appendClip(clip2s)

        #expect(added)
        #expect(layer.clips.count == 2)
        #expect(layer.clips[0].id == clip2s.id)
        #expect(layer.clips[1].id == clip10s.id)
    }

    @Test func testNeighborsHelperReturnsCorrectSurroundingClips() {
        let clip2s = makeClip(startSeconds: 2.0, name: "Clip2")
        let clip10s = makeClip(startSeconds: 10.0, name: "Clip10")
        let clip20s = makeClip(startSeconds: 20.0, name: "Clip20")

        let layer = TimelineLayer(kind: .video, clips: [clip10s, clip2s, clip20s])

        // First clip (2s): previous is nil, next is clip10s
        let (firstPrev, firstNext) = layer.neighbors(of: clip2s.id)
        #expect(firstPrev == nil)
        #expect(firstNext?.id == clip10s.id)

        // Middle clip (10s): previous is clip2s, next is clip20s
        let (midPrev, midNext) = layer.neighbors(of: clip10s.id)
        #expect(midPrev?.id == clip2s.id)
        #expect(midNext?.id == clip20s.id)

        // Last clip (20s): previous is clip10s, next is nil
        let (lastPrev, lastNext) = layer.neighbors(of: clip20s.id)
        #expect(lastPrev?.id == clip10s.id)
        #expect(lastNext == nil)

        // Non-existent clip
        let (nonePrev, noneNext) = layer.neighbors(of: UUID())
        #expect(nonePrev == nil)
        #expect(noneNext == nil)
    }

    @Test func testTrimClipAfterUnsortedInsertionDoesNotBlock() {
        let vm = TimelineViewModel()
        let clip10s = makeClip(startSeconds: 10.0, durationSeconds: 5.0, name: "Clip10")
        let clip2s = makeClip(startSeconds: 2.0, durationSeconds: 4.0, name: "Clip2")

        let layer = TimelineLayer(kind: .video, clips: [clip10s, clip2s])
        vm.layers = [layer]

        // Clip2 (start 2s, duration 4s -> ends at 6s) should be able to trim left to 1s
        // without being blocked by Clip10 (which starts at 10s).
        let newStart = CMTime(seconds: 1.0, preferredTimescale: 600)
        let newDuration = CMTime(seconds: 5.0, preferredTimescale: 600) // 1s..6s

        vm.trimClip(
            clipID: clip2s.id,
            in: layer.id,
            newStart: newStart,
            newDuration: newDuration
        )

        let updatedClips = vm.layers[0].clips
        #expect(updatedClips.count == 2)
        #expect(updatedClips[0].id == clip2s.id)
        #expect(updatedClips[0].timeRange.start == newStart)
        #expect(updatedClips[1].id == clip10s.id)
    }
}

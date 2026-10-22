import Foundation
import CoreMedia
import Testing
@testable import Domain

struct TimelineModelTests {
    @Test func testClipKindProperties() {
        #expect(ClipKind.video.hasFixedSourceDuration == true)
        #expect(ClipKind.audio.hasFixedSourceDuration == true)
        #expect(ClipKind.image.hasFixedSourceDuration == false)
        #expect(ClipKind.text.hasFixedSourceDuration == false)
        #expect(ClipKind.adjustment.hasFixedSourceDuration == false)

        #expect(ClipKind.video.isMediaSized == true)
        #expect(ClipKind.audio.isMediaSized == true)
        #expect(ClipKind.image.isMediaSized == true)
        #expect(ClipKind.text.isMediaSized == false)
        #expect(ClipKind.adjustment.isMediaSized == false)
    }

    @Test func testClipTrimmingBoundedByMaxDuration() {
        let maxDur = CMTime(value: 10, timescale: 1)
        var clip = TimelineClip(
            name: "Video Clip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            maxDuration: maxDur
        )

        // Try to trim beyond maxDuration
        clip.trim(newStart: .zero, newDuration: CMTime(value: 15, timescale: 1))
        #expect(clip.timeRange.duration == maxDur)

        // Trim shorter
        clip.trim(newStart: CMTime(value: 2, timescale: 1), newDuration: CMTime(value: 3, timescale: 1))
        #expect(clip.timeRange.start == CMTime(value: 2, timescale: 1))
        #expect(clip.timeRange.duration == CMTime(value: 3, timescale: 1))
    }

    @Test func testClipTrimmingUnboundedForText() {
        var clip = TimelineClip(
            name: "Text Clip",
            kind: .text,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            maxDuration: nil
        )

        // Can expand freely
        clip.trim(newStart: .zero, newDuration: CMTime(value: 100, timescale: 1))
        #expect(clip.timeRange.duration == CMTime(value: 100, timescale: 1))
    }

    @Test func testLayerSingleKindIntegrity() {
        var videoLayer = TimelineLayer(kind: .video)
        let videoClip = TimelineClip(name: "V1", kind: .video, timeRange: .zero)
        let audioClip = TimelineClip(name: "A1", kind: .audio, timeRange: .zero)

        #expect(videoLayer.appendClip(videoClip) == true)
        #expect(videoLayer.appendClip(audioClip) == false)
        #expect(videoLayer.clips.count == 1)
        #expect(videoLayer.clips[0].kind == .video)
    }
}

import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

final class MockAudioAlignmentService: AudioAlignmentServiceProtocol, @unchecked Sendable {
    var resultToReturn: AudioAlignmentResult?

    init(resultToReturn: AudioAlignmentResult?) {
        self.resultToReturn = resultToReturn
    }

    func calculateAlignmentOffset(sourceURL1: URL, sourceURL2: URL) async -> AudioAlignmentResult? {
        resultToReturn
    }
}

@Suite("AudioAlignmentTests")
@MainActor
struct AudioAlignmentTests {

    @Test("canSyncAudio is only true when exactly 2 media clips with audio/video are selected")
    func testCanSyncAudioSelectionRules() {
        let clipVideo = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        let clipAudio = TimelineClip(
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/audio.m4a")
        )
        let clipText = TimelineClip(
            name: "Title",
            kind: .text,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )

        let layerVideo = TimelineLayer(name: "Video Layer", kind: .video, clips: [clipVideo])
        let layerAudio = TimelineLayer(name: "Audio Layer", kind: .audio, clips: [clipAudio])
        let layerText = TimelineLayer(name: "Text Layer", kind: .text, clips: [clipText])

        let vm = TimelineViewModel(initialLayers: [layerVideo, layerAudio, layerText])

        // 0 clips selected
        #expect(vm.canSyncAudio == false)

        // 1 clip selected
        vm.selectClip(clipVideo.id)
        #expect(vm.canSyncAudio == false)

        // 2 clips selected: Video + Text (Text has no audio)
        vm.selectClip(clipText.id, isCmdPressed: true)
        #expect(vm.canSyncAudio == false)

        // 2 clips selected: Video + Audio (both valid media URLs)
        vm.clearSelection()
        vm.selectClip(clipVideo.id)
        vm.selectClip(clipAudio.id, isCmdPressed: true)
        #expect(vm.canSyncAudio == true)

        // 3 clips selected
        vm.selectClip(clipText.id, isCmdPressed: true)
        #expect(vm.canSyncAudio == false)
    }

    @Test("syncSelectedAudio applies moveClip and supports full Undo/Redo")
    func testSyncSelectedAudioAppliesMoveClipWithUndoRedo() async {
        let clipVideo = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        let clipAudio = TimelineClip(
            name: "Song 1",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 8, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/song.mp3")
        )

        let layerVideo = TimelineLayer(name: "V1", kind: .video, clips: [clipVideo])
        let layerAudio = TimelineLayer(name: "A1", kind: .audio, clips: [clipAudio])

        let mockService = MockAudioAlignmentService(
            resultToReturn: AudioAlignmentResult(
                offsetSeconds: 3.0,
                correlation: 0.80,
                score: 8.0,
                isMatch: true
            )
        )

        let vm = TimelineViewModel(
            audioAlignmentService: mockService,
            initialLayers: [layerVideo, layerAudio]
        )

        vm.selectClip(clipVideo.id)
        vm.selectClip(clipAudio.id, isCmdPressed: true)
        #expect(vm.canSyncAudio == true)

        vm.syncSelectedAudio()

        // Wait briefly for the async MainActor task to complete
        for _ in 0..<10 {
            if vm.layers[1].clips[0].timeRange.start > .zero { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let syncedAudio = vm.layers[1].clips[0]
        #expect(abs(CMTimeGetSeconds(syncedAudio.timeRange.start) - 3.0) < 0.05)

        // Undo
        #expect(vm.canUndo == true)
        let didUndo = vm.undo()
        #expect(didUndo == true)
        let restoredAudio = vm.layers[1].clips[0]
        #expect(restoredAudio.timeRange.start == .zero)

        // Redo
        #expect(vm.canRedo == true)
        let didRedo = vm.redo()
        #expect(didRedo == true)
        let redoAudio = vm.layers[1].clips[0]
        #expect(abs(CMTimeGetSeconds(redoAudio.timeRange.start) - 3.0) < 0.05)
    }

    @Test("syncSelectedAudio with negative offset trims head of target clip")
    func testSyncSelectedAudioWithNegativeOffsetTrimsSourceStart() async {
        let clipVideo = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        let clipAudio = TimelineClip(
            name: "Song 1",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 8, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/song.mp3")
        )

        let layerVideo = TimelineLayer(name: "V1", kind: .video, clips: [clipVideo])
        let layerAudio = TimelineLayer(name: "A1", kind: .audio, clips: [clipAudio])

        let mockService = MockAudioAlignmentService(
            resultToReturn: AudioAlignmentResult(
                offsetSeconds: -2.0,
                correlation: 0.75,
                score: 6.0,
                isMatch: true
            )
        )

        let vm = TimelineViewModel(
            audioAlignmentService: mockService,
            initialLayers: [layerVideo, layerAudio]
        )

        vm.selectClip(clipVideo.id)
        vm.selectClip(clipAudio.id, isCmdPressed: true)
        vm.syncSelectedAudio()

        for _ in 0..<10 {
            if vm.layers[1].clips[0].sourceStartTime > .zero { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let trimmedAudio = vm.layers[1].clips[0]
        #expect(trimmedAudio.timeRange.start == .zero)
        #expect(abs(CMTimeGetSeconds(trimmedAudio.sourceStartTime) - 2.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(trimmedAudio.timeRange.duration) - 6.0) < 0.05)

        // Undo
        _ = vm.undo()
        let undoneAudio = vm.layers[1].clips[0]
        #expect(undoneAudio.sourceStartTime == .zero)
        #expect(undoneAudio.timeRange.duration == CMTime(value: 8, timescale: 1))
    }

    @Test("syncSelectedAudio automatically trims excess tail of audio when it exceeds video end")
    func testSyncSelectedAudioAutoTrimsTail() async {
        let clipVideo = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        let clipAudio = TimelineClip(
            name: "Long Audio",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 15, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/long_audio.m4a")
        )

        let layerVideo = TimelineLayer(name: "V1", kind: .video, clips: [clipVideo])
        let layerAudio = TimelineLayer(name: "A1", kind: .audio, clips: [clipAudio])

        let mockService = MockAudioAlignmentService(
            resultToReturn: AudioAlignmentResult(
                offsetSeconds: 0.0,
                correlation: 0.85,
                score: 8.5,
                isMatch: true
            )
        )

        let vm = TimelineViewModel(
            audioAlignmentService: mockService,
            initialLayers: [layerVideo, layerAudio]
        )

        vm.selectClip(clipVideo.id)
        vm.selectClip(clipAudio.id, isCmdPressed: true)
        vm.syncSelectedAudio()

        for _ in 0..<10 {
            if vm.layers[1].clips[0].timeRange.duration < CMTime(value: 15, timescale: 1) { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let syncedAudio = vm.layers[1].clips[0]
        #expect(syncedAudio.timeRange.start == .zero)
        #expect(abs(CMTimeGetSeconds(syncedAudio.timeRange.duration) - 5.0) < 0.05)
        #expect(syncedAudio.timeRange.end == clipVideo.timeRange.end)

        // Undo restores full duration
        _ = vm.undo()
        let undoneAudio = vm.layers[1].clips[0]
        #expect(undoneAudio.timeRange.duration == CMTime(value: 15, timescale: 1))
    }

    @Test("performAISyncAudio trims excess at both ends of Video and Audio and aligns both at zero")
    func testPerformAISyncAudioTrimsBothEnds() async {
        // Video is 20s [0..20], Audio is 12s [0..12] and starts +4s into the video (so Audio spans [4..16] of the video)
        // Expected overlap: Video head trimmed by 4s (sourceStart = 4s), Video & Audio both start at 0s with duration 12s!
        let clipVideo = TimelineClip(
            name: "IMG_5671.MOV",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 20, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/IMG_5671.MOV")
        )
        let clipAudio = TimelineClip(
            name: "Song.mp3",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 12, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/Song.mp3")
        )

        let layerVideo = TimelineLayer(name: "V1", kind: .video, clips: [clipVideo])
        let layerAudio = TimelineLayer(name: "A1", kind: .audio, clips: [clipAudio])

        let mockService = MockAudioAlignmentService(
            resultToReturn: AudioAlignmentResult(
                offsetSeconds: 4.0,
                correlation: 0.90,
                score: 9.0,
                isMatch: true
            )
        )

        let vm = TimelineViewModel(
            audioAlignmentService: mockService,
            initialLayers: [layerVideo, layerAudio]
        )

        let res = await vm.performAISyncAudio(availableAssets: [])
        #expect(res.isSuccess == true)

        let trimmedVideo = vm.layers[0].clips[0]
        let trimmedAudio = vm.layers[1].clips[0]

        #expect(trimmedVideo.timeRange.start == .zero)
        #expect(trimmedAudio.timeRange.start == .zero)
        #expect(abs(CMTimeGetSeconds(trimmedVideo.sourceStartTime) - 4.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(trimmedVideo.timeRange.duration) - 12.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(trimmedAudio.timeRange.duration) - 12.0) < 0.05)
    }
}

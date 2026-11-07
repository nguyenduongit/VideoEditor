import Foundation
import CoreMedia
import Testing
import Domain
@preconcurrency import AVFoundation
@testable import FeatureShell

@Suite("TimelineExtractAudioTests")
@MainActor
struct TimelineExtractAudioTests {

    private func makeSampleVideoURL() -> URL {
        URL(fileURLWithPath: "/tmp/test_video_\(UUID().uuidString).mp4")
    }

    @Test func testCanExtractAudioValidation() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoLayer = vm.createLayer(for: .video)
        let audioLayer = vm.createLayer(for: .audio)

        let sampleURL = makeSampleVideoURL()

        let videoClip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            mediaURL: sampleURL
        )
        let audioClip = TimelineClip(
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            mediaURL: sampleURL
        )

        vm.addClip(videoClip, to: videoLayer.id)
        vm.addClip(audioClip, to: audioLayer.id)

        // Case 1: No selection
        vm.clearSelection()
        #expect(vm.canExtractAudio == false)

        // Case 2: Audio clip selected
        vm.selectClip(audioClip.id)
        #expect(vm.canExtractAudio == false)

        // Case 3: Video clip selected -> Valid
        vm.selectClip(videoClip.id)
        #expect(vm.canExtractAudio == true)

        // Case 4: Video clip already extracted -> False
        vm.updateClipLiveProperties(clipID: videoClip.id, properties: ["isAudioExtracted": .bool(true)])
        #expect(vm.canExtractAudio == false)
    }

    @Test func testExtractAudioCreatesAudioClipOnAudioLayerWithMatchingTiming() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoLayer = vm.createLayer(for: .video)
        let sampleURL = makeSampleVideoURL()

        var videoProps = BuiltInClipPropertyDefaults.properties(for: .video)
        videoProps["speed"] = .number(1.5)
        videoProps["volume"] = .number(0.8)
        videoProps["fadeIn"] = .number(0.5)

        let videoClip = TimelineClip(
            name: "Dance Routine",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 6, preferredTimescale: 600)),
            maxDuration: CMTime(seconds: 20, preferredTimescale: 600),
            mediaURL: sampleURL,
            sourceStartTime: CMTime(seconds: 1, preferredTimescale: 600),
            properties: videoProps
        )
        vm.addClip(videoClip, to: videoLayer.id)
        vm.selectClip(videoClip.id)
        #expect(vm.canExtractAudio == true)

        let extractedID = vm.extractAudio()
        #expect(extractedID != nil)

        // Verify video clip is marked with isAudioExtracted = true and volume = 0
        let updatedVideo = vm.clip(by: videoClip.id)
        #expect(updatedVideo?.properties["isAudioExtracted"]?.asBool == true)
        #expect(updatedVideo?.properties["volume"]?.asNumber == 0.0)

        // Verify audio clip created on an audio layer
        let allClips = vm.layers.flatMap(\.clips)
        let createdAudio = allClips.first { $0.id == extractedID }
        #expect(createdAudio != nil)
        #expect(createdAudio?.kind == .audio)
        #expect(createdAudio?.name == "Dance Routine (Audio)")
        #expect(createdAudio?.timeRange.start == CMTime(seconds: 2, preferredTimescale: 600))
        #expect(createdAudio?.timeRange.duration == CMTime(seconds: 6, preferredTimescale: 600))
        #expect(createdAudio?.sourceStartTime == CMTime(seconds: 1, preferredTimescale: 600))
        #expect(createdAudio?.mediaURL == sampleURL)
        #expect(createdAudio?.properties["speed"]?.asNumber == 1.5)
        #expect(createdAudio?.properties["volume"]?.asNumber == 0.8)
        #expect(createdAudio?.properties["fadeIn"]?.asNumber == 0.5)

        // Extracted audio clip should now be selected
        #expect(vm.selectedClipIDs == [extractedID!])
    }

    @Test func testExtractAudioAtomicUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let videoLayer = vm.createLayer(for: .video)
        let sampleURL = makeSampleVideoURL()

        let videoClip = TimelineClip(
            name: "Vlog Scene",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4, preferredTimescale: 600)),
            mediaURL: sampleURL
        )
        vm.addClip(videoClip, to: videoLayer.id)
        vm.selectClip(videoClip.id)

        let extractedID = vm.extractAudio()
        #expect(extractedID != nil)
        #expect(vm.clip(by: videoClip.id)?.properties["isAudioExtracted"]?.asBool == true)
        #expect(vm.clip(by: extractedID!) != nil)
        #expect(vm.canUndo == true)

        // 1. Undo: Audio clip removed, video clip sound restored
        let didUndo = vm.undo()
        #expect(didUndo == true)
        #expect(vm.clip(by: extractedID!) == nil)
        #expect(vm.clip(by: videoClip.id)?.properties["isAudioExtracted"]?.asBool != true)
        #expect(vm.canRedo == true)

        // 2. Redo: Audio clip recreated, video clip audio disabled again
        let didRedo = vm.redo()
        #expect(didRedo == true)
        #expect(vm.clip(by: videoClip.id)?.properties["isAudioExtracted"]?.asBool == true)
        #expect(vm.clip(by: extractedID!) != nil)
    }
}


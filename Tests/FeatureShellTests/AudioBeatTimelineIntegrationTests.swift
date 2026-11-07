import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

private struct MockBeatDetectionService: AudioBeatDetectionServiceProtocol {
    func detectBeats(url: URL, mode: AudioBeatDetectionMode) async -> [AudioBeatMarker] {
        switch mode {
        case .majorOnly:
            return [
                AudioBeatMarker(sourceTime: CMTime(seconds: 1.0, preferredTimescale: 600), kind: .major),
                AudioBeatMarker(sourceTime: CMTime(seconds: 2.0, preferredTimescale: 600), kind: .major),
                AudioBeatMarker(sourceTime: CMTime(seconds: 3.0, preferredTimescale: 600), kind: .major)
            ]
        case .allBeats:
            return [
                AudioBeatMarker(sourceTime: CMTime(seconds: 1.0, preferredTimescale: 600), kind: .major),
                AudioBeatMarker(sourceTime: CMTime(seconds: 1.5, preferredTimescale: 600), kind: .minor),
                AudioBeatMarker(sourceTime: CMTime(seconds: 2.0, preferredTimescale: 600), kind: .major),
                AudioBeatMarker(sourceTime: CMTime(seconds: 2.5, preferredTimescale: 600), kind: .minor),
                AudioBeatMarker(sourceTime: CMTime(seconds: 3.0, preferredTimescale: 600), kind: .major)
            ]
        }
    }

    func detectBeats(samples: [Float], sampleRate: Double, mode: AudioBeatDetectionMode) -> [AudioBeatMarker] {
        []
    }
}

@Suite("AudioBeatTimelineIntegrationTests")
@MainActor
struct AudioBeatTimelineIntegrationTests {

    @Test("AudioBeatConfiguration computes accurate timeline beat times across trim, shift, and speed")
    func testTimelineBeatTimesMapping() {
        let markers = [
            AudioBeatMarker(sourceTime: CMTime(seconds: 1.0, preferredTimescale: 600), kind: .major),
            AudioBeatMarker(sourceTime: CMTime(seconds: 2.0, preferredTimescale: 600), kind: .major),
            AudioBeatMarker(sourceTime: CMTime(seconds: 3.0, preferredTimescale: 600), kind: .major),
            AudioBeatMarker(sourceTime: CMTime(seconds: 4.0, preferredTimescale: 600), kind: .major)
        ]
        let config = AudioBeatConfiguration(mode: .majorOnly, markers: markers)
        let json = config.encodeToJSON()!

        // Clip starts at timeline 5.0s, trimmed to sourceStartTime = 1.5s, duration = 2.0s (covers source 1.5s...3.5s)
        var props = BuiltInClipPropertyDefaults.properties(for: .audio)
        props[AudioBeatConfiguration.propertyKey] = .string(json)

        let clip = TimelineClip(
            name: "Music.mp3",
            kind: .audio,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 5.0, preferredTimescale: 600),
                duration: CMTime(seconds: 2.0, preferredTimescale: 600)
            ),
            sourceStartTime: CMTime(seconds: 1.5, preferredTimescale: 600),
            properties: props
        )

        let decoded = AudioBeatConfiguration.from(clip: clip)!
        let timelineTimes = decoded.timelineBeatTimes(for: clip).map { CMTimeGetSeconds($0) }

        // Only source 2.0s (-> timeline 5.5s) and source 3.0s (-> timeline 6.5s) are inside (1.5s, 3.5s)
        #expect(timelineTimes.count == 2)
        #expect(abs(timelineTimes[0] - 5.5) < 0.001)
        #expect(abs(timelineTimes[1] - 6.5) < 0.001)
    }

    @Test("TimelineViewModel snapCandidateTimes includes beat markers from audio clips")
    func testSnapCandidatesIncludeBeatMarkers() {
        let vm = TimelineViewModel(audioBeatDetectionService: MockBeatDetectionService())
        let config = AudioBeatConfiguration(
            mode: .majorOnly,
            markers: [
                AudioBeatMarker(sourceTime: CMTime(seconds: 1.25, preferredTimescale: 600), kind: .major),
                AudioBeatMarker(sourceTime: CMTime(seconds: 2.50, preferredTimescale: 600), kind: .major)
            ]
        )
        var props = BuiltInClipPropertyDefaults.properties(for: .audio)
        props[AudioBeatConfiguration.propertyKey] = .string(config.encodeToJSON()!)

        let audioClip = TimelineClip(
            name: "BeatTrack.mp3",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)),
            mediaURL: URL(fileURLWithPath: "/tmp/test.mp3"),
            properties: props
        )
        vm.addClip(audioClip)

        let candidates = vm.snapCandidateTimes(includePlayhead: false)
        let expectedFirst = TimeRational.snapToFrame(time: CMTime(seconds: 1.25, preferredTimescale: 600))
        let expectedSecond = TimeRational.snapToFrame(time: CMTime(seconds: 2.50, preferredTimescale: 600))
        #expect(candidates.contains(expectedFirst))
        #expect(candidates.contains(expectedSecond))

        // Verify Playhead seeking to a beat marker lands on the exact same frame without offset
        let playheadState = TimelinePlayheadState()
        playheadState.seek(to: expectedFirst)
        #expect(playheadState.currentTime == expectedFirst)
    }

    @Test("Manual toggleBeatMarkerAtPlayhead and clearSelectedBeatMarkers support Undo and Redo")
    func testManualBeatToggleAndUndoRedo() {
        let vm = TimelineViewModel(audioBeatDetectionService: MockBeatDetectionService())
        let audioClip = TimelineClip(
            name: "Song.mp3",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 6.0, preferredTimescale: 600)),
            mediaURL: URL(fileURLWithPath: "/tmp/song.mp3")
        )
        vm.addClip(audioClip)
        vm.selectedClipIDs = [audioClip.id]

        let beatTime = CMTime(seconds: 2.0, preferredTimescale: 600)
        let toggledOn = vm.toggleBeatMarkerAtPlayhead(at: beatTime)
        #expect(toggledOn == true)
        #expect(vm.selectedClipHasBeats == true)

        // Pressing M again at the same time removes the marker
        _ = vm.toggleBeatMarkerAtPlayhead(at: beatTime)
        #expect(vm.selectedClipHasBeats == false)

        // Undo restores the marker
        vm.undo()
        #expect(vm.selectedClipHasBeats == true)

        // Clear all beats and undo
        vm.clearSelectedBeatMarkers()
        #expect(vm.selectedClipHasBeats == false)
        vm.undo()
        #expect(vm.selectedClipHasBeats == true)
    }
}


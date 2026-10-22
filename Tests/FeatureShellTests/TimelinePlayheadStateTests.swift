import Foundation
import CoreMedia
import Testing
@testable import FeatureShell
@testable import Domain

@MainActor
struct TimelinePlayheadStateTests {
    @Test func testPlayheadStateInitialization() {
        let state = TimelinePlayheadState(initialTime: .zero, pixelsPerSecond: 60)
        #expect(state.currentTime == .zero)
        #expect(state.isPlaying == false)
        #expect(state.isScrubbing == false)
        #expect(state.fps == 30)
        #expect(state.pixelsPerSecond == 60)
        #expect(state.currentX == 0)
        #expect(state.timecodeString == "00:00:00:00")
    }

    @Test func testPlayheadStateSeekSnapsToFrame() {
        let state = TimelinePlayheadState(initialTime: .zero, pixelsPerSecond: 60)
        var notifiedTime: CMTime?
        state.onSeek = { time in
            notifiedTime = time
        }

        // Seek to 0.034s -> snaps to 1 frame (1/30 = 0.0333s)
        let rawTime = CMTime(seconds: 0.034, preferredTimescale: 600)
        state.seek(to: rawTime)

        #expect(state.currentTime.value == 1)
        #expect(state.currentTime.timescale == 30)
        #expect(notifiedTime?.value == 1)
        #expect(state.timecodeString == "00:00:00:01")
    }

    @Test func testPlayheadStateStepFrame() {
        let state = TimelinePlayheadState(initialTime: .zero, pixelsPerSecond: 60)

        // Step forward 1 frame
        state.stepFrame(by: 1)
        #expect(state.currentTime.value == 1)
        #expect(state.currentTime.timescale == 30)

        // Step forward 29 frames -> 30 frames = 1 second
        state.stepFrame(by: 29)
        #expect(state.currentTime.value == 30)
        #expect(state.timecodeString == "00:00:01:00")

        // Step backward 10 frames
        state.stepFrame(by: -10)
        #expect(state.currentTime.value == 20)

        // Step backward 100 frames -> clamps to 0
        state.stepFrame(by: -100)
        #expect(state.currentTime.value == 0)
        #expect(state.timecodeString == "00:00:00:00")
    }

    @Test func testPlayheadStatePlayPause() {
        let state = TimelinePlayheadState()
        var lastPlayState: Bool?
        state.onPlayPause = { playing in
            lastPlayState = playing
        }

        state.setPlaying(true)
        #expect(state.isPlaying == true)
        #expect(lastPlayState == true)

        state.togglePlayPause()
        #expect(state.isPlaying == false)
        #expect(lastPlayState == false)
    }

    @Test func testProgressTimeDoesNotTriggerOnSeek() {
        let state = TimelinePlayheadState()
        var onSeekCalled = false
        state.onSeek = { _ in
            onSeekCalled = true
        }

        let newTime = CMTime(value: 5, timescale: 30)
        state.progressTime(to: newTime)

        #expect(state.currentTime == newTime)
        #expect(onSeekCalled == false)
    }
}

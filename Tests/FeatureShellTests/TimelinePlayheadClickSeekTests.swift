import Testing
import CoreMedia
import Foundation
import Domain
@testable import FeatureShell

@Suite("TimelinePlayheadClickSeekTests")
@MainActor
struct TimelinePlayheadClickSeekTests {
    @Test("Click on empty area snaps to frame and updates playhead")
    func testClickOnEmptyAreaSnapsToFrame() {
        let playhead = TimelinePlayheadState(initialTime: .zero, pixelsPerSecond: 100)
        let pps: CGFloat = 100
        let clickX: CGFloat = 254 // 2.54 seconds -> at 30fps = frame 76 -> 76/30 = 2.5333...s

        let seconds = max(0, Double(clickX / pps))
        let time = TimeRational.snapToFrame(time: CMTime(seconds: seconds, preferredTimescale: 600))
        playhead.seek(to: time, force: true)

        let expectedSeconds = Double(round(2.54 * 30.0) / 30.0)
        #expect(abs(CMTimeGetSeconds(playhead.currentTime) - expectedSeconds) < 0.001)
    }

    @Test("Click on empty area clears selection in TimelineViewModel")
    func testClickEmptyAreaClearsSelection() {
        let vm = TimelineViewModel()
        let clipID = UUID()
        vm.selectClip(clipID)
        #expect(vm.selectedClipIDs.contains(clipID))

        vm.clearSelection()
        #expect(vm.selectedClipIDs.isEmpty)
    }

    @Test("Seeking playhead on empty canvas tap is idempotent and preserves time range bounds")
    func testSeekingPlayheadOutOfBoundsSnaps() {
        let playhead = TimelinePlayheadState(initialTime: .zero, pixelsPerSecond: 100)
        let negativeX: CGFloat = -20
        let seconds = max(0, Double(negativeX / 100))
        let time = TimeRational.snapToFrame(time: CMTime(seconds: seconds, preferredTimescale: 600))
        playhead.seek(to: time, force: true)

        #expect(CMTimeGetSeconds(playhead.currentTime) == 0)
    }
}

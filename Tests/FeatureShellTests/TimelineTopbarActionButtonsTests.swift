import Foundation
import CoreMedia
import SwiftUI
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineTopbarActionButtonsTests")
@MainActor
struct TimelineTopbarActionButtonsTests {

    @Test func testTimelineViewModelCanSplitState() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        vm.addClip(clip, to: layer.id)

        // Initially no clips selected
        #expect(!vm.canSplit)

        // Select clip -> canSplit becomes true
        vm.selectClip(clip.id)
        #expect(vm.canSplit)

        // Add second clip and multi-select
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 6, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        vm.addClip(clip2, to: layer.id)
        vm.selectedClipIDs = [clip.id, clip2.id]
        #expect(vm.canSplit)

        // Clear selection -> canSplit becomes false
        vm.clearSelection()
        #expect(!vm.canSplit)
    }

    @Test func testTimelineTopbarViewCanSplitAndCanSyncAudioProps() {
        var splitTriggered = false
        var syncTriggered = false

        var pps: CGFloat = 60.0
        let binding = Binding(get: { pps }, set: { pps = $0 })

        // Default instance
        let _ = TimelineTopbarView()

        // Custom instance with canSplit and canSyncAudio
        let _ = TimelineTopbarView(
            currentTime: CMTime(seconds: 2, preferredTimescale: 600),
            pixelsPerSecond: binding,
            canSplit: true,
            canSyncAudio: true,
            isSyncingAudio: false,
            onSplit: { splitTriggered = true },
            onSyncAudio: { syncTriggered = true }
        )
        #expect(!splitTriggered)
        #expect(!syncTriggered)
    }
}

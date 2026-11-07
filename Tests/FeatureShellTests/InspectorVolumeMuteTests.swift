import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("InspectorVolumeMuteTests")
@MainActor
struct InspectorVolumeMuteTests {
    private func makeFixture(initialVolume: Double = 1.0, isLayerMuted: Bool = false) -> (TimelineViewModel, InspectorViewModel, TimelineClip, UUID) {
        let clip = TimelineClip(
            id: UUID(),
            name: "TestVideo.mp4",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            maxDuration: CMTime(seconds: 10, preferredTimescale: 600),
            sourceStartTime: .zero,
            properties: ["volume": .number(initialVolume)]
        )
        let layerID = UUID()
        let layer = TimelineLayer(
            id: layerID,
            kind: .video,
            isMuted: isLayerMuted,
            clips: [clip]
        )
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        timelineVM.selectClip(clip.id)
        inspectorVM.syncWithSelection()
        return (timelineVM, inspectorVM, clip, layerID)
    }

    @Test("Detects layer mute and updates volumeLeadingIcon accordingly")
    func testVolumeMuteDetectionWhenLayerIsMuted() {
        let (timelineVM, inspectorVM, _, layerID) = makeFixture(initialVolume: 1.0, isLayerMuted: false)

        #expect(inspectorVM.isSelectedClipLayerMuted == false)
        #expect(inspectorVM.isVolumeMuted == false)
        #expect(inspectorVM.volumeLeadingIcon == "speaker.wave.2.fill")

        // Mute layer
        timelineVM.toggleMute(for: layerID)
        #expect(inspectorVM.isSelectedClipLayerMuted == true)
        #expect(inspectorVM.isVolumeMuted == true)
        #expect(inspectorVM.volumeLeadingIcon == "speaker.slash.fill")
    }

    @Test("Toggling mute when layer is muted prioritizes unmuting the layer")
    func testToggleVolumeMuteUnmutesLayer() {
        let (timelineVM, inspectorVM, _, layerID) = makeFixture(initialVolume: 0.75, isLayerMuted: true)

        #expect(inspectorVM.isSelectedClipLayerMuted == true)
        #expect(timelineVM.layers.first(where: { $0.id == layerID })?.isMuted == true)

        inspectorVM.toggleVolumeMute()

        // Layer should now be unmuted
        #expect(timelineVM.layers.first(where: { $0.id == layerID })?.isMuted == false)
        #expect(inspectorVM.isSelectedClipLayerMuted == false)
        // Original volume of the clip is preserved intact
        #expect(inspectorVM.currentVolume == 0.75)
        #expect(inspectorVM.isVolumeMuted == false)
        #expect(inspectorVM.volumeLeadingIcon == "speaker.wave.2.fill")
    }

    @Test("Toggling mute when volume > 0 mutes clip and saves previous volume")
    func testToggleVolumeMuteMutesClipAndSavesVolume() {
        let (_, inspectorVM, clip, _) = makeFixture(initialVolume: 0.85, isLayerMuted: false)

        #expect(inspectorVM.currentVolume == 0.85)
        #expect(inspectorVM.isVolumeMuted == false)

        inspectorVM.toggleVolumeMute()

        #expect(inspectorVM.currentVolume == 0.0)
        #expect(inspectorVM.isVolumeMuted == true)
        #expect(inspectorVM.volumeLeadingIcon == "speaker.slash.fill")
        #expect(inspectorVM.preMuteVolumeByClipID[clip.id] == 0.85)
    }

    @Test("Toggling mute when volume is 0 restores previous volume")
    func testToggleVolumeMuteRestoresPreviousVolume() {
        let (_, inspectorVM, _, _) = makeFixture(initialVolume: 0.85, isLayerMuted: false)

        // Mute
        inspectorVM.toggleVolumeMute()
        #expect(inspectorVM.currentVolume == 0.0)

        // Restore
        inspectorVM.toggleVolumeMute()
        #expect(inspectorVM.currentVolume == 0.85)
        #expect(inspectorVM.isVolumeMuted == false)
        #expect(inspectorVM.volumeLeadingIcon == "speaker.wave.2.fill")
    }
}

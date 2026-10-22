import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("TimelineLayerToggleTests")
@MainActor
struct TimelineLayerToggleTests {
    private func makeSampleVideoAsset() -> MediaAsset {
        MediaAsset(
            url: URL(fileURLWithPath: "/tmp/test.mp4"),
            name: "test.mp4",
            type: .video
        )
    }

    private func makeSampleLayer(kind: ClipKind, isLocked: Bool = false, isHidden: Bool = false, isMuted: Bool = false) -> TimelineLayer {
        let clip = TimelineClip(
            name: "Clip 1",
            kind: kind,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 300, timescale: 30)),
            mediaURL: URL(fileURLWithPath: "/tmp/sample.mp4")
        )
        return TimelineLayer(
            name: "\(kind.title) 1",
            kind: kind,
            isLocked: isLocked,
            isHidden: isHidden,
            isMuted: isMuted,
            clips: [clip]
        )
    }

    @Test("Toggling lock stops playback if playing")
    func testToggleLockStopsPlayback() {
        let registry = TabRegistry()
        let layer = makeSampleLayer(kind: .video)
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)

        timelineVM.toggleLock(for: layer.id)
        #expect(timelineVM.layers[0].isLocked == true)
        #expect(shellVM.isPlaying == false)
    }

    @Test("Toggling hide does not stop playback and updates preview visibility")
    func testToggleHideDoesNotStopPlaybackAndHidesVisual() {
        let registry = TabRegistry()
        let layer = makeSampleLayer(kind: .video)
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)
        #expect(shellVM.playbackEngine.isPlaybackActive == true)

        timelineVM.toggleHide(for: layer.id)
        #expect(timelineVM.layers[0].isHidden == true)
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)
        #expect(shellVM.playbackEngine.isPlaybackActive == true)
        #expect(timelineVM.hasActiveVideoClip(at: .zero) == false)
    }

    @Test("Audio layer cannot be hidden")
    func testAudioLayerCannotBeHidden() {
        let audioLayer = makeSampleLayer(kind: .audio)
        let timelineVM = TimelineViewModel(initialLayers: [audioLayer])

        timelineVM.toggleHide(for: audioLayer.id)
        #expect(timelineVM.layers[0].isHidden == false)
    }

    @Test("Toggling mute does not stop playback")
    func testToggleMuteDoesNotStopPlayback() {
        let registry = TabRegistry()
        let layer = makeSampleLayer(kind: .video)
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)

        timelineVM.toggleMute(for: layer.id)
        #expect(timelineVM.layers[0].isMuted == true)
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)

        timelineVM.toggleMute(for: layer.id)
        #expect(timelineVM.layers[0].isMuted == false)
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)
    }

    @Test("Adding clip avoids hidden and locked layers")
    func testAddingClipAvoidsHiddenAndLockedLayers() {
        let lockedLayer = makeSampleLayer(kind: .video, isLocked: true)
        let hiddenLayer = makeSampleLayer(kind: .video, isHidden: true)
        let timelineVM = TimelineViewModel(initialLayers: [lockedLayer, hiddenLayer])

        let newClip = TimelineClip(
            name: "New Clip",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(value: 600, timescale: 30), duration: CMTime(value: 300, timescale: 30))
        )

        timelineVM.addClip(newClip)

        // Should have created a 3rd layer because the first two are locked / hidden
        #expect(timelineVM.layers.count == 3)
        #expect(timelineVM.layers.contains(where: { $0.clips.contains(where: { $0.id == newClip.id }) }))
    }

    @Test("Switch to timeline preview does not reset playback if already on timeline")
    func testSwitchToTimelinePreviewDoesNotResetPlaybackIfAlreadyOnTimeline() {
        let registry = TabRegistry()
        let layer = makeSampleLayer(kind: .video)
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.activePreviewAsset == nil)

        // Tapping timeline body while playing should not stop playback
        shellVM.switchToTimelinePreview()
        #expect(shellVM.isPlaying == true)
    }

    @Test("Toggling mute keeps playback active in engine")
    func testTogglingMuteKeepsPlaybackActiveInEngine() {
        let registry = TabRegistry()
        let layer = makeSampleLayer(kind: .video)
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playbackEngine.isPlaybackActive == true)

        timelineVM.toggleMute(for: layer.id)
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playbackEngine.isPlaybackActive == true)
        #expect(timelineVM.layers[0].isMuted == true)

        timelineVM.toggleHide(for: layer.id)
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playbackEngine.isPlaybackActive == true)
        #expect(timelineVM.layers[0].isHidden == true)
    }

    @Test("setPreviewAsset(nil) when playing timeline does not stop playback")
    func testSetPreviewAssetNilDoesNotStopPlayback() {
        let registry = TabRegistry()
        let layer = makeSampleLayer(kind: .video)
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.activePreviewAsset == nil)

        // Simulates mediaViewModel.clearSelection() -> setPreviewAsset(nil) when user clicks timeline
        shellVM.setPreviewAsset(nil)
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)
    }

    @Test("TimelineClipView and VideoThumbnailFilmstripView accept isMuted and reflect muted state")
    func testTimelineClipAndFilmstripMutedState() {
        let clip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 300, timescale: 30))
        )
        let clipViewMuted = TimelineClipView(
            clip: clip,
            height: 60,
            pixelsPerSecond: 60,
            isLocked: false,
            isMuted: true,
            onTrim: { _, _, _ in },
            onMove: { _, _ in },
            onMoveEnd: {}
        )
        #expect(clipViewMuted.isMuted == true)

        let filmstripMuted = VideoThumbnailFilmstripView(
            clip: clip,
            thumbnailService: nil,
            waveformService: nil,
            pixelsPerSecond: 60,
            width: 100,
            height: 60,
            isMuted: true
        )
        _ = filmstripMuted
    }
}

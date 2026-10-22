import Foundation
import Testing
import Domain
@testable import FeatureShell

struct PreviewPlaybackTests {
    @Test @MainActor func testPreviewVideoDoesNotAutoplayAndPlaysOnToggle() {
        let registry = TabRegistry()
        let vm = ShellViewModel(registry: registry)
        let videoURL = URL(fileURLWithPath: "/tmp/test.mp4")
        let asset = MediaAsset(url: videoURL, type: .video)

        vm.setPreviewAsset(asset)

        #expect(vm.activePreviewAsset?.id == asset.id)
        #expect(vm.avPlayer != nil)
        // Autoplay is removed: should be false on selection
        #expect(vm.isPlaying == false)
        #expect(vm.previewImage == nil)

        // Test toggle play
        vm.togglePlayPause()
        #expect(vm.isPlaying == true)

        // Test toggle pause
        vm.togglePlayPause()
        #expect(vm.isPlaying == false)
    }

    @Test @MainActor func testPreviewAudioDoesNotAutoplayAndPlaysOnToggle() {
        let registry = TabRegistry()
        let vm = ShellViewModel(registry: registry)
        let audioURL = URL(fileURLWithPath: "/tmp/song.mp3")
        let asset = MediaAsset(url: audioURL, type: .audio)

        vm.setPreviewAsset(asset)

        #expect(vm.activePreviewAsset?.id == asset.id)
        #expect(vm.avPlayer != nil)
        #expect(vm.previewImage == nil)
        #expect(vm.isPlaying == false)

        // Test toggle play audio
        vm.togglePlayPause()
        #expect(vm.isPlaying == true)

        // Test toggle pause audio
        vm.togglePlayPause()
        #expect(vm.isPlaying == false)
    }

    @Test @MainActor func testPreviewImageCleansPlayer() {
        let registry = TabRegistry()
        let vm = ShellViewModel(registry: registry)

        // First set video
        let videoAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video)
        vm.setPreviewAsset(videoAsset)
        #expect(vm.avPlayer != nil)

        // Switch to image
        let imageAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/pic.png"), type: .image)
        vm.setPreviewAsset(imageAsset)

        #expect(vm.activePreviewAsset?.id == imageAsset.id)
        #expect(vm.avPlayer == nil)
        #expect(vm.isPlaying == false)
    }

    @Test @MainActor func testClearPreview() {
        let registry = TabRegistry()
        let vm = ShellViewModel(registry: registry)
        let videoAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video)
        vm.setPreviewAsset(videoAsset)

        vm.setPreviewAsset(nil)

        #expect(vm.activePreviewAsset == nil)
        #expect(vm.avPlayer == nil)
        #expect(vm.previewImage == nil)
        #expect(vm.isPlaying == false)
    }

    @Test @MainActor func testSwitchToTimelinePreview() {
        let registry = TabRegistry()
        let vm = ShellViewModel(registry: registry)
        let videoAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video)
        vm.setPreviewAsset(videoAsset)

        var timelineActivatedCalled = false
        vm.onTimelineActivated = {
            timelineActivatedCalled = true
        }

        vm.switchToTimelinePreview()

        #expect(vm.activePreviewAsset == nil)
        #expect(vm.avPlayer == nil)
        #expect(timelineActivatedCalled == true)
    }
}

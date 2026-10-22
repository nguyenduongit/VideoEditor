import Testing
import Foundation
import CoreMedia
import AppKit
import Domain
@testable import FeatureShell

@Suite("TimelineMediaDurationResolverTests")
struct TimelineMediaDurationResolverTests {
    @Test("Non-existent URL returns nil")
    func testNonExistentURLReturnsNil() {
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_file_12345.mp4")
        let result = TimelineMediaDurationResolver.resolveDuration(for: fakeURL, type: .video)
        #expect(result == nil)
    }

    @Test("System audio file resolves accurate duration")
    func testSystemAudioFile() {
        let pingURL = URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff")
        guard FileManager.default.fileExists(atPath: pingURL.path) else { return }
        let result = TimelineMediaDurationResolver.resolveDuration(for: pingURL, type: .audio)
        #expect(result != nil)
        if let result {
            let sec = CMTimeGetSeconds(result)
            #expect(sec > 0.5 && sec < 5.0)
        }
    }

    @Test("Fragmented DASH audio avoids doubling duration")
    func testFragmentedDASHAudioDoesNotDouble() {
        let audioURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Downloads/NHA\u{0323}C HOA.m4a")
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
        let result = TimelineMediaDurationResolver.resolveDuration(for: audioURL, type: .audio)
        #expect(result != nil)
        if let result {
            let sec = CMTimeGetSeconds(result)
            // Should be ~382 seconds, strictly under 400s (and definitely not 764s)
            #expect(sec > 370 && sec < 390)
        }
    }

    @Test("Pre-warmed cache allows synchronous resolveDuration for video")
    func testPrewarmedCacheAllowsSynchronousResolveDurationForVideo() {
        TimelineMediaDurationResolver.clearCache()
        let testURL = URL(fileURLWithPath: "/tmp/sample_video_test.mp4")
        let expectedDuration = CMTime(seconds: 12.5, preferredTimescale: 600)

        #expect(TimelineMediaDurationResolver.cachedDuration(for: testURL) == nil)

        TimelineMediaDurationResolver.cacheDuration(expectedDuration, for: testURL)
        #expect(TimelineMediaDurationResolver.cachedDuration(for: testURL) == expectedDuration)

        let resolved = TimelineMediaDurationResolver.resolveDuration(for: testURL, type: .video)
        #expect(resolved == expectedDuration)

        TimelineMediaDurationResolver.clearCache()
        #expect(TimelineMediaDurationResolver.cachedDuration(for: testURL) == nil)
    }

    @Test("Async duration resolver works for audio and non-existent video")
    func testAsyncDurationResolver() async {
        TimelineMediaDurationResolver.clearCache()
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_async_123.mp4")
        let nilResult = await TimelineMediaDurationResolver.resolveDurationAsync(for: fakeURL, type: .video)
        #expect(nilResult == nil)

        let pingURL = URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff")
        guard FileManager.default.fileExists(atPath: pingURL.path) else { return }
        let pingDur = await TimelineMediaDurationResolver.resolveDurationAsync(for: pingURL, type: .audio)
        #expect(pingDur != nil)
        #expect(TimelineMediaDurationResolver.cachedDuration(for: pingURL) != nil)
    }

    @Test("TimelineClipBlockRenderer registerThumbnail and quickThumbnail non-blocking")
    @MainActor
    func testClipBlockRendererThumbnailRegistry() {
        TimelineClipBlockRenderer.clearCache()
        let videoURL = URL(fileURLWithPath: "/tmp/fake_render_test.mp4")

        let initial = TimelineClipBlockRenderer.quickThumbnail(for: videoURL)
        #expect(initial == nil)

        let sampleImage = NSImage(size: NSSize(width: 50, height: 50))
        TimelineClipBlockRenderer.registerThumbnail(sampleImage, for: videoURL)

        let cached = TimelineClipBlockRenderer.cachedThumbnail(for: videoURL)
        #expect(cached != nil)

        let quick = TimelineClipBlockRenderer.quickThumbnail(for: videoURL)
        #expect(quick != nil)

        TimelineClipBlockRenderer.clearCache()
        #expect(TimelineClipBlockRenderer.cachedThumbnail(for: videoURL) == nil)
    }
}


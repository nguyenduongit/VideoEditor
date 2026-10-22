import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

private struct MockThumbnailService: AssetThumbnailServiceProtocol {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data? { nil }
}

@Suite("TimelineProjectScriptAssetSyncTests")
@MainActor
struct TimelineProjectScriptAssetSyncTests {
    @Test func testExtractSourceURLsDeduplication() {
        let url1 = URL(fileURLWithPath: "/tmp/video1.mp4")
        let url2 = URL(fileURLWithPath: "/tmp/audio1.mp3")

        let clip1 = ClipScript(
            name: "Clip 1",
            kind: .video,
            source: .file(url: url1),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 60, timescale: 30)
            )
        )

        let clip2 = ClipScript(
            name: "Clip 2 (Same file)",
            kind: .video,
            source: .file(url: url1),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 60, timescale: 30),
                duration: RationalTime(value: 30, timescale: 30)
            )
        )

        let clip3 = ClipScript(
            name: "Clip 3",
            kind: .audio,
            source: .file(url: url2),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 90, timescale: 30)
            )
        )

        let script = ProjectScript(
            title: "Deduplication Test",
            fps: 30,
            layers: [
                LayerScript(name: "V1", kind: .video, clips: [clip1, clip2]),
                LayerScript(name: "A1", kind: .audio, clips: [clip3])
            ]
        )

        let extractedURLs = script.extractSourceURLs()
        #expect(extractedURLs.count == 2)
        #expect(extractedURLs.contains(url1))
        #expect(extractedURLs.contains(url2))
    }

    @Test func testMediaLibraryImportFromScriptURLs() {
        let mediaVM = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        #expect(mediaVM.assets.isEmpty)

        let url1 = URL(fileURLWithPath: "/tmp/sync_asset_unique_test_1.mp4")
        let url2 = URL(fileURLWithPath: "/tmp/sync_asset_unique_test_2.mp3")

        mediaVM.importURLs([url1, url2])
        #expect(mediaVM.assets.count == 2)

        // Importing again should not produce duplicates
        mediaVM.importURLs([url1])
        #expect(mediaVM.assets.count == 2)
    }
}

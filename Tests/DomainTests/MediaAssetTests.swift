import Foundation
import Testing
@testable import Domain

struct MediaAssetTests {
    @Test func testMediaTypeMapping() {
        #expect(MediaType.from(fileExtension: "mp4") == .video)
        #expect(MediaType.from(fileExtension: "MOV") == .video)
        #expect(MediaType.from(fileExtension: "mp3") == .audio)
        #expect(MediaType.from(fileExtension: "WAV") == .audio)
        #expect(MediaType.from(fileExtension: "png") == .image)
        #expect(MediaType.from(fileExtension: "JPG") == .image)
        #expect(MediaType.from(fileExtension: "txt") == nil)
    }

    @Test func testMediaAssetDefaultName() {
        let url = URL(fileURLWithPath: "/tmp/sample_video.mp4")
        let asset = MediaAsset(url: url, type: .video)
        #expect(asset.name == "sample_video.mp4")
        #expect(asset.type == .video)
    }

    @Test func testMediaAssetCustomName() {
        let url = URL(fileURLWithPath: "/tmp/audio.wav")
        let asset = MediaAsset(url: url, name: "Voiceover", type: .audio)
        #expect(asset.name == "Voiceover")
    }

    @Test func testClipKindDefaultTier() {
        #expect(ClipKind.text.defaultTier == 0)
        #expect(ClipKind.effect.defaultTier == 1)
        #expect(ClipKind.adjustment.defaultTier == 2)
        #expect(ClipKind.image.defaultTier == 3)
        #expect(ClipKind.video.defaultTier == 4)
        #expect(ClipKind.audio.defaultTier == 5)

        #expect(MediaType.video.clipKind == .video)
        #expect(MediaType.audio.clipKind == .audio)
        #expect(MediaType.image.clipKind == .image)
    }
}

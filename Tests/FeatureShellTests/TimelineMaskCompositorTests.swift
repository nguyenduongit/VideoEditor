import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import CoreImage
import AppKit
import AVKit
@testable import Domain
@testable import FeatureShell

@Suite("TimelineMaskCompositorTests")
@MainActor
struct TimelineMaskCompositorTests {
    @Test("TimelineCompositionBuilder detects active masks and selects custom compositor")
    func testTimelineCompositionBuilderWithActiveMask() {
        let clipWithoutMask = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: ["maskType": .string("none")]
        )
        let layer1 = TimelineLayer(kind: .video, clips: [clipWithoutMask])
        #expect(!TimelineCompositionBuilder.hasActiveMask(in: [layer1]))

        let clipWithMask = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: [
                "maskType": .string("circle"),
                "maskRadiusX": .number(200.0),
                "maskRadiusY": .number(200.0)
            ]
        )
        let layer2 = TimelineLayer(kind: .video, clips: [clipWithMask])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [layer2]))

        let comp = AVMutableComposition()
        let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        guard let track else {
            Issue.record("Failed to create mock track")
            return
        }

        let videoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: [layer2],
            composition: comp,
            layerTrackIDs: [layer2.id: track.trackID],
            aspectRatio: .ratio16x9,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        #expect(videoComp?.customVideoCompositorClass == TimelineVideoCompositor.self)
        #expect(videoComp?.instructions.first is TimelineCustomVideoCompositionInstruction)
    }

    @Test("Custom compositor renders frame with active mask")
    func testActualCustomCompositorRenderWithRealVideo() async throws {
        let testVideoURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Downloads/TikDown.com_TikTok_Media_001_a8275114d7c7ae0835091a6f5d9fe117.mp4")
        guard FileManager.default.fileExists(atPath: testVideoURL.path) else { return }

        let clip = TimelineClip(
            name: "TikTok",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            mediaURL: testVideoURL,
            sourceStartTime: .zero,
            properties: ["maskType": .string("split")]
        )
        let layer = TimelineLayer(kind: .video, clips: [clip])

        let comp = AVMutableComposition()
        let tracksData = await TimelineCompositionBuilder.buildTracks(
            for: comp,
            from: [layer],
            aspectRatio: .ratio16x9
        )
        var trackIDs: [UUID: CMPersistentTrackID] = [:]
        for (l, inst) in zip([layer], tracksData.instructions) {
            trackIDs[l.id] = inst.trackID
        }

        let videoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: [layer],
            composition: comp,
            layerTrackIDs: trackIDs,
            aspectRatio: .ratio16x9,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        #expect(videoComp != nil)
        guard let videoComp else { return }

        let gen = AVAssetImageGenerator(asset: comp)
        gen.videoComposition = videoComp
        gen.appliesPreferredTrackTransform = true

        let (cgImage, _) = try await gen.image(at: CMTime(seconds: 1, preferredTimescale: 600))
        #expect(cgImage.width == 1920)
        #expect(cgImage.height == 1080)

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            Issue.record("Failed to read image data")
            return
        }
        let bpp = cgImage.bitsPerPixel / 8
        let bpr = cgImage.bytesPerRow

        let leftOffset = 540 * bpr + 400 * bpp
        let leftIsBlack = (ptr[leftOffset] < 10 && ptr[leftOffset + 1] < 10 && ptr[leftOffset + 2] < 10)
        let rightOffset = 540 * bpr + 1100 * bpp
        let rightIsVisible = (ptr[rightOffset] > 10 || ptr[rightOffset + 1] > 10 || ptr[rightOffset + 2] > 10)

        #expect(leftIsBlack, "Left side outside split mask should be black background")
        #expect(rightIsVisible, "Right side inside split mask should show video content")
    }

    @Test("Two-layer compositing: top layer with split mask reveals bottom layer")
    func testTwoLayerMaskCompositing() async throws {
        let topVideoURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Downloads/TikDown.com_TikTok_Media_001_a8275114d7c7ae0835091a6f5d9fe117.mp4")
        let bgVideoURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Downloads/IMG_5593-co-ban-20261018-123024.mp4")
        guard FileManager.default.fileExists(atPath: topVideoURL.path),
              FileManager.default.fileExists(atPath: bgVideoURL.path) else { return }

        let topClip = TimelineClip(
            name: "Top",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            mediaURL: topVideoURL,
            sourceStartTime: .zero,
            properties: ["maskType": .string("split")]
        )
        let topLayer = TimelineLayer(kind: .video, clips: [topClip])

        let bgClip = TimelineClip(
            name: "Background",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            mediaURL: bgVideoURL,
            sourceStartTime: .zero,
            properties: [:]
        )
        let bgLayer = TimelineLayer(kind: .video, clips: [bgClip])

        let layers = [topLayer, bgLayer]
        let comp = AVMutableComposition()
        let tracksData = await TimelineCompositionBuilder.buildTracks(for: comp, from: layers, aspectRatio: .ratio16x9)
        var trackIDs: [UUID: CMPersistentTrackID] = [:]
        for (l, inst) in zip(layers, tracksData.instructions) {
            trackIDs[l.id] = inst.trackID
        }

        let videoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: layers,
            composition: comp,
            layerTrackIDs: trackIDs,
            aspectRatio: .ratio16x9,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        guard let videoComp else {
            Issue.record("Failed to build videoComp")
            return
        }

        let gen = AVAssetImageGenerator(asset: comp)
        gen.videoComposition = videoComp
        gen.appliesPreferredTrackTransform = true

        let (cgImage, _) = try await gen.image(at: CMTime(seconds: 1, preferredTimescale: 600))
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            Issue.record("Failed to read image data")
            return
        }
        let bpp = cgImage.bitsPerPixel / 8
        let bpr = cgImage.bytesPerRow

        let leftOffset = 540 * bpr + 400 * bpp
        let bgShowsThrough = (ptr[leftOffset] > 10 || ptr[leftOffset + 1] > 10 || ptr[leftOffset + 2] > 10)
        #expect(bgShowsThrough, "Background layer should show through where top layer is masked out")

        let rightOffset = 540 * bpr + 1100 * bpp
        let topShowsThrough = (ptr[rightOffset] > 10 || ptr[rightOffset + 1] > 10 || ptr[rightOffset + 2] > 10)
        #expect(topShowsThrough, "Top layer should show on right of split mask")
    }

    @Test("Validate video composition with exact multi-duration clips")
    func testVideoCompositionValidationWithExactClips() async throws {
        let topURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Downloads/TikDown.com_TikTok_Media_001_a8275114d7c7ae0835091a6f5d9fe117.mp4")
        let bgURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Downloads/IMG_5593-co-ban-20261018-123024.mp4")
        guard FileManager.default.fileExists(atPath: topURL.path),
              FileManager.default.fileExists(atPath: bgURL.path) else { return }

        let topClip = TimelineClip(
            name: "Top",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 24.4, preferredTimescale: 600)),
            mediaURL: topURL,
            sourceStartTime: .zero,
            properties: ["maskType": .string("split")]
        )
        let topLayer = TimelineLayer(kind: .video, clips: [topClip])

        let bgClip = TimelineClip(
            name: "BG",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 671.0, preferredTimescale: 600)),
            mediaURL: bgURL,
            sourceStartTime: .zero,
            properties: [:]
        )
        let bgLayer = TimelineLayer(kind: .video, clips: [bgClip])

        let layers = [topLayer, bgLayer]
        let comp = AVMutableComposition()
        let tracksData = await TimelineCompositionBuilder.buildTracks(for: comp, from: layers, aspectRatio: .ratio16x9)
        var trackIDs: [UUID: CMPersistentTrackID] = [:]
        for (l, inst) in zip(layers, tracksData.instructions) {
            trackIDs[l.id] = inst.trackID
        }

        let totalDur = CMTime(seconds: 671.0, preferredTimescale: 600)
        guard let videoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: layers,
            composition: comp,
            layerTrackIDs: trackIDs,
            aspectRatio: .ratio16x9,
            duration: totalDur
        ) else {
            Issue.record("Failed to build videoComp")
            return
        }

        #expect(videoComp.customVideoCompositorClass == TimelineVideoCompositor.self)
        let valid = try await videoComp.isValid(for: comp, timeRange: CMTimeRange(start: .zero, duration: comp.duration), validationDelegate: nil)
        #expect(valid, "Video composition should be valid for composition tracks")
    }
}

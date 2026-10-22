import Foundation
import CoreMedia
@preconcurrency import AVFoundation
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineCompositionBuilderTests")
struct TimelineCompositionBuilderTests {

    private static func createTestVideoFile(url: URL, durationSeconds: Double = 2.0) async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320,
            AVVideoHeightKey: 240
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)

        if let buffer = pixelBuffer {
            adaptor.append(buffer, withPresentationTime: .zero)
            let endFrameTime = CMTime(seconds: durationSeconds, preferredTimescale: 600)
            adaptor.append(buffer, withPresentationTime: endFrameTime)
        }

        input.markAsFinished()
        await writer.finishWriting()
    }

    @Test func testMakeVideoCompositionDefaultsAndInstruction() throws {
        let comp = AVMutableComposition()
        let track = try #require(comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        let inst = AVMutableVideoCompositionLayerInstruction(assetTrack: track)

        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        let videoComp = TimelineCompositionBuilder.makeVideoComposition(
            layerInstructions: [inst],
            renderSize: .zero,
            duration: duration
        )

        #expect(videoComp.renderSize.width == 1920)
        #expect(videoComp.renderSize.height == 1080)
        #expect(videoComp.instructions.count == 1)

        guard let firstInst = videoComp.instructions.first as? AVVideoCompositionInstruction else {
            Issue.record("Missing first video composition instruction")
            return
        }
        #expect(firstInst.timeRange.start == .zero)
        #expect(firstInst.timeRange.duration == duration)
        #expect(firstInst.layerInstructions.count == 1)
    }

    @Test func testBuildTracksCreatesEmptyTimeRangeForGap() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("test_gap_\(UUID().uuidString).mp4")
        try await Self.createTestVideoFile(url: videoURL, durationSeconds: 2.0)
        defer { try? FileManager.default.removeItem(at: videoURL) }

        // Clip 1: 0s..2s
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2.0, preferredTimescale: 600)),
            mediaURL: videoURL
        )
        // Clip 2: 5s..7s (gap of 3s from 2s to 5s)
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 5.0, preferredTimescale: 600), duration: CMTime(seconds: 2.0, preferredTimescale: 600)),
            mediaURL: videoURL
        )

        let layer = TimelineLayer(kind: .video, clips: [clip1, clip2])
        let composition = AVMutableComposition()

        let tracksData = await TimelineCompositionBuilder.buildTracks(for: composition, from: [layer])
        #expect(!tracksData.instructions.isEmpty)

        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            Issue.record("Expected a video track in composition")
            return
        }

        // Segments:
        // Segment 0: 0s..2s (Clip 1, not empty)
        // Segment 1: 2s..5s (Gap, isEmpty == true, duration 3s)
        // Segment 2: 5s..7s (Clip 2, not empty)
        #expect(videoTrack.segments.count == 3)
        #expect(!videoTrack.segments[0].isEmpty)
        #expect(videoTrack.segments[1].isEmpty)
        #expect(!videoTrack.segments[2].isEmpty)

        let gapDuration = videoTrack.segments[1].timeMapping.target.duration
        #expect(abs(CMTimeGetSeconds(gapDuration) - 3.0) < 0.05)
    }

    @Test func testBuildTracksHandlesUnsortedClipsChronologically() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("test_unsorted_\(UUID().uuidString).mp4")
        try await Self.createTestVideoFile(url: videoURL, durationSeconds: 2.0)
        defer { try? FileManager.default.removeItem(at: videoURL) }

        // Clip 2 at 5s..7s
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 5.0, preferredTimescale: 600), duration: CMTime(seconds: 2.0, preferredTimescale: 600)),
            mediaURL: videoURL
        )
        // Clip 1 at 0s..2s
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2.0, preferredTimescale: 600)),
            mediaURL: videoURL
        )

        // Pass clips with clip2 first, clip1 second
        let layer = TimelineLayer(kind: .video, clips: [clip2, clip1])
        let composition = AVMutableComposition()

        _ = await TimelineCompositionBuilder.buildTracks(for: composition, from: [layer])

        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            Issue.record("Expected a video track in composition")
            return
        }

        // Must still produce: Clip 1 (0..2s), Gap (2..5s), Clip 2 (5..7s)
        #expect(videoTrack.segments.count == 3)
        #expect(!videoTrack.segments[0].isEmpty)
        #expect(videoTrack.segments[1].isEmpty)
        #expect(!videoTrack.segments[2].isEmpty)
    }

    @Test func testBuildTracksAppliesAspectFitTransform() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("test_aspect_fit_\(UUID().uuidString).mp4")
        try await Self.createTestVideoFile(url: videoURL, durationSeconds: 1.0)
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 1.0, preferredTimescale: 600)),
            mediaURL: videoURL
        )
        let layer = TimelineLayer(kind: .video, clips: [clip])
        let composition = AVMutableComposition()

        let tracksData = await TimelineCompositionBuilder.buildTracks(
            for: composition,
            from: [layer],
            aspectRatio: .ratio16x9
        )
        #expect(!tracksData.instructions.isEmpty)
        guard let layerInst = tracksData.instructions.first else {
            Issue.record("Expected layer instruction")
            return
        }

        var transform = CGAffineTransform.identity
        let hasTransform = layerInst.getTransformRamp(
            for: .zero,
            start: &transform,
            end: nil,
            timeRange: nil
        )
        #expect(hasTransform)
        // Video file created is 320x240 (4:3), canvas is 1920x1080 (16:9).
        // scaleW = 1920 / 320 = 6.0, scaleH = 1080 / 240 = 4.5.
        // Aspect Fit chooses min(6.0, 4.5) = 4.5.
        #expect(abs(transform.a - 4.5) < 0.01)
        #expect(abs(transform.d - 4.5) < 0.01)
    }
}

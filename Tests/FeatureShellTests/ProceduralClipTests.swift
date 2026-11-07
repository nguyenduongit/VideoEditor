import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("ProceduralClipTests")
@MainActor
struct ProceduralClipTests {
    @Test("ProceduralAssetProvider creates a valid black MP4 file on disk")
    func testProceduralAssetProviderGeneratesFile() async throws {
        let url = ProceduralAssetProvider.shared.blackVideoURL()
        #expect(FileManager.default.fileExists(atPath: url.path))

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(!tracks.isEmpty)
        let naturalSize = try await tracks[0].load(.naturalSize)
        #expect(naturalSize.width == 64)
        #expect(naturalSize.height == 64)
    }

    @Test("Procedural clip allows infinite trim bounds without fixed source duration cap")
    func testProceduralClipInfiniteTrimBounds() {
        let clip = TimelineClip(
            name: "Màn hình đen",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            maxDuration: nil,
            properties: [
                "isProcedural": .bool(true),
                "isSolidColor": .bool(true),
                "solidColorHex": .string("#000000")
            ]
        )

        let maxEndNoNext = TimelineClipTrimBounds.maxEnd(clip: clip, nextClipStart: nil)
        #expect(maxEndNoNext == Double.infinity)

        let minStartNoPrev = TimelineClipTrimBounds.minStart(clip: clip, previousClipEnd: nil)
        #expect(minStartNoPrev == 0.0)

        var trimmed = clip
        let longDuration = CMTime(seconds: 120, preferredTimescale: 600)
        trimmed.trim(newStart: .zero, newDuration: longDuration)
        #expect(trimmed.timeRange.duration.seconds == 120.0)
    }

    @Test("Procedural solid color clip activates custom compositor")
    func testProceduralClipActivatesCustomCompositor() {
        let clip = TimelineClip(
            name: "Màn hình đen",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: [
                "isProcedural": .bool(true),
                "isSolidColor": .bool(true)
            ]
        )
        let layer = TimelineLayer(kind: .video, clips: [clip])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [layer]))
    }

    @Test("Splitting a procedural clip preserves isProcedural and sets right sourceStartTime to zero")
    func testProceduralClipSplit() {
        let clip = TimelineClip(
            name: "Màn hình đen",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600)),
            properties: [
                "isProcedural": .bool(true),
                "isSolidColor": .bool(true)
            ]
        )

        let splitResult = clip.split(at: CMTime(seconds: 4, preferredTimescale: 600))
        #expect(splitResult != nil)
        if let (left, right) = splitResult {
            #expect(left.timeRange.duration.seconds == 4.0)
            #expect(right.timeRange.duration.seconds == 6.0)
            #expect(left.properties["isProcedural"]?.asBool == true)
            #expect(right.properties["isProcedural"]?.asBool == true)
            #expect(right.sourceStartTime == .zero)
        }
    }
}


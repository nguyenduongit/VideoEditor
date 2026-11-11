import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("CompositorSeamlessTransitionTests")
@MainActor
struct CompositorSeamlessTransitionTests {
    @Test("buildVideoComposition uses TimelineVideoCompositor when transform effects are active")
    func testConsistentCompositorAcrossPropertyChanges() {
        let composition = AVMutableComposition()
        let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: 201)
        #expect(track != nil)

        let layerID = UUID()
        let dummyURL = URL(fileURLWithPath: "/tmp/seamless_test.mp4")
        TimelineCompositionBuilder.metadataCache.store(
            VideoTrackMetadata(transform: .identity, naturalSize: CGSize(width: 1920, height: 1080)),
            for: dummyURL
        )

        let scrubbedClip = TimelineClip(
            id: UUID(),
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            mediaURL: dummyURL,
            sourceStartTime: .zero,
            properties: [
                "scale": .number(1.0),
                "positionX": .number(0.0),
                "skewX": .number(2.5),
                "perspectiveX": .number(0.15)
            ]
        )
        let layer2 = TimelineLayer(id: layerID, name: "Video Layer", kind: .video, clips: [scrubbedClip])
        let trackIDs: [UUID: CMPersistentTrackID] = [layerID: 201]

        let compScrubbed = TimelineCompositionBuilder.buildVideoComposition(
            for: [layer2],
            composition: composition,
            layerTrackIDs: trackIDs,
            aspectRatio: .ratio16x9,
            duration: CMTime(value: 5, timescale: 1)
        )
        #expect(compScrubbed != nil)
        #expect(compScrubbed?.customVideoCompositorClass == TimelineVideoCompositor.self)
    }

    @Test("Image clip inherits video transform and blend, excludes speed, and exposes Image, Mask, Adjustment tabs")
    func testImageClipTabsAndBlendMode() {
        let registry = ClipPropertyRegistry()
        let tabs = registry.tabs(for: .image)
        #expect(tabs == ["Image", "Mask", "Adjustment"])
        #expect(!tabs.contains("Speed"))

        let imageDesc = registry.descriptors(for: .image, tab: "Image")
        let descIDs = imageDesc.map(\.id)
        #expect(descIDs.contains("position"))
        #expect(descIDs.contains("scale"))
        #expect(descIDs.contains("uniformScale"))
        #expect(descIDs.contains("rotation"))
        #expect(descIDs.contains("skewX"))
        #expect(descIDs.contains("skewY"))
        #expect(descIDs.contains("perspectiveX"))
        #expect(descIDs.contains("perspectiveY"))
        #expect(descIDs.contains("flip"))
        #expect(descIDs.contains("blendMode"))
        #expect(descIDs.contains("opacity"))
        #expect(!descIDs.contains("speed"))

        let maskDesc = registry.descriptors(for: .image, tab: "Mask")
        #expect(maskDesc.contains { $0.id == "maskType" })

        let adjDesc = registry.descriptors(for: .image, tab: "Adjustment")
        #expect(!adjDesc.isEmpty)

        // Verify makeStillImageRenderInfo forwards blendMode
        let imageClip = TimelineClip(
            name: "Photo.png",
            kind: .image,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 4, timescale: 1)),
            properties: [
                "blendMode": .string("screen"),
                "opacity": .number(0.85)
            ]
        )
        let imgLayer = TimelineLayer(id: UUID(), name: "Image Layer", kind: .image, clips: [imageClip])
        let renderInfo = TimelineCompositionBuilder.makeStillImageRenderInfo(
            layer: imgLayer,
            range: CMTimeRange(start: .zero, duration: CMTime(value: 4, timescale: 1)),
            canvasSize: CGSize(width: 1920, height: 1080)
        )
        #expect(renderInfo != nil)
        #expect(renderInfo?.blendMode == .screen)
        #expect(renderInfo?.opacity == 0.85)
    }

    @Test("Image clip has full filmstrip thumbnail presentation with header and no waveform")
    func testImageClipTimelineFilmstripPresentation() {
        let pres = ClipKind.image.presentation
        #expect(pres.hasFilmstrip == true)
        #expect(pres.hasWaveform == false)
        #expect(pres.hasHeaderBar == true)
        #expect(pres.showsHeaderDuration == true)
        #expect(ClipKind.image.isAuxiliary == false)
    }
}

import Foundation
import Testing
import CoreMedia
import CoreGraphics
import Domain
@testable import FeatureShell

@Suite("PreviewObjectManipulatorTests")
struct PreviewObjectManipulatorTests {

    @Test func testHitTestingSingleClipCenterAndCorners() {
        let canvasSize = CGSize(width: 1920, height: 1080)
        let viewSize = CGSize(width: 960, height: 540)

        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        )
        let layer = TimelineLayer(kind: .video, clips: [clip])

        // Center click: screen (480, 270)
        let hitCenter = PreviewHitTester.findTopMostClip(
            layers: [layer],
            currentTime: CMTime(seconds: 2, preferredTimescale: 600),
            canvasSize: canvasSize,
            screenPoint: CGPoint(x: 480, y: 270),
            viewSize: viewSize
        )
        #expect(hitCenter?.id == clip.id)

        // Point outside the view: screen (1000, 600)
        let hitOutside = PreviewHitTester.findTopMostClip(
            layers: [layer],
            currentTime: CMTime(seconds: 2, preferredTimescale: 600),
            canvasSize: canvasSize,
            screenPoint: CGPoint(x: 1000, y: 600),
            viewSize: viewSize
        )
        #expect(hitOutside == nil)
    }

    @Test func testOverlappingLayersPriorityTopMostLayerSelected() {
        let canvasSize = CGSize(width: 1920, height: 1080)
        let viewSize = CGSize(width: 960, height: 540)

        let topClip = TimelineClip(
            name: "Top Overlay",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let bottomClip = TimelineClip(
            name: "Bottom Base",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        )

        // layers[0] is top-most
        let topLayer = TimelineLayer(name: "Video 2", kind: .video, clips: [topClip])
        let bottomLayer = TimelineLayer(name: "Video 1", kind: .video, clips: [bottomClip])

        let hit = PreviewHitTester.findTopMostClip(
            layers: [topLayer, bottomLayer],
            currentTime: CMTime(seconds: 1, preferredTimescale: 600),
            canvasSize: canvasSize,
            screenPoint: CGPoint(x: 480, y: 270),
            viewSize: viewSize
        )

        #expect(hit?.id == topClip.id)
        #expect(hit?.name == "Top Overlay")
    }

    @Test func testHiddenAndLockedLayersAreSkipped() {
        let canvasSize = CGSize(width: 1920, height: 1080)
        let viewSize = CGSize(width: 960, height: 540)

        let topClip = TimelineClip(
            name: "Top Overlay",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let bottomClip = TimelineClip(
            name: "Bottom Base",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        )

        let hiddenTopLayer = TimelineLayer(name: "Video 2", kind: .video, isHidden: true, clips: [topClip])
        let bottomLayer = TimelineLayer(name: "Video 1", kind: .video, clips: [bottomClip])

        // When top layer is hidden, bottom layer must be selected
        var hit = PreviewHitTester.findTopMostClip(
            layers: [hiddenTopLayer, bottomLayer],
            currentTime: CMTime(seconds: 1, preferredTimescale: 600),
            canvasSize: canvasSize,
            screenPoint: CGPoint(x: 480, y: 270),
            viewSize: viewSize
        )
        #expect(hit?.id == bottomClip.id)

        // When top layer is locked, bottom layer must be selected
        let lockedTopLayer = TimelineLayer(name: "Video 2", kind: .video, isLocked: true, clips: [topClip])
        hit = PreviewHitTester.findTopMostClip(
            layers: [lockedTopLayer, bottomLayer],
            currentTime: CMTime(seconds: 1, preferredTimescale: 600),
            canvasSize: canvasSize,
            screenPoint: CGPoint(x: 480, y: 270),
            viewSize: viewSize
        )
        #expect(hit?.id == bottomClip.id)
    }

    @Test func testAudioLayersAreIgnoredForPreviewHitTesting() {
        let canvasSize = CGSize(width: 1920, height: 1080)
        let viewSize = CGSize(width: 960, height: 540)

        let audioClip = TimelineClip(
            name: "BGM.mp3",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        )
        let audioLayer = TimelineLayer(kind: .audio, clips: [audioClip])

        let hit = PreviewHitTester.findTopMostClip(
            layers: [audioLayer],
            currentTime: CMTime(seconds: 2, preferredTimescale: 600),
            canvasSize: canvasSize,
            screenPoint: CGPoint(x: 480, y: 270),
            viewSize: viewSize
        )
        #expect(hit == nil)
    }

    @Test @MainActor func testLiveDragAndUndoRedoTransaction() {
        let timelineVM = TimelineViewModel()
        let executor = TimelineCommandExecutor(viewModel: timelineVM)
        timelineVM.commandExecutor = executor

        var clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        clip.properties["positionX"] = .number(0.0)
        clip.properties["positionY"] = .number(0.0)
        timelineVM.layers = [TimelineLayer(kind: .video, clips: [clip])]
        timelineVM.selectedClipIDs = [clip.id]

        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        #expect(inspectorVM.liveNumber(for: "positionX", default: 0) == 0.0)

        // Drag starts
        inspectorVM.onSliderEditingChanged(key: "position", isEditing: true)

        // Live dragging updates
        inspectorVM.updateLiveValue(key: "positionX", value: 120.0)
        inspectorVM.updateLiveValue(key: "positionY", value: -45.0)

        #expect(inspectorVM.liveNumber(for: "positionX", default: 0) == 120.0)
        #expect(inspectorVM.liveNumber(for: "positionY", default: 0) == -45.0)

        // Drag ends
        inspectorVM.onSliderEditingChanged(key: "position", isEditing: false)

        #expect(timelineVM.canUndo)
        let updatedClip = timelineVM.clip(by: clip.id)
        #expect(updatedClip?.properties["positionX"]?.asNumber == 120.0)
        #expect(updatedClip?.properties["positionY"]?.asNumber == -45.0)

        // Undo
        let undone = timelineVM.undo()
        #expect(undone)
        let undoneClip = timelineVM.clip(by: clip.id)
        #expect(undoneClip?.properties["positionX"]?.asNumber == 0.0)
        #expect(undoneClip?.properties["positionY"]?.asNumber == 0.0)

        // Redo
        let redone = timelineVM.redo()
        #expect(redone)
        let redoneClip = timelineVM.clip(by: clip.id)
        #expect(redoneClip?.properties["positionX"]?.asNumber == 120.0)
        #expect(redoneClip?.properties["positionY"]?.asNumber == -45.0)
    }

    @Test func testDragTranslationDirectionMatchesScreenOrientation() {
        let canvasSize = CGSize(width: 1920, height: 1080)
        let viewSize = CGSize(width: 960, height: 540)

        // Center position (0, 0) maps to screen center (480, 270)
        let centerPt = ClipCanvasGeometry.screenCenter(
            positionX: 0,
            positionY: 0,
            canvasSize: canvasSize,
            viewSize: viewSize
        )
        #expect(centerPt.x == 480)
        #expect(centerPt.y == 270)

        // Moving UP on screen (negative Y in screen coords): positionY should decrease
        let upPt = ClipCanvasGeometry.screenCenter(
            positionX: 0,
            positionY: -100,
            canvasSize: canvasSize,
            viewSize: viewSize
        )
        #expect(upPt.y < centerPt.y) // Screen Y is smaller (higher up on screen)

        // Moving DOWN on screen (positive Y in screen coords): positionY should increase
        let downPt = ClipCanvasGeometry.screenCenter(
            positionX: 0,
            positionY: 100,
            canvasSize: canvasSize,
            viewSize: viewSize
        )
        #expect(downPt.y > centerPt.y) // Screen Y is larger (lower down on screen)
    }

    @Test func testGeometry16x9VideoIn9x16CanvasWithAutoPanFillsHeightAndPreservesOverflow() {
        let canvasSize = CGSize(width: 1080, height: 1920) // 9:16
        var clip = TimelineClip(
            name: "Video 16:9",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        )
        let url = URL(fileURLWithPath: "/tmp/sample16x9_\(UUID().uuidString).mp4")
        clip.mediaURL = url
        VideoMetadataCache.shared.store(
            VideoTrackMetadata(transform: .identity, naturalSize: CGSize(width: 1920, height: 1080)),
            for: url
        )

        let autoPan = AutoPanConfiguration(
            isEnabled: true,
            zoom: 1.0,
            smoothness: 0.5,
            keyframes: [
                AutoPanKeyframe(timeSeconds: 0, normalizedX: 0.5, confidence: 1.0, waistY: 0.5, ankleY: 0.8)
            ]
        )
        clip.properties["autoPanConfig"] = .string(autoPan.encodeToString()!)

        let geom = ClipCanvasGeometry.compute(
            for: clip,
            canvasSize: canvasSize,
            currentTime: CMTime(seconds: 1, preferredTimescale: 600)
        )

        // Height must match the 9:16 canvas height (1920)
        #expect(abs(geom.size.height - 1920.0) < 0.1)
        // Width must overflow the 9:16 canvas (3413.33)
        #expect(geom.size.width > 1080.0)
        #expect(abs(geom.size.width - 3413.33) < 1.0)
    }
}

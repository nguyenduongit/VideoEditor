import Testing
import AppKit
import CoreMedia
@testable import Domain
@testable import DesignSystem
@testable import FeatureShell

private final class MockDropDraggingInfo: NSObject, NSDraggingInfo {
    var draggingPasteboard: NSPasteboard = .init(name: .drag)
    var draggingSource: Any? = nil
    var draggingSourceOperationMask: NSDragOperation = .copy
    var draggingLocation: NSPoint = NSPoint(x: 100, y: 50)
    var draggedImageLocation: NSPoint = .zero
    var draggedImage: NSImage? = nil
    var draggingSequenceNumber: Int = 1
    var draggingDestinationWindow: NSWindow? = nil
    var numberOfValidItemsForDrop: Int = 1
    var animatesToDestination: Bool = false
    var draggingFormation: NSDraggingFormation = .default
    var springLoadingHighlight: NSSpringLoadingHighlight = .none

    var enumeratedItems: [NSDraggingItem] = []

    func resetSpringLoading() {}
    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }

    func enumerateDraggingItems(
        options: NSDraggingItemEnumerationOptions = [],
        for view: NSView?,
        classes: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {
        for (i, item) in enumeratedItems.enumerated() {
            var stop: ObjCBool = false
            block(item, i, &stop)
            if stop.boolValue { break }
        }
    }
}

@Suite("TimelineDropTargetBridgeTests")
@MainActor
struct TimelineDropTargetBridgeTests {
    @Test("ClipBlockRenderer produces valid image for video and audio")
    @MainActor
    func testClipBlockRendererProducesValidImageForVideoAndAudio() {
        TimelineClipBlockRenderer.clearCache()

        let dur = CMTime(seconds: 142.0, preferredTimescale: 600)
        let videoImg = TimelineClipBlockRenderer.renderImage(
            name: "test_video.mp4",
            duration: dur,
            kind: .video,
            width: 300,
            height: 74,
            thumbnail: nil
        )

        #expect(videoImg != nil)
        #expect(videoImg?.size.width == 300)
        #expect(videoImg?.size.height == 74)

        let audioImg = TimelineClipBlockRenderer.renderImage(
            name: "test_audio.mp3",
            duration: dur,
            kind: .audio,
            width: 250,
            height: 54,
            thumbnail: nil
        )

        #expect(audioImg != nil)
        #expect(audioImg?.size.width == 250)
        #expect(audioImg?.size.height == 54)
    }

    @Test("hitTest returns nil when no file is on drag pasteboard")
    func testHitTestReturnsNilWhenNoFileOnDragPasteboard() {
        let view = TimelineDropTargetNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        let pb = NSPasteboard(name: .drag)
        pb.clearContents()

        let hitResult = view.hitTest(NSPoint(x: 50, y: 50))
        #expect(hitResult == nil)
    }

    @Test("hitTest returns self when file is on drag pasteboard")
    func testHitTestReturnsSelfWhenFileIsOnDragPasteboard() {
        let view = TimelineDropTargetNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        let testURL = URL(fileURLWithPath: "/tmp/test.mp4")
        pb.writeObjects([testURL as NSURL])

        let hitResult = view.hitTest(NSPoint(x: 50, y: 50))
        #expect(hitResult == view)
        pb.clearContents()
    }

    // Drag image is no longer overridden at the destination — it is pre-built at
    // the SOURCE (MediaAssetDragSourceNSView) with the cursor at the left edge.
    // This test verifies that:
    //   • draggingEntered returns .copy and updates the guide line
    //   • draggingExited clears the guide line
    //   • The drag item frame is NOT touched by the destination
    @Test("draggingEntered updates guide line and draggingExited clears it")
    @MainActor
    func testDraggingEnteredUpdatesGuideAndExitedClearsIt() {
        let view = TimelineDropTargetNSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        view.pixelsPerSecond = 10

        var guideX: CGFloat?
        view.onDragGuideChanged = { guideX = $0 }

        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        let testURL = URL(fileURLWithPath: "/tmp/test_clip.mp4")
        pb.writeObjects([testURL as NSURL])

        let mock = MockDropDraggingInfo()
        mock.draggingLocation = NSPoint(x: 100, y: 60)

        let dragItem = NSDraggingItem(pasteboardWriter: testURL as NSURL)
        let origFrame = NSRect(x: 50, y: 50, width: 80, height: 80)
        let origImg = NSImage(size: NSSize(width: 80, height: 80))
        dragItem.setDraggingFrame(origFrame, contents: origImg)
        mock.enumeratedItems = [dragItem]

        let op = view.draggingEntered(mock)
        #expect(op == .copy)
        #expect(guideX != nil)
        // Destination sets 1:1 block frame anchored at cursor X (100) and video layer height (74)
        #expect(dragItem.draggingFrame.origin.x == 100)
        #expect(dragItem.draggingFrame.size.height == 74)

        view.draggingExited(mock)
        #expect(guideX == nil)
        // Leaving timeline restores the compact thumbnail (64x64) anchored at cursor left edge (100)
        #expect(dragItem.draggingFrame.size.width == 64)
        #expect(dragItem.draggingFrame.size.height == 64)
        #expect(dragItem.draggingFrame.origin.x == 100)
        #expect(dragItem.draggingFrame.origin.y == 208)
        pb.clearContents()
    }

    @Test("TimelineClipBlockRenderer dragThumbnail produces valid 64x64 card")
    @MainActor
    func testDragThumbnailProducesValidCard() {
        TimelineClipBlockRenderer.clearCache()
        let testURL = URL(fileURLWithPath: "/tmp/sample_drag.mp4")
        let thumbImg = TimelineClipBlockRenderer.dragThumbnail(for: testURL, type: .video)
        #expect(thumbImg.size.width == 64)
        #expect(thumbImg.size.height == 64)

        let audioURL = URL(fileURLWithPath: "/tmp/sample_drag.mp3")
        let audioThumb = TimelineClipBlockRenderer.dragThumbnail(for: audioURL, type: .audio)
        #expect(audioThumb.size.width == 64)
        #expect(audioThumb.size.height == 64)
    }

    @Test("performDragOperation calls drop callback with snapped time at head")
    func testPerformDragOperationCallsDropCallbackWithSnappedTime() {
        let view = TimelineDropTargetNSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        view.pixelsPerSecond = 100
        view.scrollOffset = 50

        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        let testURL = URL(fileURLWithPath: "/tmp/sample.mp4")
        pb.writeObjects([testURL as NSURL])

        let mock = MockDropDraggingInfo()
        mock.draggingLocation = NSPoint(x: 124, y: 60)

        var droppedAsset: MediaAsset?
        var droppedTime: CMTime?
        view.onDropAsset = { asset, time in
            droppedAsset = asset
            droppedTime = time
        }

        let performed = view.performDragOperation(mock)
        #expect(performed)
        #expect(droppedAsset?.url.lastPathComponent == "sample.mp4")
        #expect(droppedTime != nil)
        if let time = droppedTime {
            #expect(abs(CMTimeGetSeconds(time) - 1.74) < 0.05)
        }
        pb.clearContents()
    }

    @Test("draggingEntered with view in window updates guide line correctly")
    @MainActor
    func testDraggingEnteredWithViewInWindowUpdatesGuideLineCorrectly() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let view = TimelineDropTargetNSView(frame: NSRect(x: 100, y: 50, width: 600, height: 400))
        win.contentView?.addSubview(view)
        view.pixelsPerSecond = 100

        var guideX: CGFloat?
        view.onDragGuideChanged = { guideX = $0 }

        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        let testURL = URL(fileURLWithPath: "/tmp/test_clip.mp4")
        pb.writeObjects([testURL as NSURL])

        let mock = MockDropDraggingInfo()
        // Mouse is at window X=250 → local X=150 inside the view (frame.origin.x=100)
        mock.draggingLocation = NSPoint(x: 250, y: 150)
        mock.enumeratedItems = []

        let op = view.draggingEntered(mock)
        #expect(op == .copy)
        // Guide must snap to a position near 150 px (local X) at 100 px/s → ~1.5 s
        #expect(guideX != nil)
        if let gX = guideX {
            #expect(abs(gX - 150) < 5)
        }
        pb.clearContents()
    }

    @Test("DropTarget snaps to clip edge candidate and drops at snapped time")
    @MainActor
    func testDropTargetSnapsToClipEdgeAndDropsAtSnappedTime() {
        let view = TimelineDropTargetNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        view.pixelsPerSecond = 100
        view.scrollOffset = 0

        // Candidate snap point at 5.0 seconds (e.g. start of another clip on timeline)
        let candidateTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        view.snapCandidatesProvider = { [candidateTime] }

        var guideCanvasX: CGFloat?
        view.onDragGuideChanged = { guideCanvasX = $0 }

        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        let testURL = URL(fileURLWithPath: "/tmp/snap_sample.mp4")
        pb.writeObjects([testURL as NSURL])

        let mock = MockDropDraggingInfo()
        // Mouse is at X=506 (5.06s). At 100 PPS, 6 pixels difference is within the 10px snap threshold
        mock.draggingLocation = NSPoint(x: 506, y: 100)

        _ = view.draggingEntered(mock)
        // Guide line must snap exactly to candidate (5.0s * 100 = 500 px)
        #expect(guideCanvasX != nil)
        if let gX = guideCanvasX {
            #expect(abs(gX - 500.0) < 0.001)
        }

        var droppedTime: CMTime?
        view.onDropAsset = { _, time in droppedTime = time }
        let performed = view.performDragOperation(mock)
        #expect(performed)
        #expect(droppedTime == candidateTime)
        pb.clearContents()
    }
}

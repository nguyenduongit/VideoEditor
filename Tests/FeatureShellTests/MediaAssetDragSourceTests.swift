import Testing
import AppKit
import Domain
@testable import FeatureShell

@Suite("MediaAssetDragSourceNSView Tests")
@MainActor
struct MediaAssetDragSourceTests {

    private func makeView(width: CGFloat = 100, height: CGFloat = 120) -> (MediaAssetDragSourceNSView, NSWindow) {
        let view = MediaAssetDragSourceNSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(view)
        return (view, window)
    }

    private func makeMouseEvent(
        type: NSEvent.EventType,
        locationInView: NSPoint,
        view: NSView,
        window: NSWindow
    ) -> NSEvent? {
        let locationInWindow = view.convert(locationInView, to: nil)
        return NSEvent.mouseEvent(
            with: type,
            location: locationInWindow,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
    }

    @Test func testPlusButtonHitRectCalculation() {
        let (view, _) = makeView(width: 100, height: 120)
        let hitRect = view.plusButtonHitRect
        #expect(hitRect.width == 30)
        #expect(hitRect.height == 30)
        #expect(hitRect.origin.x == 70)
        #expect(hitRect.origin.y == 70)
    }

    @Test func testClickOnPlusButtonInvokesAddToTimeline() throws {
        let (view, window) = makeView(width: 100, height: 120)
        var addCalled = false
        var selectCalled = false

        view.onAddToTimeline = { addCalled = true }
        view.onSelect = { _ in selectCalled = true }

        let insidePoint = NSPoint(x: 85, y: 85)
        let downEvent = try #require(makeMouseEvent(type: .leftMouseDown, locationInView: insidePoint, view: view, window: window))
        let upEvent = try #require(makeMouseEvent(type: .leftMouseUp, locationInView: insidePoint, view: view, window: window))

        view.mouseDown(with: downEvent)
        #expect(!selectCalled)
        #expect(!addCalled)

        view.mouseUp(with: upEvent)
        #expect(addCalled)
        #expect(!selectCalled)
    }

    @Test func testClickOutsidePlusButtonInvokesSelect() throws {
        let (view, window) = makeView(width: 100, height: 120)
        var addCalled = false
        var selectCalled = false

        view.onAddToTimeline = { addCalled = true }
        view.onSelect = { _ in selectCalled = true }

        let outsidePoint = NSPoint(x: 20, y: 20)
        let downEvent = try #require(makeMouseEvent(type: .leftMouseDown, locationInView: outsidePoint, view: view, window: window))
        let upEvent = try #require(makeMouseEvent(type: .leftMouseUp, locationInView: outsidePoint, view: view, window: window))

        view.mouseDown(with: downEvent)
        #expect(selectCalled)
        #expect(!addCalled)

        view.mouseUp(with: upEvent)
        #expect(!addCalled)
    }

    @Test func testMouseDownOnPlusButtonAndMouseUpOutsideCancelsAdd() throws {
        let (view, window) = makeView(width: 100, height: 120)
        var addCalled = false
        var selectCalled = false

        view.onAddToTimeline = { addCalled = true }
        view.onSelect = { _ in selectCalled = true }

        let insidePoint = NSPoint(x: 85, y: 85)
        let outsidePoint = NSPoint(x: 10, y: 10)
        let downEvent = try #require(makeMouseEvent(type: .leftMouseDown, locationInView: insidePoint, view: view, window: window))
        let upEvent = try #require(makeMouseEvent(type: .leftMouseUp, locationInView: outsidePoint, view: view, window: window))

        view.mouseDown(with: downEvent)
        view.mouseUp(with: upEvent)

        #expect(!addCalled)
        #expect(!selectCalled)
    }
}

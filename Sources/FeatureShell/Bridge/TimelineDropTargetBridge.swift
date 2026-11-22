import AppKit
import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Lưu giữ trạng thái phiên kéo thả từ các kho Assets sang Timeline (In-Memory O(1) Fast Path).
@MainActor
public final class TransitionDragSessionState {
    public static let shared = TransitionDragSessionState()
    public var activePresetID: String?
    public var activePayload: TimelineDragPayload?
    public var timelinePixelsPerSecond: CGFloat = 60.0

    private init() {}

    public func begin(payload: TimelineDragPayload) {
        activePayload = payload
        activePresetID = payload.transitionPresetID
    }

    public func clear() {
        activePayload = nil
        activePresetID = nil
    }
}

public struct TimelineDropTargetBridge: NSViewRepresentable {
    private let pixelsPerSecond: CGFloat
    private let scrollOffset: CGFloat
    private let verticalScrollOffset: CGFloat
    private let onDropAsset: (MediaAsset, CMTime) -> Void
    private let onDropPayload: ((TimelineDragPayload, CMTime) -> Void)?
    private let onDragGuideChanged: ((CGFloat?) -> Void)?
    private let snapCandidatesProvider: (() -> [CMTime])?
    private let resolveTransitionJoinTarget: ((String, CGFloat, CGFloat) -> TransitionDropJoinTarget?)?
    private let onDropTransition: ((String, CGFloat, CGFloat) -> Bool)?
    private let onTransitionDragEnded: (() -> Void)?

    public init(
        pixelsPerSecond: CGFloat,
        scrollOffset: CGFloat,
        verticalScrollOffset: CGFloat = 0,
        onDropAsset: @escaping (MediaAsset, CMTime) -> Void,
        onDropPayload: ((TimelineDragPayload, CMTime) -> Void)? = nil,
        onDragGuideChanged: ((CGFloat?) -> Void)? = nil,
        snapCandidatesProvider: (() -> [CMTime])? = nil,
        resolveTransitionJoinTarget: ((String, CGFloat, CGFloat) -> TransitionDropJoinTarget?)? = nil,
        onDropTransition: ((String, CGFloat, CGFloat) -> Bool)? = nil,
        onTransitionDragEnded: (() -> Void)? = nil
    ) {
        self.pixelsPerSecond = pixelsPerSecond
        self.scrollOffset = scrollOffset
        self.verticalScrollOffset = verticalScrollOffset
        self.onDropAsset = onDropAsset
        self.onDropPayload = onDropPayload
        self.onDragGuideChanged = onDragGuideChanged
        self.snapCandidatesProvider = snapCandidatesProvider
        self.resolveTransitionJoinTarget = resolveTransitionJoinTarget
        self.onDropTransition = onDropTransition
        self.onTransitionDragEnded = onTransitionDragEnded
    }

    public func makeNSView(context: Context) -> TimelineDropTargetNSView {
        let view = TimelineDropTargetNSView()
        configure(view)
        return view
    }

    public func updateNSView(_ nsView: TimelineDropTargetNSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: TimelineDropTargetNSView) {
        view.pixelsPerSecond = pixelsPerSecond
        TransitionDragSessionState.shared.timelinePixelsPerSecond = pixelsPerSecond
        view.scrollOffset = scrollOffset
        view.verticalScrollOffset = verticalScrollOffset
        view.onDropAsset = onDropAsset
        view.onDropPayload = onDropPayload
        view.onDragGuideChanged = onDragGuideChanged
        view.snapCandidatesProvider = snapCandidatesProvider
        view.resolveTransitionJoinTarget = resolveTransitionJoinTarget
        view.onDropTransition = onDropTransition
        view.onTransitionDragEnded = onTransitionDragEnded
    }
}

// MARK: - TimelineDropTargetNSView

public final class TimelineDropTargetNSView: NSView {
    public var pixelsPerSecond: CGFloat = 100
    public var scrollOffset: CGFloat = 0
    public var verticalScrollOffset: CGFloat = 0
    public var onDropAsset: ((MediaAsset, CMTime) -> Void)?
    public var onDropPayload: ((TimelineDragPayload, CMTime) -> Void)?
    public var onDragGuideChanged: ((CGFloat?) -> Void)?
    public var snapCandidatesProvider: (() -> [CMTime])?
    public var resolveTransitionJoinTarget: ((String, CGFloat, CGFloat) -> TransitionDropJoinTarget?)?
    public var onDropTransition: ((String, CGFloat, CGFloat) -> Bool)?
    public var onTransitionDragEnded: (() -> Void)?

    var activeSessionPayload: TimelineDragPayload?
    var cachedSnapCandidates: [CMTime] = [.zero]
    var hasCachedSession = false
    var lastGuideCanvasX: CGFloat?

    override public var isFlipped: Bool { true }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .string])
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        if TransitionDragSessionState.shared.activePayload != nil ||
           TransitionDragSessionState.shared.activePresetID != nil {
            if let ev = NSApplication.shared.currentEvent {
                switch ev.type {
                case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                     .otherMouseDown, .otherMouseUp, .scrollWheel:
                    return nil
                default:
                    break
                }
            }
            return self
        }
        // Only intercept external Finder drags (where the drag originates outside our window).
        // Never intercept in-window `.leftMouseDragged` from internal clip move/trim gestures.
        let currentEvent = NSApplication.shared.currentEvent
        let isExternalEvent = (currentEvent == nil) || (currentEvent?.window !== self.window)
        if isExternalEvent {
            let pbTypes = NSPasteboard(name: .drag).types ?? []
            if pbTypes.contains(NSPasteboard.PasteboardType("public.file-url")) {
                return self
            }
        }
        return nil
    }

    override public func mouseDown(with event: NSEvent) { forwardMouseEvent(event) }
    override public func mouseUp(with event: NSEvent) { forwardMouseEvent(event) }
    override public func rightMouseDown(with event: NSEvent) { forwardMouseEvent(event) }

    private func forwardMouseEvent(_ event: NSEvent) {
        isHidden = true
        let hit = window?.contentView?.hitTest(event.locationInWindow)
        isHidden = false
        guard let hit, hit !== self else { return }
        switch event.type {
        case .leftMouseDown: hit.mouseDown(with: event)
        case .leftMouseUp: hit.mouseUp(with: event)
        case .rightMouseDown: hit.rightMouseDown(with: event)
        default: break
        }
    }

    // MARK: - Drag destination

    override public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let localLoc = convert(sender.draggingLocation, from: nil)
        guard let payload = resolveDragPayload(from: sender) else {
            resetDragSessionCache()
            return []
        }
        activeSessionPayload = payload
        cachedSnapCandidates = snapCandidatesProvider?() ?? [.zero]
        hasCachedSession = true
        lastGuideCanvasX = nil
        if let presetID = payload.transitionPresetID {
            return evaluateTransitionDrag(sender: sender, presetID: presetID, localLoc: localLoc)
        }
        updateDragGuide(at: localLoc.x)
        updateDraggingItem(sender: sender, payload: payload, localLoc: localLoc)
        return .copy
    }

    override public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let localLoc = convert(sender.draggingLocation, from: nil)
        guard let payload = activeSessionPayload ?? resolveDragPayload(from: sender) else {
            publishGuide(nil)
            return []
        }
        if let presetID = payload.transitionPresetID {
            return evaluateTransitionDrag(sender: sender, presetID: presetID, localLoc: localLoc)
        }
        updateDragGuide(at: localLoc.x)
        return .copy
    }

    override public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        let payload = activeSessionPayload ?? (sender.flatMap { resolveDragPayload(from: $0) })
        publishGuide(nil)
        onTransitionDragEnded?()
        if let sender, let payload, payload.clipKind != nil {
            let localLoc = convert(sender.draggingLocation, from: nil)
            restoreThumbnailDraggingItem(sender: sender, payload: payload, localLoc: localLoc)
        }
        resetDragSessionCache()
    }

    override public func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        publishGuide(nil)
        onTransitionDragEnded?()
        resetDragSessionCache()
        TransitionDragSessionState.shared.clear()
    }

    override public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let localLoc = convert(sender.draggingLocation, from: nil)
        guard let payload = activeSessionPayload ?? resolveDragPayload(from: sender) else {
            resetDragSessionCache()
            return false
        }
        defer {
            publishGuide(nil)
            onTransitionDragEnded?()
            resetDragSessionCache()
            TransitionDragSessionState.shared.clear()
        }

        if let presetID = payload.transitionPresetID {
            let canvasX = max(0, localLoc.x + scrollOffset)
            let canvasY = max(0, localLoc.y + verticalScrollOffset)
            return onDropTransition?(presetID, canvasX, canvasY) ?? false
        }

        let dropTime = calculateDropTime(locX: localLoc.x)
        if case .media(let asset) = payload {
            if let onDropPayload {
                onDropPayload(payload, dropTime)
            } else {
                onDropAsset?(asset, dropTime)
            }
            return true
        }
        onDropPayload?(payload, dropTime)
        return true
    }

    // MARK: - Helpers

    func resetDragSessionCache() {
        activeSessionPayload = nil
        cachedSnapCandidates = [.zero]
        hasCachedSession = false
        lastGuideCanvasX = nil
    }

    func publishGuide(_ canvasX: CGFloat?) {
        if let canvasX, let last = lastGuideCanvasX, abs(canvasX - last) < 0.0005 { return }
        if canvasX == nil && lastGuideCanvasX == nil { return }
        lastGuideCanvasX = canvasX
        onDragGuideChanged?(canvasX)
    }

    func evaluateTransitionDrag(sender: any NSDraggingInfo, presetID: String, localLoc: NSPoint) -> NSDragOperation {
        let canvasX = max(0, localLoc.x + scrollOffset)
        let canvasY = max(0, localLoc.y + verticalScrollOffset)
        guard let target = resolveTransitionJoinTarget?(presetID, canvasX, canvasY) else {
            publishGuide(nil)
            return .copy
        }
        publishGuide(target.cutCanvasX)
        return .copy
    }

    func calculateDropTime(locX: CGFloat) -> CMTime {
        let canvasX = max(0, locX + scrollOffset)
        let rawTime = CMTime(seconds: max(0, Double(canvasX / pixelsPerSecond)), preferredTimescale: 600)
        let candidates = hasCachedSession ? cachedSnapCandidates : (snapCandidatesProvider?() ?? [.zero])
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pixelsPerSecond)
        let (snapped, didSnap) = TimelineSnapEngine.snapPoint(time: rawTime, candidates: candidates, threshold: threshold)
        return didSnap ? snapped : TimeRational.snapToFrame(time: rawTime)
    }

    func updateDragGuide(at locX: CGFloat) {
        let effectTime = calculateDropTime(locX: locX)
        publishGuide(CGFloat(CMTimeGetSeconds(effectTime)) * pixelsPerSecond)
    }
}

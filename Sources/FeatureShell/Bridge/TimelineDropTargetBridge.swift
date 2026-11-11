import AppKit
import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Lưu giữ ID của `TransitionPreset` đang được kéo từ `TransitionLibraryView` sang Timeline.
@MainActor
public final class TransitionDragSessionState {
    public static let shared = TransitionDragSessionState()
    public var activePresetID: String?
    private init() {}
}

public struct TimelineDropTargetBridge: NSViewRepresentable {
    private let pixelsPerSecond: CGFloat
    private let scrollOffset: CGFloat
    private let verticalScrollOffset: CGFloat
    private let onDropAsset: (MediaAsset, CMTime) -> Void
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
        view.scrollOffset = scrollOffset
        view.verticalScrollOffset = verticalScrollOffset
        view.onDropAsset = onDropAsset
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
    public var onDragGuideChanged: ((CGFloat?) -> Void)?
    public var snapCandidatesProvider: (() -> [CMTime])?
    public var resolveTransitionJoinTarget: ((String, CGFloat, CGFloat) -> TransitionDropJoinTarget?)?
    public var onDropTransition: ((String, CGFloat, CGFloat) -> Bool)?
    public var onTransitionDragEnded: (() -> Void)?

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
        if let ev = NSApplication.shared.currentEvent {
            switch ev.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                 .otherMouseDown, .otherMouseUp, .scrollWheel:
                return nil
            default:
                break
            }
        }
        if TransitionDragSessionState.shared.activePresetID != nil {
            return self
        }
        let pbTypes = NSPasteboard(name: .drag).types ?? []
        if pbTypes.contains(NSPasteboard.PasteboardType("public.file-url")) || pbTypes.contains(.string) {
            return self
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
        if let hit, hit !== self {
            switch event.type {
            case .leftMouseDown: hit.mouseDown(with: event)
            case .leftMouseUp: hit.mouseUp(with: event)
            case .rightMouseDown: hit.rightMouseDown(with: event)
            default: break
            }
        }
    }

    // MARK: - Drag destination

    override public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let localLoc = convert(sender.draggingLocation, from: nil)
        if let url = extractFileURL(from: sender),
           let type = MediaType.from(fileExtension: url.pathExtension) {
            updateDragGuide(at: localLoc.x)
            updateDraggingItem(sender: sender, url: url, type: type, localLoc: localLoc)
            return .copy
        }
        if let presetID = extractTransitionPresetID(from: sender) {
            return evaluateTransitionDrag(sender: sender, presetID: presetID, localLoc: localLoc)
        }
        return []
    }

    override public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let localLoc = convert(sender.draggingLocation, from: nil)
        if extractFileURL(from: sender) != nil {
            updateDragGuide(at: localLoc.x)
            return .copy
        }
        if let presetID = extractTransitionPresetID(from: sender) {
            return evaluateTransitionDrag(sender: sender, presetID: presetID, localLoc: localLoc)
        }
        onDragGuideChanged?(nil)
        return []
    }

    override public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDragGuideChanged?(nil)
        onTransitionDragEnded?()
        guard let sender else { return }
        if let url = extractFileURL(from: sender),
           let type = MediaType.from(fileExtension: url.pathExtension) {
            let localLoc = convert(sender.draggingLocation, from: nil)
            restoreThumbnailDraggingItem(sender: sender, url: url, type: type, localLoc: localLoc)
        }
    }

    override public func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        onDragGuideChanged?(nil)
        onTransitionDragEnded?()
        TransitionDragSessionState.shared.activePresetID = nil
    }

    override public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let localLoc = convert(sender.draggingLocation, from: nil)
        if let url = extractFileURL(from: sender),
           let type = MediaType.from(fileExtension: url.pathExtension) {
            let dropTime = calculateDropTime(locX: localLoc.x)
            let asset = MediaAsset(url: url, type: type)
            onDropAsset?(asset, dropTime)
            onDragGuideChanged?(nil)
            return true
        }
        if let presetID = extractTransitionPresetID(from: sender) {
            let canvasX = max(0, localLoc.x + scrollOffset)
            let canvasY = max(0, localLoc.y + verticalScrollOffset)
            let didDrop = onDropTransition?(presetID, canvasX, canvasY) ?? false
            onDragGuideChanged?(nil)
            onTransitionDragEnded?()
            TransitionDragSessionState.shared.activePresetID = nil
            return didDrop
        }
        return false
    }

    // MARK: - Helpers

    private func evaluateTransitionDrag(
        sender: any NSDraggingInfo,
        presetID: String,
        localLoc: NSPoint
    ) -> NSDragOperation {
        let canvasX = max(0, localLoc.x + scrollOffset)
        let canvasY = max(0, localLoc.y + verticalScrollOffset)
        guard let target = resolveTransitionJoinTarget?(presetID, canvasX, canvasY) else {
            onDragGuideChanged?(nil)
            return .copy
        }
        onDragGuideChanged?(target.cutCanvasX)
        return .copy
    }

    func extractFileURL(from sender: any NSDraggingInfo) -> URL? {
        if let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first {
            return first
        }
        if let str = sender.draggingPasteboard.string(forType: .fileURL),
           let u = URL(string: str) {
            return u
        }
        return nil
    }

    func extractTransitionPresetID(from sender: any NSDraggingInfo) -> String? {
        let pb = sender.draggingPasteboard
        if let str = pb.string(forType: .string), str.hasPrefix("transition:") {
            return String(str.dropFirst("transition:".count))
        }
        if let strings = pb.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let first = strings.first(where: { $0.hasPrefix("transition:") }) {
            return String(first.dropFirst("transition:".count))
        }
        return TransitionDragSessionState.shared.activePresetID
    }

    private func calculateDropTime(locX: CGFloat) -> CMTime {
        let canvasX = max(0, locX + scrollOffset)
        let seconds = max(0, Double(canvasX / pixelsPerSecond))
        let rawTime = CMTime(seconds: seconds, preferredTimescale: 600)
        let candidates = snapCandidatesProvider?() ?? [.zero]
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pixelsPerSecond)
        let (snapped, didSnap) = TimelineSnapEngine.snapPoint(
            time: rawTime,
            candidates: candidates,
            threshold: threshold
        )
        return didSnap ? snapped : TimeRational.snapToFrame(time: rawTime)
    }

    private func updateDragGuide(at locX: CGFloat) {
        let effectTime = calculateDropTime(locX: locX)
        let snappedCanvasX = CGFloat(CMTimeGetSeconds(effectTime)) * pixelsPerSecond
        onDragGuideChanged?(snappedCanvasX)
    }
}

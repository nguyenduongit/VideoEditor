import AppKit
import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelineDropTargetBridge: NSViewRepresentable {
    private let pixelsPerSecond: CGFloat
    private let scrollOffset: CGFloat
    private let onDropAsset: (MediaAsset, CMTime) -> Void
    private let onDragGuideChanged: ((CGFloat?) -> Void)?
    private let snapCandidatesProvider: (() -> [CMTime])?

    public init(
        pixelsPerSecond: CGFloat,
        scrollOffset: CGFloat,
        onDropAsset: @escaping (MediaAsset, CMTime) -> Void,
        onDragGuideChanged: ((CGFloat?) -> Void)? = nil,
        snapCandidatesProvider: (() -> [CMTime])? = nil
    ) {
        self.pixelsPerSecond = pixelsPerSecond
        self.scrollOffset = scrollOffset
        self.onDropAsset = onDropAsset
        self.onDragGuideChanged = onDragGuideChanged
        self.snapCandidatesProvider = snapCandidatesProvider
    }

    public func makeNSView(context: Context) -> TimelineDropTargetNSView {
        let view = TimelineDropTargetNSView()
        view.pixelsPerSecond = pixelsPerSecond
        view.scrollOffset = scrollOffset
        view.onDropAsset = onDropAsset
        view.onDragGuideChanged = onDragGuideChanged
        view.snapCandidatesProvider = snapCandidatesProvider
        return view
    }

    public func updateNSView(_ nsView: TimelineDropTargetNSView, context: Context) {
        nsView.pixelsPerSecond = pixelsPerSecond
        nsView.scrollOffset = scrollOffset
        nsView.onDropAsset = onDropAsset
        nsView.onDragGuideChanged = onDragGuideChanged
        nsView.snapCandidatesProvider = snapCandidatesProvider
    }
}

// MARK: -

public final class TimelineDropTargetNSView: NSView {
    public var pixelsPerSecond: CGFloat = 100
    public var scrollOffset: CGFloat = 0
    public var onDropAsset: ((MediaAsset, CMTime) -> Void)?
    public var onDragGuideChanged: ((CGFloat?) -> Void)?
    public var snapCandidatesProvider: (() -> [CMTime])?

    override public var isFlipped: Bool { true }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
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
        let pbTypes = NSPasteboard(name: .drag).types ?? []
        if pbTypes.contains(NSPasteboard.PasteboardType("public.file-url")) {
            return self
        }
        return nil
    }

    override public func mouseDown(with event: NSEvent) {
        forwardMouseEvent(event)
    }

    override public func mouseUp(with event: NSEvent) {
        forwardMouseEvent(event)
    }

    override public func rightMouseDown(with event: NSEvent) {
        forwardMouseEvent(event)
    }

    private func forwardMouseEvent(_ event: NSEvent) {
        isHidden = true
        let hit = window?.contentView?.hitTest(event.locationInWindow)
        isHidden = false
        if let hit, hit !== self {
            switch event.type {
            case .leftMouseDown:
                hit.mouseDown(with: event)
            case .leftMouseUp:
                hit.mouseUp(with: event)
            case .rightMouseDown:
                hit.rightMouseDown(with: event)
            default:
                break
            }
        }
    }

    // MARK: - Drag destination

    override public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let url = extractFileURL(from: sender) else { return [] }
        guard let type = MediaType.from(fileExtension: url.pathExtension) else { return [] }
        let localLoc = convert(sender.draggingLocation, from: nil)
        updateDragGuide(at: localLoc.x)
        updateDraggingItem(sender: sender, url: url, type: type, localLoc: localLoc)
        return .copy
    }

    override public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateDragGuide(at: convert(sender.draggingLocation, from: nil).x)
        return .copy
    }

    override public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDragGuideChanged?(nil)
        guard let sender else { return }
        guard let url = extractFileURL(from: sender) else { return }
        guard let type = MediaType.from(fileExtension: url.pathExtension) else { return }
        let localLoc = convert(sender.draggingLocation, from: nil)
        restoreThumbnailDraggingItem(sender: sender, url: url, type: type, localLoc: localLoc)
    }

    override public func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        onDragGuideChanged?(nil)
    }

    override public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let url = extractFileURL(from: sender) else { return false }
        guard let type = MediaType.from(fileExtension: url.pathExtension) else { return false }
        let dropTime = calculateDropTime(locX: convert(sender.draggingLocation, from: nil).x)
        let asset = MediaAsset(url: url, type: type)
        onDropAsset?(asset, dropTime)
        onDragGuideChanged?(nil)
        return true
    }

    // MARK: - Helpers

    private func updateDraggingItem(
        sender: any NSDraggingInfo,
        url: URL,
        type: MediaType,
        localLoc: NSPoint
    ) {
        sender.draggingFormation = .none
        let kind = type.clipKind
        let dur = TimelineMediaDurationResolver.resolveDuration(for: url, type: type)
            ?? CMTime(seconds: 5, preferredTimescale: 600)
        let (targetW, targetH) = calculateTargetDimensions(for: kind, duration: dur)
        let thumb = (kind == .video) ? TimelineClipBlockRenderer.quickThumbnail(for: url) : nil

        guard let blockImg = TimelineClipBlockRenderer.renderImage(
            name: url.lastPathComponent,
            duration: dur,
            kind: kind,
            width: targetW,
            height: targetH,
            thumbnail: thumb
        ) else { return }

        let newFrame = NSRect(
            x: localLoc.x,
            y: localLoc.y - (targetH / 2),
            width: targetW,
            height: targetH
        )

        sender.enumerateDraggingItems(
            options: [],
            for: self,
            classes: [NSURL.self, NSPasteboardItem.self],
            searchOptions: [:]
        ) { item, _, _ in
            item.setDraggingFrame(newFrame, contents: blockImg)
            let comp = NSDraggingImageComponent(key: .icon)
            comp.contents = blockImg
            comp.frame = NSRect(origin: .zero, size: NSSize(width: targetW, height: targetH))
            item.imageComponentsProvider = { [comp] }
        }
    }

    private func restoreThumbnailDraggingItem(
        sender: any NSDraggingInfo,
        url: URL,
        type: MediaType,
        localLoc: NSPoint
    ) {
        sender.draggingFormation = .none
        let thumbImg = TimelineClipBlockRenderer.dragThumbnail(for: url, type: type)
        let thumbSize = thumbImg.size

        let newFrame = NSRect(
            x: localLoc.x,
            y: localLoc.y - (thumbSize.height / 2),
            width: thumbSize.width,
            height: thumbSize.height
        )

        sender.enumerateDraggingItems(
            options: [],
            for: self,
            classes: [NSURL.self, NSPasteboardItem.self],
            searchOptions: [:]
        ) { item, _, _ in
            item.setDraggingFrame(newFrame, contents: thumbImg)
            let comp = NSDraggingImageComponent(key: .icon)
            comp.contents = thumbImg
            comp.frame = NSRect(origin: .zero, size: thumbSize)
            item.imageComponentsProvider = { [comp] }
        }
    }

    private func calculateTargetDimensions(
        for kind: ClipKind,
        duration: CMTime
    ) -> (width: CGFloat, height: CGFloat) {
        let targetH: CGFloat = {
            switch kind {
            case .video: return DSSize.videoLayerHeight - 6
            case .audio, .image: return DSSize.mediaLayerHeight - 6
            case .text, .adjustment: return DSSize.compactLayerHeight - 6
            }
        }()

        let rawW = CGFloat(CMTimeGetSeconds(duration)) * pixelsPerSecond
        let targetW = max(28.0, rawW)
        return (targetW, targetH)
    }

    private func extractFileURL(from sender: any NSDraggingInfo) -> URL? {
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
        let effectiveTime = didSnap ? snapped : TimeRational.snapToFrame(time: rawTime)
        let snappedCanvasX = CGFloat(CMTimeGetSeconds(effectiveTime)) * pixelsPerSecond
        onDragGuideChanged?(snappedCanvasX)
    }
}

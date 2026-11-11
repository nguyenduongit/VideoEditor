import AppKit
import CoreMedia
import Domain
import DesignSystem

extension TimelineDropTargetNSView {
    func updateDraggingItem(
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

    func updateTransitionDraggingItem(
        sender: any NSDraggingInfo,
        target: TransitionDropJoinTarget
    ) {
        sender.draggingFormation = .none
        let w = max(14.0, target.overlayWidth)
        let h = max(10.0, target.overlayHeight)
        let cutLocalX = target.cutCanvasX - scrollOffset
        let cutLocalY = target.layerMidY - verticalScrollOffset
        let previewImg = renderCyanTransitionPreview(width: w, height: h)
        let newFrame = NSRect(
            x: cutLocalX - (w / 2),
            y: cutLocalY - (h / 2),
            width: w,
            height: h
        )

        sender.enumerateDraggingItems(
            options: [],
            for: self,
            classes: [NSString.self, NSPasteboardItem.self],
            searchOptions: [:]
        ) { item, _, _ in
            item.setDraggingFrame(newFrame, contents: previewImg)
            let comp = NSDraggingImageComponent(key: .icon)
            comp.contents = previewImg
            comp.frame = NSRect(origin: .zero, size: NSSize(width: w, height: h))
            item.imageComponentsProvider = { [comp] }
        }
    }

    private func renderCyanTransitionPreview(width: CGFloat, height: CGFloat) -> NSImage {
        let size = NSSize(width: width, height: height)
        let img = NSImage(size: size)
        img.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        NSColor(DSColors.toggleCyan).withAlphaComponent(0.60).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.90).setStroke()
        path.lineWidth = 1.2
        path.stroke()

        let midLine = NSRect(x: width * 0.5 - 0.5, y: 0, width: 1.0, height: height)
        NSColor.white.withAlphaComponent(0.80).setFill()
        midLine.fill()
        img.unlockFocus()
        return img
    }

    func restoreThumbnailDraggingItem(
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

    func calculateTargetDimensions(
        for kind: ClipKind,
        duration: CMTime
    ) -> (width: CGFloat, height: CGFloat) {
        let targetH = kind.presentation.defaultLayerHeight - 6
        let rawW = CGFloat(CMTimeGetSeconds(duration)) * pixelsPerSecond
        let targetW = max(28.0, rawW)
        return (targetW, targetH)
    }
}

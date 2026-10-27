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

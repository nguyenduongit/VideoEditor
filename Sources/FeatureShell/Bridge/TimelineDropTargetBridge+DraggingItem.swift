import AppKit
import CoreMedia
import Domain
import DesignSystem

/// Đại diện hợp nhất cho mọi loại tài nguyên kéo từ Sidebar (hoặc Finder) thả vào Timeline.
public enum TimelineDragPayload: Sendable, Equatable {
    case media(MediaAsset)
    case audio(AudioPreset)
    case text(TextPreset)
    case defaultText
    case sticker(StickerPreset)
    case effect(EffectPreset)
    case adjustment(AdjustmentPreset)
    case defaultAdjustment
    case transition(TransitionPreset)
    case transitionID(String)

    public var clipKind: ClipKind? {
        switch self {
        case .media(let asset): return asset.type.clipKind
        case .audio: return .audio
        case .text, .defaultText: return .text
        case .sticker: return .sticker
        case .effect: return .effect
        case .adjustment, .defaultAdjustment: return .adjustment
        case .transition, .transitionID: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .media(let asset): return asset.name
        case .audio(let preset): return preset.name
        case .text(let preset): return preset.name
        case .defaultText: return "Default Text"
        case .sticker(let preset): return preset.name
        case .effect(let preset): return preset.name
        case .adjustment(let preset): return preset.name
        case .defaultAdjustment: return "Adjustment Layer"
        case .transition(let preset): return preset.name
        case .transitionID(let id): return id
        }
    }

    public var transitionPresetID: String? {
        switch self {
        case .transition(let preset): return preset.id
        case .transitionID(let id): return id
        default: return nil
        }
    }

    public var pasteboardToken: String {
        switch self {
        case .media(let asset): return "timeline-asset:media:\(asset.id.uuidString)"
        case .audio(let preset): return "timeline-asset:audio:\(preset.id)"
        case .text(let preset): return "timeline-asset:text:\(preset.id)"
        case .defaultText: return "timeline-asset:text:default"
        case .sticker(let preset): return "timeline-asset:sticker:\(preset.id)"
        case .effect(let preset): return "timeline-asset:effect:\(preset.id)"
        case .adjustment(let preset): return "timeline-asset:adjustment:\(preset.id)"
        case .defaultAdjustment: return "timeline-asset:adjustment:default"
        case .transition(let preset): return "transition:\(preset.id)"
        case .transitionID(let id): return "transition:\(id)"
        }
    }

    public func resolvedDuration() -> CMTime {
        switch self {
        case .media(let asset):
            return TimelineMediaDurationResolver.resolveDuration(for: asset.url, type: asset.type)
                ?? CMTime(seconds: 5.0, preferredTimescale: 600)
        case .audio(let preset):
            let sec = preset.id == "audio_dance_beat" ? 8.0 : (preset.duration > 0 ? preset.duration : 5.0)
            return CMTime(seconds: sec, preferredTimescale: 600)
        case .text(let preset):
            let sec = preset.config.animation.hasScriptAnimation
                ? max(preset.defaultDuration, preset.config.animation.scriptDuration)
                : preset.defaultDuration
            return CMTime(seconds: max(0.5, sec), preferredTimescale: 600)
        case .defaultText, .adjustment, .defaultAdjustment:
            return CMTime(seconds: 5.0, preferredTimescale: 600)
        case .sticker(let preset):
            let sec = preset.defaultDuration > 0.05 ? preset.defaultDuration : 3.0
            return CMTime(seconds: sec, preferredTimescale: 600)
        case .effect(let preset):
            return CMTime(seconds: max(0.5, preset.defaultDuration), preferredTimescale: 600)
        case .transition(let preset):
            return CMTime(seconds: max(0.1, preset.defaultDuration), preferredTimescale: 600)
        case .transitionID:
            return CMTime(seconds: 1.0, preferredTimescale: 600)
        }
    }
}

extension TimelineDropTargetNSView {
    func resolveDragPayload(from sender: any NSDraggingInfo) -> TimelineDragPayload? {
        if let str = extractPasteboardString(from: sender) {
            if str.hasPrefix("transition:") {
                let id = String(str.dropFirst("transition:".count))
                if let active = TransitionDragSessionState.shared.activePayload,
                   active.transitionPresetID == id {
                    return active
                }
                return .transitionID(id)
            }
            if str.hasPrefix("timeline-asset:") {
                if let active = TransitionDragSessionState.shared.activePayload,
                   active.pasteboardToken == str {
                    return active
                }
                return decodeFallbackAssetToken(str)
            }
        }
        if let url = extractFileURL(from: sender),
           let type = MediaType.from(fileExtension: url.pathExtension) {
            if case .media(let activeAsset) = TransitionDragSessionState.shared.activePayload,
               activeAsset.url == url {
                return .media(activeAsset)
            }
            return .media(MediaAsset(url: url, type: type))
        }
        if let active = TransitionDragSessionState.shared.activePayload {
            return active
        }
        if let presetID = TransitionDragSessionState.shared.activePresetID {
            return .transitionID(presetID)
        }
        return nil
    }

    private func decodeFallbackAssetToken(_ token: String) -> TimelineDragPayload? {
        if token == "timeline-asset:text:default" { return .defaultText }
        if token == "timeline-asset:adjustment:default" { return .defaultAdjustment }
        return TransitionDragSessionState.shared.activePayload
    }

    private func extractPasteboardString(from sender: any NSDraggingInfo) -> String? {
        let pb = sender.draggingPasteboard
        if let str = pb.string(forType: .string) {
            return str
        }
        if let strings = pb.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let first = strings.first {
            return first
        }
        return nil
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
        resolveDragPayload(from: sender)?.transitionPresetID
    }

    func updateDraggingItem(
        sender: any NSDraggingInfo,
        payload: TimelineDragPayload,
        localLoc: NSPoint
    ) {
        guard let kind = payload.clipKind else { return }
        sender.draggingFormation = .none
        let dur = payload.resolvedDuration()
        let (targetW, targetH) = calculateTargetDimensions(for: kind, duration: dur)
        let thumb: NSImage? = {
            if case .media(let asset) = payload, kind == .video {
                return TimelineClipBlockRenderer.quickThumbnail(for: asset.url)
            }
            return nil
        }()

        guard let blockImg = TimelineClipBlockRenderer.renderImage(
            name: payload.displayName,
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
        applyDraggingImage(blockImg, frame: newFrame, to: sender)
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
        let previewImg = TransitionDragSourceNSView.renderCyanOverlayImage(width: w, height: h)
        let newFrame = NSRect(
            x: cutLocalX - (w / 2),
            y: cutLocalY - (h / 2),
            width: w,
            height: h
        )
        applyDraggingImage(previewImg, frame: newFrame, to: sender)
    }

    func restoreThumbnailDraggingItem(
        sender: any NSDraggingInfo,
        payload: TimelineDragPayload,
        localLoc: NSPoint
    ) {
        sender.draggingFormation = .none
        let thumbImg = TimelineClipBlockRenderer.dragThumbnail(for: payload)
        let thumbSize = thumbImg.size
        let newFrame = NSRect(
            x: localLoc.x,
            y: localLoc.y - (thumbSize.height / 2),
            width: thumbSize.width,
            height: thumbSize.height
        )
        applyDraggingImage(thumbImg, frame: newFrame, to: sender)
    }

    private func applyDraggingImage(
        _ image: NSImage,
        frame: NSRect,
        to sender: any NSDraggingInfo
    ) {
        let size = frame.size
        sender.enumerateDraggingItems(
            options: [],
            for: self,
            classes: [NSURL.self, NSString.self, NSPasteboardItem.self],
            searchOptions: [:]
        ) { item, _, _ in
            item.setDraggingFrame(frame, contents: image)
            let comp = NSDraggingImageComponent(key: .icon)
            comp.contents = image
            comp.frame = NSRect(origin: .zero, size: size)
            item.imageComponentsProvider = { [comp] }
        }
    }

    func calculateTargetDimensions(
        for kind: ClipKind,
        duration: CMTime
    ) -> (width: CGFloat, height: CGFloat) {
        TimelineClipBlockRenderer.blockDimensions(
            for: kind,
            duration: duration,
            pixelsPerSecond: pixelsPerSecond
        )
    }
}

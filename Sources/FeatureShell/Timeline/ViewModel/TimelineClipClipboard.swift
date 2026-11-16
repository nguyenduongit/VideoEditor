import Foundation
import CoreMedia
import Domain

/// Nhóm thuộc tính có thể sao chép & dán có chọn lọc giữa các Clip.
public enum ClipAttributeCategory: String, CaseIterable, Identifiable, Sendable, Hashable {
    case transform
    case colorGrading
    case mask
    case audio
    case speed
    case textStyle
    case textAnimation
    case effectConfig
    case keyframes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .transform: return "Transform & Blend"
        case .colorGrading: return "Color Adjustment"
        case .mask: return "Mask"
        case .audio: return "Audio & Fade"
        case .speed: return "Speed"
        case .textStyle: return "Text Style & Background"
        case .textAnimation: return "Text Animation"
        case .effectConfig: return "Effect Parameters"
        case .keyframes: return "Keyframes"
        }
    }

    public var systemImage: String {
        switch self {
        case .transform: return "arrow.up.and.down.and.arrow.left.and.right"
        case .colorGrading: return "camera.filters"
        case .mask: return "circle.dashed"
        case .audio: return "speaker.wave.2"
        case .speed: return "gauge.with.needle"
        case .textStyle: return "textformat"
        case .textAnimation: return "sparkles"
        case .effectConfig: return "wand.and.stars"
        case .keyframes: return "diamond"
        }
    }
}

/// Bộ trích xuất & trộn thuộc tính an toàn, bảo toàn dữ liệu gốc (`mediaURL`, `textContent`, `beatMarkers`).
public enum TimelineClipAttributeExtractor {
    private static let transformKeys: [String] = [
        "positionX", "positionY", "scale", "scaleWidth", "scaleHeight", "uniformScale",
        "rotation", "skewX", "skewY", "perspectiveX", "perspectiveY",
        "flipHorizontal", "flipVertical", "blendMode", "opacity"
    ]

    private static let maskKeys: [String] = [
        "maskType", "maskInvert", "maskFeather", "maskPositionX", "maskPositionY",
        "maskOffsetY", "maskRotation", "maskRadiusX", "maskRadiusY",
        "maskWidth", "maskHeight", "maskCornerRadius", "maskFilmHeight"
    ]

    private static let audioKeys: [String] = [
        "volume", "isClipMuted", "preMuteVolume", "fadeIn", "fadeOut", "pan", "pitchPreservation"
    ]

    public static func availableCategories(for clip: TimelineClip) -> [ClipAttributeCategory] {
        var list: [ClipAttributeCategory] = []
        switch clip.kind {
        case .video:
            list = [.transform, .colorGrading, .mask, .audio, .speed, .keyframes]
        case .image:
            list = [.transform, .colorGrading, .mask, .keyframes]
        case .audio:
            list = [.audio, .speed, .keyframes]
        case .text:
            list = [.transform, .textStyle, .textAnimation, .keyframes]
        case .adjustment:
            list = [.colorGrading, .keyframes]
        case .effect:
            list = [.effectConfig, .keyframes]
        case .sticker:
            list = [.transform, .textAnimation, .speed, .keyframes]
        }
        return list
    }

    public static func compatibleCategories(from source: TimelineClip, to target: TimelineClip) -> [ClipAttributeCategory] {
        let targetSet = Set(availableCategories(for: target))
        return availableCategories(for: source).filter { targetSet.contains($0) }
    }

    public static func apply(
        from source: TimelineClip,
        categories: Set<ClipAttributeCategory>,
        to target: TimelineClip
    ) -> [String: PropertyValue] {
        var updated = target.properties
        let allowed = Set(compatibleCategories(from: source, to: target)).intersection(categories)

        if allowed.contains(.transform) {
            copyKeys(transformKeys, from: source.properties, to: &updated)
            syncStickerTransform(from: source, to: &updated)
        }
        if allowed.contains(.colorGrading) {
            copyKeys(["adjustmentConfig", "intensity"], from: source.properties, to: &updated)
        }
        if allowed.contains(.mask) {
            copyKeys(maskKeys, from: source.properties, to: &updated)
        }
        if allowed.contains(.audio) {
            copyKeys(audioKeys, from: source.properties, to: &updated)
        }
        if allowed.contains(.speed) {
            copyKeys(["speed", "pitchPreservation"], from: source.properties, to: &updated)
        }
        if allowed.contains(.effectConfig) {
            copyKeys(["effectConfig", "intensity", "blurRadius"], from: source.properties, to: &updated)
        }
        if allowed.contains(.keyframes) {
            copyKeys([ClipKeyframeMap.propertyKey], from: source.properties, to: &updated)
        }
        if allowed.contains(.textStyle) || allowed.contains(.textAnimation) || (allowed.contains(.transform) && target.kind == .text) {
            applyTextCategories(allowed: allowed, from: source, target: target, into: &updated)
        }
        return updated
    }

    private static func copyKeys(_ keys: [String], from source: [String: PropertyValue], to dest: inout [String: PropertyValue]) {
        for key in keys {
            if let value = source[key] {
                dest[key] = value
            } else {
                dest.removeValue(forKey: key)
            }
        }
    }

    private static func syncStickerTransform(from source: TimelineClip, to dest: inout [String: PropertyValue]) {
        guard let dstJson = dest["stickerConfig"]?.asString,
              var dstCfg = StickerConfiguration.decode(from: dstJson) else { return }
        if let srcJson = source.properties["stickerConfig"]?.asString,
           let srcCfg = StickerConfiguration.decode(from: srcJson) {
            dstCfg.flipHorizontal = srcCfg.flipHorizontal
            dstCfg.flipVertical = srcCfg.flipVertical
            dstCfg.blendMode = srcCfg.blendMode
        }
        if let encoded = dstCfg.encodeToJSON() {
            dest["stickerConfig"] = .string(encoded)
        }
    }

    private static func applyTextCategories(
        allowed: Set<ClipAttributeCategory>,
        from source: TimelineClip,
        target: TimelineClip,
        into dest: inout [String: PropertyValue]
    ) {
        if target.kind == .sticker, allowed.contains(.textAnimation),
           let srcStickerJson = source.properties["stickerConfig"]?.asString,
           let srcSticker = StickerConfiguration.decode(from: srcStickerJson),
           let dstStickerJson = dest["stickerConfig"]?.asString,
           var dstSticker = StickerConfiguration.decode(from: dstStickerJson) {
            dstSticker.animation = srcSticker.animation
            if let json = dstSticker.encodeToJSON() { dest["stickerConfig"] = .string(json) }
            return
        }
        guard target.kind == .text, source.kind == .text else { return }
        let srcCfg = source.properties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) }
            ?? TextConfiguration(content: target.name)
        var dstCfg = dest["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) }
            ?? TextConfiguration(content: target.properties["textContent"]?.asString ?? target.name)

        if allowed.contains(.textStyle) {
            let preservedContent = dstCfg.content
            let preservedPosX = dstCfg.positionX, preservedPosY = dstCfg.positionY
            let preservedScale = dstCfg.scale, preservedRot = dstCfg.rotation, preservedOp = dstCfg.opacity
            let preservedAnim = dstCfg.animation
            dstCfg = srcCfg
            dstCfg.content = preservedContent
            dstCfg.positionX = preservedPosX; dstCfg.positionY = preservedPosY
            dstCfg.scale = preservedScale; dstCfg.rotation = preservedRot; dstCfg.opacity = preservedOp
            dstCfg.animation = preservedAnim
            if let fs = source.properties["fontSize"] { dest["fontSize"] = fs }
        }
        if allowed.contains(.textAnimation) {
            dstCfg.animation = srcCfg.animation
        }
        if allowed.contains(.transform) {
            dstCfg.positionX = srcCfg.positionX; dstCfg.positionY = srcCfg.positionY
            dstCfg.scale = srcCfg.scale; dstCfg.rotation = srcCfg.rotation
            dstCfg.skewX = srcCfg.skewX; dstCfg.skewY = srcCfg.skewY; dstCfg.opacity = srcCfg.opacity
        }
        if let json = dstCfg.encodeToJSON() { dest["textConfig"] = .string(json) }
    }
}

/// Gom toàn bộ callback Context Menu & trạng thái Clipboard truyền xuống từng Clip.
@MainActor
public struct TimelineClipContextActions {
    public let playheadTime: CMTime
    public let canPasteClip: Bool
    public let canPasteAttributes: Bool
    public let onCut: (UUID) -> Void
    public let onCopy: (UUID) -> Void
    public let onPaste: () -> Void
    public let onDuplicate: (UUID) -> Void
    public let onDelete: (UUID) -> Void
    public let onSplitAtPlayhead: (UUID) -> Void
    public let onCopyAttributes: (UUID) -> Void
    public let onPasteAttributes: (UUID) -> Void
    public let onResetAttributes: (UUID) -> Void
    public let onToggleMuteClipAudio: (UUID) -> Void
    public let onSetSpeed: (UUID, Double) -> Void
    public let onFlip: (UUID, Bool) -> Void
    public let onResetTransform: (UUID) -> Void
    public let onSetDuration: (UUID, Double) -> Void
    public let onMatchDurationBelow: (UUID) -> Void
    public let onApplyTextStyleToTrack: (UUID) -> Void
    public let onAutoMarkBeats: (UUID, AudioBeatDetectionMode) -> Void
    public let onToggleBeatAtPlayhead: (UUID) -> Void
    public let onClearBeats: (UUID) -> Void
    public let onSetAudioFade: (UUID, Double) -> Void

    public init(
        playheadTime: CMTime,
        canPasteClip: Bool,
        canPasteAttributes: Bool,
        onCut: @escaping (UUID) -> Void,
        onCopy: @escaping (UUID) -> Void,
        onPaste: @escaping () -> Void,
        onDuplicate: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onSplitAtPlayhead: @escaping (UUID) -> Void,
        onCopyAttributes: @escaping (UUID) -> Void,
        onPasteAttributes: @escaping (UUID) -> Void,
        onResetAttributes: @escaping (UUID) -> Void,
        onToggleMuteClipAudio: @escaping (UUID) -> Void,
        onSetSpeed: @escaping (UUID, Double) -> Void,
        onFlip: @escaping (UUID, Bool) -> Void,
        onResetTransform: @escaping (UUID) -> Void,
        onSetDuration: @escaping (UUID, Double) -> Void,
        onMatchDurationBelow: @escaping (UUID) -> Void,
        onApplyTextStyleToTrack: @escaping (UUID) -> Void,
        onAutoMarkBeats: @escaping (UUID, AudioBeatDetectionMode) -> Void,
        onToggleBeatAtPlayhead: @escaping (UUID) -> Void,
        onClearBeats: @escaping (UUID) -> Void,
        onSetAudioFade: @escaping (UUID, Double) -> Void
    ) {
        self.playheadTime = playheadTime
        self.canPasteClip = canPasteClip
        self.canPasteAttributes = canPasteAttributes
        self.onCut = onCut
        self.onCopy = onCopy
        self.onPaste = onPaste
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onSplitAtPlayhead = onSplitAtPlayhead
        self.onCopyAttributes = onCopyAttributes
        self.onPasteAttributes = onPasteAttributes
        self.onResetAttributes = onResetAttributes
        self.onToggleMuteClipAudio = onToggleMuteClipAudio
        self.onSetSpeed = onSetSpeed
        self.onFlip = onFlip
        self.onResetTransform = onResetTransform
        self.onSetDuration = onSetDuration
        self.onMatchDurationBelow = onMatchDurationBelow
        self.onApplyTextStyleToTrack = onApplyTextStyleToTrack
        self.onAutoMarkBeats = onAutoMarkBeats
        self.onToggleBeatAtPlayhead = onToggleBeatAtPlayhead
        self.onClearBeats = onClearBeats
        self.onSetAudioFade = onSetAudioFade
    }
}

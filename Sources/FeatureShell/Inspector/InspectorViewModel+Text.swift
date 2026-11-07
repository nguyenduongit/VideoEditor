import Foundation
import Domain

/// Mở rộng `InspectorViewModel` cho cấu hình lõi đơn dòng hợp nhất của Module `Text` và cầu nối `Sticker` (`StickerConfiguration` + `Animation`).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension InspectorViewModel {
    /// Cấu hình văn bản đơn dòng hiện hành của Text Clip (hoặc cấu hình mang `animation` của Sticker Clip đang chọn).
    public var textConfiguration: TextConfiguration {
        if selectedClip?.kind == .sticker {
            let sCfg = stickerConfiguration
            var carrier = TextConfiguration(content: selectedClip?.name ?? "Sticker")
            carrier.animation = sCfg.animation
            carrier.animation.scope = .wholeBlock
            return carrier
        }
        let str = liveProperties["textConfig"]?.asString
            ?? selectedClip?.properties["textConfig"]?.asString ?? ""
        return TextConfiguration.decode(from: str) ?? TextConfiguration()
    }

    /// Cấu hình hiện hành của Sticker Clip đang chọn.
    public var stickerConfiguration: StickerConfiguration {
        let str = liveProperties["stickerConfig"]?.asString
            ?? selectedClip?.properties["stickerConfig"]?.asString ?? ""
        var cfg = StickerConfiguration.decode(from: str) ?? StickerConfiguration(
            systemSymbolFallback: liveProperties["systemSymbolFallback"]?.asString
                ?? selectedClip?.properties["systemSymbolFallback"]?.asString
                ?? "face.smiling"
        )
        if let fh = liveProperties["flipHorizontal"]?.asBool { cfg.flipHorizontal = fh }
        if let fv = liveProperties["flipVertical"]?.asBool { cfg.flipVertical = fv }
        if let spd = liveProperties["speed"]?.asNumber { cfg.playbackSpeed = spd }
        if let loopRaw = liveProperties["loopMode"]?.asString, let loop = StickerLoopMode(rawValue: loopRaw) {
            cfg.loopMode = loop
        }
        return cfg
    }

    public var rootTextConfiguration: TextConfiguration {
        textConfiguration
    }

    public var activeTextLayerConfiguration: TextConfiguration {
        textConfiguration
    }

    /// Cập nhật cấu hình văn bản hiện hành (hoặc `animation` của Sticker khi đang chọn Sticker Clip).
    public func updateTextConfiguration(_ config: TextConfiguration, commit: Bool) {
        if selectedClip?.kind == .sticker {
            var sCfg = stickerConfiguration
            sCfg.animation = config.animation
            sCfg.animation.scope = .wholeBlock
            updateStickerConfiguration(sCfg, commit: commit)
            return
        }
        guard let json = config.encodeToJSON() else { return }
        if commit {
            commitTextProperty(key: "textConfig", text: json)
        } else {
            updateLiveText(key: "textConfig", text: json)
        }
    }

    /// Cập nhật `StickerConfiguration` và đồng bộ ngược các thuộc tính phẳng (`flipHorizontal`, `flipVertical`, `speed`, `loopMode`).
    public func updateStickerConfiguration(_ config: StickerConfiguration, commit: Bool) {
        guard let json = config.encodeToJSON() else { return }
        liveProperties["flipHorizontal"] = .bool(config.flipHorizontal)
        liveProperties["flipVertical"] = .bool(config.flipVertical)
        liveProperties["speed"] = .number(config.playbackSpeed)
        liveProperties["loopMode"] = .string(config.loopMode.rawValue)
        if let sym = config.systemSymbolFallback {
            liveProperties["systemSymbolFallback"] = .string(sym)
        }
        if commit {
            commitTextProperty(key: "stickerConfig", text: json)
        } else {
            updateLiveText(key: "stickerConfig", text: json)
        }
    }

    public func updateActiveTextLayer(_ updated: TextConfiguration, commit: Bool) {
        updateTextConfiguration(updated, commit: commit)
    }

    public func applyRootTextConfiguration(_ root: TextConfiguration, commit: Bool) {
        updateTextConfiguration(root, commit: commit)
    }

    /// Đồng bộ các thuộc tính phẳng phục vụ Canvas Direct Manipulation & Keyframe Track.
    func syncTextFlatProperties(from cfg: TextConfiguration) {
        liveProperties["positionX"] = .number(cfg.positionX)
        liveProperties["positionY"] = .number(cfg.positionY)
        liveProperties["scale"] = .number(cfg.scale)
        liveProperties["rotation"] = .number(cfg.rotation)
        liveProperties["opacity"] = .number(cfg.opacity)
        liveProperties["fontSize"] = .number(cfg.fontSize)
        liveProperties["textContent"] = .string(cfg.content)
        liveProperties["fontName"] = .string(cfg.fontName)
    }

    /// Đồng bộ ngược thay đổi thanh trượt/keyframe phẳng vào `textConfig` hoặc `stickerConfig`.
    func syncTextConfigFromLiveNumber(key: String, value: Double, clip: TimelineClip) {
        if clip.kind == .sticker, key == "speed" {
            var sCfg = stickerConfiguration
            sCfg.playbackSpeed = max(0.25, min(4.0, value))
            if let json = sCfg.encodeToJSON() {
                liveProperties["stickerConfig"] = .string(json)
            }
            return
        }
        guard clip.kind == .text else { return }
        var cfg = liveProperties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) }
            ?? clip.properties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) }
            ?? TextConfiguration()
        switch key {
        case "positionX": cfg.positionX = value
        case "positionY": cfg.positionY = value
        case "scale": cfg.scale = value
        case "rotation": cfg.rotation = value
        case "opacity": cfg.opacity = value
        case "fontSize": cfg.fontSize = value
        default: return
        }
        if let json = cfg.encodeToJSON() {
            liveProperties["textConfig"] = .string(json)
        }
    }
}

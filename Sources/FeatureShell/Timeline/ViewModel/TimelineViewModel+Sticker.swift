import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Thêm một clip Sticker (GIF / APNG) vào Timeline tại thời điểm chỉ định hoặc playhead hiện tại.
    /// Tuân thủ quy tắc R3.1 (Hàm <= 50 dòng) và R7.1 (Transaction Command) của AGENTS.md.
    public func addStickerPreset(_ preset: StickerPreset, at time: CMTime? = nil) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        let frames = max(15, Int64(round(preset.defaultDuration * Double(TimeRational.defaultFPS))))
        let resolvedDuration = CMTime(value: frames, timescale: TimeRational.defaultFPS)
        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)

        var properties = dependencies.propertyRegistry.defaultProperties(for: .sticker)
        if let json = preset.config.encodeToJSON() {
            properties["stickerConfig"] = .string(json)
        }
        properties["scale"] = .number(1.0)
        properties["positionX"] = .number(0.0)
        properties["positionY"] = .number(0.0)
        properties["rotation"] = .number(0.0)
        properties["opacity"] = .number(1.0)
        properties["flipHorizontal"] = .bool(preset.config.flipHorizontal)
        properties["flipVertical"] = .bool(preset.config.flipVertical)
        properties["speed"] = .number(preset.config.playbackSpeed)
        properties["loopMode"] = .string(preset.config.loopMode.rawValue)
        properties["systemSymbolFallback"] = .string(preset.systemSymbolFallback)
        properties["originPresetId"] = .string(preset.id)
        properties["originPresetName"] = .string(preset.name)

        let clip = TimelineClip(
            assetID: nil,
            name: preset.name,
            kind: .sticker,
            timeRange: timeRange,
            properties: properties
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
    }
}


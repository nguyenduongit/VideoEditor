import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Thêm một clip Effect Layer vào timeline tại thời điểm chỉ định hoặc playhead hiện tại.
    /// Tuân thủ quy tắc R3.1 (Hàm <= 50 dòng) và R7.1 (Transaction Command / Undo-Redo) của AGENTS.md.
    public func addEffectClip(
        named name: String? = nil,
        config: EffectConfiguration = EffectConfiguration(),
        durationSeconds: Double? = nil,
        at time: CMTime? = nil
    ) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        let resolvedSeconds = durationSeconds ?? 3.0
        let frames = max(15, Int64(round(resolvedSeconds * Double(TimeRational.defaultFPS))))
        let resolvedDuration = CMTime(value: frames, timescale: TimeRational.defaultFPS)
        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)

        var properties = dependencies.propertyRegistry.defaultProperties(for: .effect)
        if let json = config.encodeToJSON() {
            properties["effectConfig"] = .string(json)
        }
        properties["effectType"] = .string(config.type.rawValue)
        properties["intensity"] = .number(config.intensity)
        properties["speed"] = .number(config.speed)

        let clipName = name ?? config.type.displayName
        let clip = TimelineClip(
            assetID: nil,
            name: clipName,
            kind: .effect,
            timeRange: timeRange,
            properties: properties
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
    }
}

import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Thêm một clip Text vào timeline tại thời điểm chỉ định hoặc playhead hiện tại.
    /// Tuân thủ quy tắc R3.1 (Hàm <= 50 dòng) và R7.1 (Transaction Command / Undo-Redo) của AGENTS.md.
    public func addTextClip(
        named name: String = "Văn bản",
        config: TextConfiguration = TextConfiguration(),
        durationSeconds: Double = 5.0,
        at time: CMTime? = nil,
        originPresetID: String? = nil,
        originPresetName: String? = nil
    ) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        let resolvedDuration = resolveTextClipDuration(preferredSeconds: durationSeconds, at: targetStart)
        var finalConfig = config
        TextAutoFitter.autoFitScaleToCanvasWidth(
            config: &finalConfig,
            canvasSize: aspectRatio.renderSize,
            targetWidthRatio: 0.80
        )
        let clip = makeTextTimelineClip(
            named: name,
            config: finalConfig,
            timeRange: CMTimeRange(start: targetStart, duration: resolvedDuration),
            originPresetID: originPresetID,
            originPresetName: originPresetName
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
    }

    /// Thêm một mẫu `TextPreset` đơn dòng hợp nhất vào Timeline.
    public func addTextPreset(_ preset: TextPreset, at time: CMTime? = nil) {
        if preset.id == "default" {
            addTextClip(named: preset.name, config: preset.config, at: time)
            return
        }
        let proposedStart = time ?? currentTime
        let baseStart = TimeRational.snapToFrame(time: proposedStart)
        let baseDuration = resolveTextClipDuration(preferredSeconds: preset.defaultDuration, at: baseStart)

        var presetConfig = preset.config
        TextAutoFitter.autoFitScaleToCanvasWidth(
            config: &presetConfig,
            canvasSize: aspectRatio.renderSize,
            targetWidthRatio: 0.80
        )
        let unifiedClip = makeTextTimelineClip(
            named: preset.name,
            config: presetConfig,
            timeRange: CMTimeRange(start: baseStart, duration: baseDuration),
            originPresetID: preset.id,
            originPresetName: preset.name
        )
        var simulatedLayers = layers
        let layerID = allocateLayerID(for: unifiedClip, in: &simulatedLayers)

        applyAddedClips([(unifiedClip, layerID)])
        selectedClipIDs = [unifiedClip.id]
    }

    private func resolveTextClipDuration(preferredSeconds: Double, at targetStart: CMTime) -> CMTime {
        let frames = max(15, Int64(round(max(0.5, preferredSeconds) * Double(TimeRational.defaultFPS))))
        var resolvedDuration = CMTime(value: frames, timescale: TimeRational.defaultFPS)
        let mediaClips = layers.flatMap(\.clips).filter { $0.kind == .video || $0.kind == .image }
        if let currentMediaClip = mediaClips.first(where: { $0.timeRange.containsTime(targetStart) }) {
            let remaining = CMTimeSubtract(currentMediaClip.timeRange.end, targetStart)
            if remaining > .zero {
                resolvedDuration = min(resolvedDuration, remaining)
            }
        }
        return resolvedDuration
    }

    private func makeTextTimelineClip(
        named name: String,
        config: TextConfiguration,
        timeRange: CMTimeRange,
        originPresetID: String? = nil,
        originPresetName: String? = nil
    ) -> TimelineClip {
        var properties = dependencies.propertyRegistry.defaultProperties(for: .text)
        if let json = config.encodeToJSON() {
            properties["textConfig"] = .string(json)
        }
        properties["textContent"] = .string(config.content)
        properties["fontSize"] = .number(config.fontSize)
        properties["positionX"] = .number(config.positionX)
        properties["positionY"] = .number(config.positionY)
        properties["scale"] = .number(config.scale)
        properties["rotation"] = .number(config.rotation)
        properties["opacity"] = .number(config.opacity)
        if let originPresetID {
            properties["originPresetId"] = .string(originPresetID)
            properties["originPresetName"] = .string(originPresetName ?? name)
        }

        return TimelineClip(
            assetID: nil,
            name: config.content.isEmpty ? name : config.content,
            kind: .text,
            timeRange: timeRange,
            properties: properties
        )
    }
}

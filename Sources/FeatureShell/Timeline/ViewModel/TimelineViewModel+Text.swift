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
        at time: CMTime? = nil
    ) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        let resolvedDuration = resolveTextClipDuration(preferredSeconds: durationSeconds, at: targetStart)
        let clip = makeTextTimelineClip(
            named: name,
            config: config,
            timeRange: CMTimeRange(start: targetStart, duration: resolvedDuration)
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
    }

    /// Thêm một mẫu `TextPreset` (hỗ trợ cả mẫu đơn lớp và mẫu đa lớp `subLayers`) vào timeline trong 1 transaction duy nhất.
    public func addTextPreset(_ preset: TextPreset, at time: CMTime? = nil) {
        if preset.id == "default" {
            addTextClip(named: preset.name, config: preset.config, at: time)
            return
        }
        let proposedStart = time ?? currentTime
        let baseStart = TimeRational.snapToFrame(time: proposedStart)
        let baseDuration = resolveTextClipDuration(preferredSeconds: preset.defaultDuration, at: baseStart)

        var simulatedLayers = layers
        var placements: [(TimelineClip, UUID)] = []

        let mainClip = makeTextTimelineClip(
            named: preset.name,
            config: preset.config,
            timeRange: CMTimeRange(start: baseStart, duration: baseDuration),
            originPresetID: preset.id,
            originPresetName: preset.name
        )
        let mainLayerID = allocateLayerID(for: mainClip, in: &simulatedLayers)
        placements.append((mainClip, mainLayerID))

        for sub in preset.subLayers {
            let offsetFrames = Int64(round(sub.startOffsetSeconds * Double(TimeRational.defaultFPS)))
            let offsetTime = CMTime(value: max(0, offsetFrames), timescale: TimeRational.defaultFPS)
            let subStart = CMTimeAdd(baseStart, offsetTime)
            let remaining = CMTimeSubtract(CMTimeAdd(baseStart, baseDuration), subStart)
            guard remaining > .zero else { continue }
            let scaledSeconds = max(0.5, CMTimeGetSeconds(remaining) * sub.durationRatio)
            let subFrames = max(1, Int64(round(scaledSeconds * Double(TimeRational.defaultFPS))))
            let subDuration = min(remaining, CMTime(value: subFrames, timescale: TimeRational.defaultFPS))
            let subClip = makeTextTimelineClip(
                named: sub.name,
                config: sub.config,
                timeRange: CMTimeRange(start: subStart, duration: subDuration),
                originPresetID: preset.id,
                originPresetName: preset.name
            )
            let subLayerID = allocateLayerID(for: subClip, in: &simulatedLayers)
            placements.append((subClip, subLayerID))
        }

        applyAddedClips(placements)
        selectedClipIDs = Set(placements.map { $0.0.id })
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
        var properties = ClipPropertyRegistry.shared.defaultProperties(for: .text)
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

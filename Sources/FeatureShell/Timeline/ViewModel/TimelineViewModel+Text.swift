import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Thêm một clip Text vào timeline tại thời điểm chỉ định hoặc playhead hiện tại.
    /// Tuân thủ quy tắc R3.1 (Hàm <= 50 dòng) và R7.1 (Transaction Command / Undo-Redo) của AGENTS.md.
    public func addTextClip(
        named name: String = "Văn bản",
        config: TextConfiguration = TextConfiguration(),
        at time: CMTime? = nil
    ) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        var resolvedDuration = CMTime(value: 5 * Int64(TimeRational.defaultFPS), timescale: TimeRational.defaultFPS)
        let mediaClips = layers.flatMap(\.clips).filter { $0.kind == .video || $0.kind == .image }
        if let currentMediaClip = mediaClips.first(where: { $0.timeRange.containsTime(targetStart) }) {
            let remaining = CMTimeSubtract(currentMediaClip.timeRange.end, targetStart)
            if remaining > .zero {
                resolvedDuration = min(resolvedDuration, remaining)
            }
        }
        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)

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

        let clip = TimelineClip(
            assetID: nil,
            name: config.content.isEmpty ? name : config.content,
            kind: .text,
            timeRange: timeRange,
            properties: properties
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
    }
}

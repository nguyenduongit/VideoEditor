import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Thêm một clip Adjustment Layer vào timeline tại thời điểm chỉ định hoặc playhead hiện tại.
    /// Tuân thủ quy tắc R3.1 (Hàm <= 50 dòng) và R7.1 (Transaction Command / Undo-Redo) của AGENTS.md.
    public func addAdjustmentClip(
        named name: String = "Adjustment Layer",
        config: AdjustmentConfiguration = AdjustmentConfiguration(),
        at time: CMTime? = nil
    ) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        var resolvedDuration = CMTime(value: 5 * Int64(TimeRational.defaultFPS), timescale: TimeRational.defaultFPS)
        let mediaClips = layers.flatMap(\.clips).filter { $0.kind == .video || $0.kind == .image }
        if let currentMediaClip = mediaClips.first(where: { $0.timeRange.containsTime(targetStart) }) {
            let remaining = CMTimeSubtract(currentMediaClip.timeRange.end, targetStart)
            if remaining > .zero {
                resolvedDuration = remaining
            }
        }
        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)

        var properties = ClipPropertyRegistry.shared.defaultProperties(for: .adjustment)
        if let json = config.encodeToJSON() {
            properties["adjustmentConfig"] = .string(json)
        }

        let clip = TimelineClip(
            assetID: nil,
            name: name,
            kind: .adjustment,
            timeRange: timeRange,
            properties: properties
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
    }
}

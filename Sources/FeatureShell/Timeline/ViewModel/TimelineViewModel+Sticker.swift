import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Adds a System Library sticker clip to the Timeline at the specified time or playhead.
    /// Complies with AGENTS.md (Function <= 50 lines, Transaction Command).
    public func addStickerItem(_ item: StickerLibraryItem, at time: CMTime? = nil) {
        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)
        let durSeconds = item.defaultDuration > 0.05 ? item.defaultDuration : 3.0
        let frames = max(15, Int64(round(durSeconds * Double(TimeRational.defaultFPS))))
        let resolvedDuration = CMTime(value: frames, timescale: TimeRational.defaultFPS)
        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)

        var properties = dependencies.propertyRegistry.defaultProperties(for: .sticker)
        if let json = item.config.encodeToJSON() {
            properties["stickerConfig"] = .string(json)
        }
        properties["scale"] = .number(1.0)
        properties["positionX"] = .number(0.0)
        properties["positionY"] = .number(0.0)
        properties["rotation"] = .number(0.0)
        properties["opacity"] = .number(1.0)
        properties["flipHorizontal"] = .bool(item.config.flipHorizontal)
        properties["flipVertical"] = .bool(item.config.flipVertical)
        properties["speed"] = .number(item.config.playbackSpeed)
        properties["loopMode"] = .string(item.config.loopMode.rawValue)
        properties["systemSymbolFallback"] = .string(item.systemSymbolFallback)
        properties["originPresetId"] = .string(item.id)
        properties["originPresetName"] = .string(item.name)

        let clip = TimelineClip(
            assetID: nil,
            name: item.name,
            kind: .sticker,
            timeRange: timeRange,
            properties: properties
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]

        if item.format == .audiogram {
            let tempo = AudioTempoResolver.resolveTempo(overlapping: clip.timeRange, in: layers)
            if let sourceID = tempo.sourceClipID, let url = self.clip(by: sourceID)?.mediaURL {
                if tempo.needsBeatAnalysis {
                    backgroundAnalyzeBeats(for: sourceID, url: url)
                }
                backgroundExtractReactiveProfile(for: url)
            }
        }
    }
}

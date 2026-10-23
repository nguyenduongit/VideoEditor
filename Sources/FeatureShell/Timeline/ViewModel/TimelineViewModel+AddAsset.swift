import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {

    /// Adds a single asset to the timeline at the given time or currentTime.
    public func addAsset(_ asset: MediaAsset, at time: CMTime? = nil) {
        addAssets([asset], at: time)
    }

    /// Adds multiple assets to the timeline at the given time or currentTime,
    /// automatically assigning each clip to an appropriate layer (avoiding collisions)
    /// and grouping the operation into a single undo/redo batch command.
    public func addAssets(_ assets: [MediaAsset], at time: CMTime? = nil) {
        guard !assets.isEmpty else { return }

        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)

        var newClipsWithLayers: [(clip: TimelineClip, targetLayerID: UUID)] = []
        var simulatedLayers = layers

        for asset in assets {
            let clip = makeClip(for: asset, at: targetStart)
            let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
            newClipsWithLayers.append((clip, layerID))
        }

        applyAddedClips(newClipsWithLayers)
        selectedClipIDs = Set(newClipsWithLayers.map(\.clip.id))
        resetZoom()
    }

    // MARK: - Private Helpers

    private func makeClip(for asset: MediaAsset, at targetStart: CMTime) -> TimelineClip {
        let kind = asset.type.clipKind
        let defaultDuration = CMTime(value: 5 * Int64(TimeRational.defaultFPS), timescale: TimeRational.defaultFPS)

        var resolvedDuration = defaultDuration
        var maxDuration: CMTime?

        if kind.hasFixedSourceDuration {
            if let dur = TimelineMediaDurationResolver.resolveDuration(for: asset.url, type: asset.type) {
                let snapped = TimeRational.snapToFrame(time: dur)
                resolvedDuration = snapped
                maxDuration = snapped
            }
        }

        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)
        return TimelineClip(
            assetID: asset.id,
            name: asset.name,
            kind: kind,
            timeRange: timeRange,
            maxDuration: maxDuration,
            mediaURL: asset.url
        )
    }

    func allocateLayerID(for clip: TimelineClip, in simulatedLayers: inout [TimelineLayer]) -> UUID {
        let candidateIndex = simulatedLayers.firstIndex { layer in
            guard layer.kind == clip.kind && !layer.isLocked && !layer.isHidden else { return false }
            return !layer.clips.contains { existing in
                existing.timeRange.intersection(clip.timeRange).duration > .zero
            }
        }

        if let index = candidateIndex {
            _ = simulatedLayers[index].appendClip(clip)
            return simulatedLayers[index].id
        }

        let count = simulatedLayers.filter { $0.kind == clip.kind }.count + 1
        let newLayerID = UUID()
        var newLayer = TimelineLayer(id: newLayerID, name: "\(clip.kind.title) \(count)", kind: clip.kind, clips: [])
        _ = newLayer.appendClip(clip)
        let insertionIndex = defaultInsertionIndex(for: clip.kind)
        simulatedLayers.insert(newLayer, at: min(insertionIndex, simulatedLayers.count))
        return newLayerID
    }

    func applyAddedClips(_ items: [(clip: TimelineClip, targetLayerID: UUID)]) {
        if let executor = commandExecutor, !isApplyingCommand {
            let commands = items.map { item in
                TimelineCommand.addClip(layerID: item.targetLayerID, clip: item.clip.toScript())
            }
            executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            return
        }

        for item in items {
            if let index = layers.firstIndex(where: { $0.id == item.targetLayerID }) {
                _ = layers[index].appendClip(item.clip)
            } else {
                let count = layers.filter { $0.kind == item.clip.kind }.count + 1
                var newLayer = TimelineLayer(id: item.targetLayerID, name: "\(item.clip.kind.title) \(count)", kind: item.clip.kind, clips: [])
                _ = newLayer.appendClip(item.clip)
                let insIdx = defaultInsertionIndex(for: item.clip.kind)
                layers.insert(newLayer, at: min(insIdx, layers.count))
            }
        }
        onClipsTrimmed?()
    }
}

import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func selectClip(_ id: UUID?, isCmdPressed: Bool = false) {
        guard let id else {
            selectedClipIDs.removeAll()
            return
        }
        if isCmdPressed {
            if selectedClipIDs.contains(id) {
                selectedClipIDs.remove(id)
            } else {
                selectedClipIDs.insert(id)
            }
        } else {
            selectedClipIDs = [id]
        }
    }

    public func clearSelection() {
        selectedClipIDs.removeAll()
    }

    public func deleteSelectedClips() {
        guard !selectedClipIDs.isEmpty else { return }
        let idsToDelete = selectedClipIDs

        if let executor = commandExecutor, !isApplyingCommand {
            let commands = idsToDelete.map { TimelineCommand.removeClip(clipID: $0) }
            executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            selectedClipIDs.removeAll()
            cleanEmptyLayers()
            if currentTime > totalDuration { currentTime = totalDuration }
            resetZoom()
            onClipsDeleted?(Array(idsToDelete))
            return
        }

        for index in 0..<layers.count {
            layers[index].clips.removeAll { clip in
                idsToDelete.contains(clip.id)
            }
        }

        selectedClipIDs.removeAll()
        cleanEmptyLayers()

        if currentTime > totalDuration {
            currentTime = totalDuration
        }
        resetZoom()
        onClipsDeleted?(Array(idsToDelete))
    }

    public func removeClips(forAssetIDs assetIDs: Set<UUID>, urls: Set<URL> = []) {
        var removedIDs = Set<UUID>()
        for layer in layers {
            for clip in layer.clips {
                let matchesAssetID = clip.assetID.map { assetIDs.contains($0) } ?? false
                let matchesURL = clip.mediaURL.map { urls.contains($0) } ?? false
                if matchesAssetID || matchesURL {
                    removedIDs.insert(clip.id)
                }
            }
        }
        guard !removedIDs.isEmpty else { return }

        if let executor = commandExecutor, !isApplyingCommand {
            let commands = removedIDs.map { TimelineCommand.removeClip(clipID: $0) }
            executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            selectedClipIDs.subtract(removedIDs)
            cleanEmptyLayers()
            if currentTime > totalDuration { currentTime = totalDuration }
            resetZoom()
            onClipsDeleted?(Array(removedIDs))
            return
        }

        for index in 0..<layers.count {
            layers[index].clips.removeAll { removedIDs.contains($0.id) }
        }

        selectedClipIDs.subtract(removedIDs)
        cleanEmptyLayers()

        if currentTime > totalDuration {
            currentTime = totalDuration
        }
        resetZoom()

        onClipsDeleted?(Array(removedIDs))
    }

    @discardableResult
    public func splitClips(at time: CMTime) -> [UUID] {
        let snappedTime = TimeRational.snapToFrame(time: time)
        var targets: [TimelineClip] = []

        for layer in layers where !layer.isLocked {
            for clip in layer.clips {
                let isTarget = selectedClipIDs.isEmpty || selectedClipIDs.contains(clip.id)
                if isTarget,
                   snappedTime > clip.timeRange.start,
                   snappedTime < clip.timeRange.end,
                   (snappedTime - clip.timeRange.start) >= TimelineClip.minDuration,
                   (clip.timeRange.end - snappedTime) >= TimelineClip.minDuration {
                    targets.append(clip)
                }
            }
        }

        if let executor = commandExecutor, !isApplyingCommand, !targets.isEmpty {
            let rationalTime = RationalTime(cmTime: snappedTime)
            var generatedRightIDs: [UUID] = []
            let commands = targets.map { target -> TimelineCommand in
                let rightID = UUID()
                generatedRightIDs.append(rightID)
                return TimelineCommand.splitClip(clipID: target.id, atTime: rationalTime, newRightClipID: rightID)
            }
            let success = executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            if success {
                selectedClipIDs = Set(generatedRightIDs)
                return generatedRightIDs
            }
        }

        return splitClipsDirectly(at: time)
    }

    private func splitClipsDirectly(at time: CMTime) -> [UUID] {
        var newRightClipIDs: [UUID] = []

        for layerIndex in 0..<layers.count {
            guard !layers[layerIndex].isLocked else { continue }

            var newClips: [TimelineClip] = []
            var layerModified = false

            for clip in layers[layerIndex].clips {
                let isTarget = selectedClipIDs.isEmpty || selectedClipIDs.contains(clip.id)

                if isTarget, let (left, right) = clip.split(at: time) {
                    newClips.append(left)
                    newClips.append(right)
                    newRightClipIDs.append(right.id)
                    layerModified = true
                } else {
                    newClips.append(clip)
                }
            }

            if layerModified {
                layers[layerIndex].clips = newClips
            }
        }

        if !newRightClipIDs.isEmpty {
            selectedClipIDs = Set(newRightClipIDs)
            onClipsSplit?(newRightClipIDs)
        }

        return newRightClipIDs
    }

    public func applySpeedChange(
        clipID: UUID,
        newProperties: [String: PropertyValue],
        oldProperties: [String: PropertyValue]
    ) {
        guard let layerIndex = layers.firstIndex(where: { $0.clips.contains(where: { $0.id == clipID }) }),
              let clipIndex = layers[layerIndex].clips.firstIndex(where: { $0.id == clipID }) else {
            return
        }
        let clip = layers[layerIndex].clips[clipIndex]
        let oldSpeed = max(0.01, oldProperties["speed"]?.asNumber ?? 1.0)
        let newSpeed = max(0.01, newProperties["speed"]?.asNumber ?? 1.0)
        guard abs(oldSpeed - newSpeed) > 0.001 else {
            let cmd = TimelineCommand.updateClipProperties(clipID: clipID, properties: newProperties)
            commandExecutor?.execute(cmd)
            return
        }

        let currentDurSec = CMTimeGetSeconds(clip.timeRange.duration)
        let sourceDurSec = currentDurSec * oldSpeed
        let targetDurSec = max(0.1, sourceDurSec / newSpeed)
        let deltaSec = targetDurSec - currentDurSec

        let timescale = clip.timeRange.duration.timescale
        let targetDuration = CMTime(seconds: targetDurSec, preferredTimescale: timescale)
        let delta = CMTime(seconds: deltaSec, preferredTimescale: timescale)

        let commands = makeSpeedChangeCommands(
            clip: clip,
            targetDuration: targetDuration,
            delta: delta,
            newProperties: newProperties,
            layer: layers[layerIndex]
        )

        if let executor = commandExecutor, !isApplyingCommand {
            executor.execute(.batch(commands: commands))
        } else {
            layers[layerIndex].clips[clipIndex].properties = newProperties
            layers[layerIndex].clips[clipIndex].timeRange.duration = targetDuration
            for i in 0..<layers[layerIndex].clips.count where layers[layerIndex].clips[i].id != clipID && layers[layerIndex].clips[i].timeRange.start >= clip.timeRange.start {
                layers[layerIndex].clips[i].timeRange.start = CMTimeMaximum(.zero, layers[layerIndex].clips[i].timeRange.start + delta)
            }
        }
        onClipsTrimmed?()
    }

    private func makeSpeedChangeCommands(
        clip: TimelineClip,
        targetDuration: CMTime,
        delta: CMTime,
        newProperties: [String: PropertyValue],
        layer: TimelineLayer
    ) -> [TimelineCommand] {
        var commands: [TimelineCommand] = [
            .updateClipProperties(clipID: clip.id, properties: newProperties),
            .trimClip(
                clipID: clip.id,
                newStart: RationalTime(cmTime: clip.timeRange.start),
                newDuration: RationalTime(cmTime: targetDuration),
                newSourceStart: RationalTime(cmTime: clip.sourceStartTime)
            )
        ]
        let subsequentClips = layer.clips.filter { $0.id != clip.id && $0.timeRange.start >= clip.timeRange.start }
        for nextClip in subsequentClips {
            let newStart = CMTimeMaximum(.zero, nextClip.timeRange.start + delta)
            commands.append(.moveClip(clipID: nextClip.id, targetLayerID: layer.id, newStartTime: RationalTime(cmTime: newStart)))
        }
        return commands
    }
}

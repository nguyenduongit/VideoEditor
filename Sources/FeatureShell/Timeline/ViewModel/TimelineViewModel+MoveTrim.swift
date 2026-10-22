import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func moveClip(
        clipID: UUID,
        from sourceLayerID: UUID,
        to targetLayerID: UUID?,
        insertAtIndex: Int?,
        newStartTime: CMTime
    ) {
        guard let sourceIndex = layers.firstIndex(where: { $0.id == sourceLayerID }) else { return }
        guard let existingClip = layers[sourceIndex].clips.first(where: { $0.id == clipID }) else { return }

        let resolvedTargetID = targetLayerID ?? (insertAtIndex == nil ? sourceLayerID : nil)

        let effectiveStart: CMTime
        if resolvedTargetID == sourceLayerID && insertAtIndex == nil {
            effectiveStart = layers[sourceIndex].clampStartWithinNeighbors(
                for: clipID,
                proposedStart: newStartTime,
                duration: existingClip.timeRange.duration
            )
        } else {
            effectiveStart = newStartTime
        }

        if let executor = commandExecutor, !isApplyingCommand, let resolvedTargetID, insertAtIndex == nil {
            let cmd = TimelineCommand.moveClip(
                clipID: clipID,
                targetLayerID: resolvedTargetID,
                newStartTime: RationalTime(cmTime: effectiveStart)
            )
            if executor.execute(cmd) { return }
        }

        guard var clip = layers[sourceIndex].removeClip(by: clipID) else { return }
        clip.shift(to: effectiveStart)

        if let insertAtIndex, insertAtIndex >= 0, insertAtIndex <= layers.count {
            var newLayer = createLayer(for: clip.kind, at: insertAtIndex)
            newLayer.appendClip(clip)
            if let index = layers.firstIndex(where: { $0.id == newLayer.id }) {
                layers[index] = newLayer
            }
            cleanEmptyLayers()
            onClipsTrimmed?()
            return
        }

        if let resolvedTargetID,
           let targetIndex = layers.firstIndex(where: { $0.id == resolvedTargetID && $0.kind == clip.kind && !$0.isLocked && !$0.isHidden }),
           !layers[targetIndex].hasCollision(with: clip.timeRange) {
            layers[targetIndex].appendClip(clip)
            cleanEmptyLayers()
            onClipsTrimmed?()
            return
        }

        if let availableIndex = layers.firstIndex(where: { $0.kind == clip.kind && !$0.isLocked && !$0.isHidden && !$0.hasCollision(with: clip.timeRange) }) {
            layers[availableIndex].appendClip(clip)
            cleanEmptyLayers()
            onClipsTrimmed?()
            return
        }

        var newLayer = createLayer(for: clip.kind)
        newLayer.appendClip(clip)
        if let index = layers.firstIndex(where: { $0.id == newLayer.id }) {
            layers[index] = newLayer
        }
        cleanEmptyLayers()
        onClipsTrimmed?()
    }

    public func trimClip(
        clipID: UUID,
        in layerID: UUID,
        newStart: CMTime,
        newDuration: CMTime,
        newSourceStart: CMTime? = nil
    ) {
        if let executor = commandExecutor, !isApplyingCommand {
            let cmd = TimelineCommand.trimClip(
                clipID: clipID,
                newStart: RationalTime(cmTime: newStart),
                newDuration: RationalTime(cmTime: newDuration),
                newSourceStart: newSourceStart.map { RationalTime(cmTime: $0) }
            )
            executor.execute(cmd)
            return
        }
        guard let layerIndex = layers.firstIndex(where: { $0.id == layerID && !$0.isLocked }) else { return }
        guard let clipIndex = layers[layerIndex].clips.firstIndex(where: { $0.id == clipID }) else { return }

        let (prevClip, nextClip) = layers[layerIndex].neighbors(of: clipID)

        var clampedStart = newStart
        if let prevEnd = prevClip?.timeRange.end {
            clampedStart = CMTimeMaximum(clampedStart, prevEnd)
        } else {
            clampedStart = CMTimeMaximum(clampedStart, .zero)
        }

        var clampedEnd = clampedStart + newDuration
        if let nextStart = nextClip?.timeRange.start {
            clampedEnd = CMTimeMinimum(clampedEnd, nextStart)
        }

        let clampedDuration = CMTimeMaximum(clampedEnd - clampedStart, TimelineClip.minDuration)

        layers[layerIndex].clips[clipIndex].trim(
            newStart: clampedStart,
            newDuration: clampedDuration,
            newSourceStart: newSourceStart
        )
        layers[layerIndex].sortClips()
        onClipsTrimmed?()
    }
}

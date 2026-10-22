import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Computes the effective delta for group movement based on a pivot clip's proposed new start time.
    public func clampedGroupMoveDelta(pivotClipID: UUID, proposedStart: CMTime) -> CMTime {
        guard let pivotClip = layers.flatMap(\.clips).first(where: { $0.id == pivotClipID }) else {
            return .zero
        }
        let originalStart = pivotClip.timeRange.start
        let proposedDelta = CMTimeSubtract(proposedStart, originalStart)
        let limits = TimelineGroupMoveEngine.calculateLimits(layers: layers, selectedClipIDs: selectedClipIDs)
        return TimelineGroupMoveEngine.clamp(delta: proposedDelta, limits: limits)
    }

    /// Updates groupMoveOffset in real-time during drag.
    public func updateGroupMove(pivotClipID: UUID, proposedStart: CMTime) {
        let effectiveDelta = clampedGroupMoveDelta(pivotClipID: pivotClipID, proposedStart: proposedStart)
        groupMoveOffset = CGFloat(CMTimeGetSeconds(effectiveDelta)) * pixelsPerSecond
    }

    /// Resets group move offset (e.g. on drag end or cancel).
    public func resetGroupMove() {
        groupMoveOffset = 0
    }

    /// Commits the group movement by delta time across all selected clips.
    public func commitGroupMove(delta: CMTime) {
        defer { resetGroupMove() }
        guard delta != .zero else { return }

        var targets: [(clip: TimelineClip, layerID: UUID)] = []
        for layer in layers {
            for clip in layer.clips where selectedClipIDs.contains(clip.id) {
                targets.append((clip, layer.id))
            }
        }
        guard !targets.isEmpty else { return }

        let isForward = delta > .zero
        targets.sort {
            isForward ? $0.clip.timeRange.start > $1.clip.timeRange.start : $0.clip.timeRange.start < $1.clip.timeRange.start
        }

        if let executor = commandExecutor, !isApplyingCommand {
            let commands = targets.map { target -> TimelineCommand in
                let newStart = CMTimeAdd(target.clip.timeRange.start, delta)
                return TimelineCommand.moveClip(
                    clipID: target.clip.id,
                    targetLayerID: target.layerID,
                    newStartTime: RationalTime(cmTime: newStart)
                )
            }
            _ = executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            return
        }

        for target in targets {
            guard let layerIndex = layers.firstIndex(where: { $0.id == target.layerID }),
                  let clipIndex = layers[layerIndex].clips.firstIndex(where: { $0.id == target.clip.id }) else {
                continue
            }
            var clip = layers[layerIndex].clips.remove(at: clipIndex)
            clip.shift(to: CMTimeAdd(target.clip.timeRange.start, delta))
            layers[layerIndex].appendClip(clip)
        }
        cleanEmptyLayers()
        onClipsTrimmed?()
    }
}

import Foundation
import CoreMedia
import Domain

/// Executes domain commands against a TimelineViewModel and manages an Undo/Redo stack.
@MainActor
public final class TimelineCommandExecutor {
    weak var viewModel: TimelineViewModel?
    public internal(set) var history: [TimelineHistoryRecord] = []
    public internal(set) var historyIndex: Int = 0

    public init(viewModel: TimelineViewModel) {
        self.viewModel = viewModel
    }

    public var canUndo: Bool { historyIndex > 0 }
    public var canRedo: Bool { historyIndex < history.count }

    @discardableResult
    public func execute(_ command: TimelineCommand, registerUndo: Bool = true, title: String? = nil) -> Bool {
        guard let viewModel else { return false }

        guard let inverse = apply(command: command, on: viewModel) else {
            return false
        }

        if registerUndo {
            if historyIndex < history.count {
                history.removeSubrange(historyIndex..<history.count)
            }
            let record = TimelineHistoryRecord(
                title: title,
                command: command,
                inverse: inverse
            )
            history.append(record)
            historyIndex = history.count
        }
        viewModel.updateUndoRedoState()
        return true
    }

    // MARK: - Internal Apply Logic

    func apply(command: TimelineCommand, on vm: TimelineViewModel) -> TimelineCommand? {
        let prevApplying = vm.isApplyingCommand
        vm.isApplyingCommand = true
        defer { vm.isApplyingCommand = prevApplying }

        switch command {
        case .addClip(let layerID, let clipScript):
            return applyAddClip(layerID: layerID, clipScript: clipScript, on: vm)
        case .removeClip(let clipID):
            return applyRemoveClip(clipID: clipID, on: vm)
        case .moveClip(let clipID, let targetLayerID, let newStartTime):
            return applyMoveClip(clipID: clipID, targetLayerID: targetLayerID, newStartTime: newStartTime, on: vm)
        case .trimClip(let clipID, let newStart, let newDuration, let newSourceStart):
            return applyTrimClip(clipID: clipID, newStart: newStart, newDuration: newDuration, newSourceStart: newSourceStart, on: vm)
        case .splitClip(let clipID, let atTime, let newRightClipID):
            return applySplitClip(clipID: clipID, atTime: atTime, newRightClipID: newRightClipID, on: vm)
        case .updateClipProperties(let clipID, let properties):
            return applyUpdateClipProperties(clipID: clipID, properties: properties, on: vm)
        case .setLayerStatus(let layerID, let isLocked, let isHidden, let isMuted):
            return applySetLayerStatus(layerID: layerID, isLocked: isLocked, isHidden: isHidden, isMuted: isMuted, on: vm)
        case .setAspectRatio(let ratio):
            return applySetAspectRatio(ratio: ratio, on: vm)
        case .batch(let commands):
            return applyBatch(commands: commands, on: vm)
        }
    }

    private func applyAddClip(layerID: UUID, clipScript: ClipScript, on vm: TimelineViewModel) -> TimelineCommand? {
        let clip = clipScript.toTimelineClip()
        let layerIndex: Int
        if let existingIndex = vm.layers.firstIndex(where: { $0.id == layerID }) {
            layerIndex = existingIndex
        } else {
            let count = vm.layers.filter { $0.kind == clip.kind }.count + 1
            let newLayer = TimelineLayer(id: layerID, name: "\(clip.kind.title) \(count)", kind: clip.kind)
            let insertionIndex = vm.defaultInsertionIndex(for: clip.kind)
            vm.layers.insert(newLayer, at: insertionIndex)
            layerIndex = insertionIndex
        }

        guard vm.layers[layerIndex].appendClip(clip) else { return nil }
        vm.onClipsTrimmed?()
        return .removeClip(clipID: clip.id)
    }

    private func applyRemoveClip(clipID: UUID, on vm: TimelineViewModel) -> TimelineCommand? {
        for index in 0..<vm.layers.count {
            if let clipIndex = vm.layers[index].clips.firstIndex(where: { $0.id == clipID }) {
                let layerID = vm.layers[index].id
                let removedClip = vm.layers[index].clips.remove(at: clipIndex)
                return .addClip(layerID: layerID, clip: ClipScript(from: removedClip))
            }
        }
        return nil
    }

    private func applyMoveClip(
        clipID: UUID, targetLayerID: UUID, newStartTime: RationalTime, on vm: TimelineViewModel
    ) -> TimelineCommand? {
        guard let sourceLayerIndex = vm.layers.firstIndex(where: { $0.clips.contains { $0.id == clipID } }),
              let clipIndex = vm.layers[sourceLayerIndex].clips.firstIndex(where: { $0.id == clipID }) else {
            return nil
        }

        let oldLayerID = vm.layers[sourceLayerIndex].id
        let oldStart = RationalTime(cmTime: vm.layers[sourceLayerIndex].clips[clipIndex].timeRange.start)

        if oldLayerID == targetLayerID {
            let clampedStart = vm.layers[sourceLayerIndex].clampStartWithinNeighbors(
                for: clipID,
                proposedStart: newStartTime.cmTime,
                duration: vm.layers[sourceLayerIndex].clips[clipIndex].timeRange.duration
            )
            var clip = vm.layers[sourceLayerIndex].clips.remove(at: clipIndex)
            clip.shift(to: clampedStart)
            vm.layers[sourceLayerIndex].appendClip(clip)
            vm.onClipsTrimmed?()
            return .moveClip(clipID: clipID, targetLayerID: oldLayerID, newStartTime: oldStart)
        }

        var clip = vm.layers[sourceLayerIndex].clips.remove(at: clipIndex)
        clip.shift(to: newStartTime.cmTime)

        var targetIndex: Int
        if let existingIndex = vm.layers.firstIndex(where: { $0.id == targetLayerID && $0.kind == clip.kind }) {
            if !vm.layers[existingIndex].hasCollision(with: clip.timeRange) {
                targetIndex = existingIndex
            } else if let openIndex = vm.layers.firstIndex(where: { $0.kind == clip.kind && !$0.isLocked && !$0.isHidden && !$0.hasCollision(with: clip.timeRange) }) {
                targetIndex = openIndex
            } else {
                let count = vm.layers.filter { $0.kind == clip.kind }.count + 1
                let newLayer = TimelineLayer(name: "\(clip.kind.title) \(count)", kind: clip.kind)
                let insIdx = vm.defaultInsertionIndex(for: clip.kind)
                vm.layers.insert(newLayer, at: insIdx)
                targetIndex = insIdx
            }
        } else {
            let count = vm.layers.filter { $0.kind == clip.kind }.count + 1
            let newLayer = TimelineLayer(id: targetLayerID, name: "\(clip.kind.title) \(count)", kind: clip.kind)
            let insIdx = vm.defaultInsertionIndex(for: clip.kind)
            vm.layers.insert(newLayer, at: insIdx)
            targetIndex = insIdx
        }

        vm.layers[targetIndex].appendClip(clip)
        vm.onClipsTrimmed?()

        return .moveClip(clipID: clipID, targetLayerID: oldLayerID, newStartTime: oldStart)
    }

    private func applyTrimClip(
        clipID: UUID, newStart: RationalTime, newDuration: RationalTime, newSourceStart: RationalTime?, on vm: TimelineViewModel
    ) -> TimelineCommand? {
        for layer in vm.layers {
            if let clipIndex = layer.clips.firstIndex(where: { $0.id == clipID }) {
                let oldClip = layer.clips[clipIndex]
                let oldStart = RationalTime(cmTime: oldClip.timeRange.start)
                let oldDuration = RationalTime(cmTime: oldClip.timeRange.duration)
                let oldSourceStart = RationalTime(cmTime: oldClip.sourceStartTime)

                vm.trimClip(
                    clipID: clipID,
                    in: layer.id,
                    newStart: newStart.cmTime,
                    newDuration: newDuration.cmTime,
                    newSourceStart: newSourceStart?.cmTime
                )

                return .trimClip(
                    clipID: clipID,
                    newStart: oldStart,
                    newDuration: oldDuration,
                    newSourceStart: oldSourceStart
                )
            }
        }
        return nil
    }

    private func applySplitClip(
        clipID: UUID, atTime: RationalTime, newRightClipID: UUID?, on vm: TimelineViewModel
    ) -> TimelineCommand? {
        for (layerIndex, layer) in vm.layers.enumerated() {
            if let clip = layer.clips.first(where: { $0.id == clipID }),
               let (left, right) = clip.split(at: atTime.cmTime, newRightID: newRightClipID) {
                let originalStart = RationalTime(cmTime: clip.timeRange.start)
                let originalDuration = RationalTime(cmTime: clip.timeRange.duration)
                let originalSourceStart = RationalTime(cmTime: clip.sourceStartTime)

                vm.layers[layerIndex].clips.removeAll { $0.id == clipID }
                vm.layers[layerIndex].appendClip(left)
                vm.layers[layerIndex].appendClip(right)
                vm.onClipsSplit?([right.id])
                vm.onClipsTrimmed?()

                let undoRight = TimelineCommand.removeClip(clipID: right.id)
                let undoLeft = TimelineCommand.trimClip(
                    clipID: left.id,
                    newStart: originalStart,
                    newDuration: originalDuration,
                    newSourceStart: originalSourceStart
                )
                return .batch(commands: [undoRight, undoLeft])
            }
        }
        return nil
    }

    private func applySetLayerStatus(
        layerID: UUID, isLocked: Bool?, isHidden: Bool?, isMuted: Bool?, on vm: TimelineViewModel
    ) -> TimelineCommand? {
        guard let layerIndex = vm.layers.firstIndex(where: { $0.id == layerID }) else { return nil }
        let oldLocked = vm.layers[layerIndex].isLocked
        let oldHidden = vm.layers[layerIndex].isHidden
        let oldMuted = vm.layers[layerIndex].isMuted

        if let isLocked { vm.layers[layerIndex].isLocked = isLocked }
        if let isHidden, vm.layers[layerIndex].kind != .audio { vm.layers[layerIndex].isHidden = isHidden }
        if let isMuted { vm.layers[layerIndex].isMuted = isMuted }

        return .setLayerStatus(layerID: layerID, isLocked: oldLocked, isHidden: oldHidden, isMuted: oldMuted)
    }

    private func applyUpdateClipProperties(
        clipID: UUID, properties: [String: PropertyValue], on vm: TimelineViewModel
    ) -> TimelineCommand? {
        for layerIndex in 0..<vm.layers.count {
            if let clipIndex = vm.layers[layerIndex].clips.firstIndex(where: { $0.id == clipID }) {
                let oldProperties = vm.layers[layerIndex].clips[clipIndex].properties
                vm.layers[layerIndex].clips[clipIndex].properties = properties
                vm.onClipsTrimmed?()
                return .updateClipProperties(clipID: clipID, properties: oldProperties)
            }
        }
        return nil
    }

    private func applySetAspectRatio(ratio: CanvasAspectRatio, on vm: TimelineViewModel) -> TimelineCommand? {
        let oldRatio = vm.aspectRatio
        vm.aspectRatio = ratio
        vm.onAspectRatioChanged?(ratio)
        return .setAspectRatio(oldRatio)
    }

    private func applyBatch(commands: [TimelineCommand], on vm: TimelineViewModel) -> TimelineCommand? {
        var inverseCommands: [TimelineCommand] = []
        for command in commands {
            guard let inverse = apply(command: command, on: vm) else {
                return nil
            }
            inverseCommands.append(inverse)
        }
        return .batch(commands: inverseCommands.reversed())
    }
}

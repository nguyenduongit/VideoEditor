import Foundation
import Domain

extension TimelineCommandExecutor {
    func applySetLayerStatus(
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

    func applyUpdateClipProperties(
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

    func applySetAspectRatio(ratio: CanvasAspectRatio, on vm: TimelineViewModel) -> TimelineCommand? {
        let oldRatio = vm.aspectRatio
        vm.aspectRatio = ratio
        vm.onAspectRatioChanged?(ratio)
        return .setAspectRatio(oldRatio)
    }

    func applyBatch(commands: [TimelineCommand], on vm: TimelineViewModel) -> TimelineCommand? {
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

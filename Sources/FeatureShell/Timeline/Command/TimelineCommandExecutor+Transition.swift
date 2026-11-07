import Foundation
import Domain

/// Mở rộng `TimelineCommandExecutor` cho các lệnh thêm/sửa/xóa `CutTransition` có hỗ trợ Undo/Redo nguyên tử.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R7.1 (Transaction Command).
extension TimelineCommandExecutor {
    func applySetCutTransition(
        layerID: UUID,
        transition: CutTransition,
        on vm: TimelineViewModel
    ) -> TimelineCommand? {
        guard let layerIndex = vm.layers.firstIndex(where: { $0.id == layerID }) else {
            return nil
        }

        let previous = vm.layers[layerIndex].transitions.first(where: {
            $0.id == transition.id ||
            ($0.leadingClipID == transition.leadingClipID && $0.trailingClipID == transition.trailingClipID)
        })

        vm.layers[layerIndex].addOrUpdateTransition(transition)
        guard vm.layers[layerIndex].transitions.contains(where: { $0.id == transition.id }) else {
            return nil
        }
        vm.onClipsTrimmed?()

        if let previous {
            return .setCutTransition(layerID: layerID, transition: previous)
        }
        return .removeCutTransition(layerID: layerID, transitionID: transition.id)
    }

    func applyRemoveCutTransition(
        layerID: UUID,
        transitionID: UUID,
        on vm: TimelineViewModel
    ) -> TimelineCommand? {
        guard let layerIndex = vm.layers.firstIndex(where: { $0.id == layerID }),
              let existing = vm.layers[layerIndex].transition(by: transitionID) else {
            return nil
        }

        vm.layers[layerIndex].removeTransition(by: transitionID)
        if vm.selectedTransitionID == transitionID {
            vm.selectedTransitionID = nil
        }
        vm.onClipsTrimmed?()
        return .setCutTransition(layerID: layerID, transition: existing)
    }
}

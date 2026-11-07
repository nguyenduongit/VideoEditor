import Foundation
import CoreMedia
import Domain

/// Mở rộng `TimelineViewModel` quản lý `CutTransition` thông qua `TimelineCommandExecutor` (Undo/Redo trọn vẹn).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R7.1 (Transaction Command).
extension TimelineViewModel {
    /// Thêm hoặc cập nhật hiệu ứng chuyển cảnh (`CutTransition`) giữa 2 clip kề nhau.
    @discardableResult
    public func addOrUpdateCutTransition(
        _ preset: TransitionPreset,
        between leadingClipID: UUID,
        and trailingClipID: UUID
    ) -> CutTransition? {
        guard let layerIndex = layers.firstIndex(where: { layer in
            layer.clips.contains(where: { $0.id == leadingClipID }) &&
            layer.clips.contains(where: { $0.id == trailingClipID })
        }) else {
            return nil
        }

        let layer = layers[layerIndex]
        guard let leadIdx = layer.clips.firstIndex(where: { $0.id == leadingClipID }),
              leadIdx + 1 < layer.clips.count,
              layer.clips[leadIdx + 1].id == trailingClipID else {
            return nil
        }

        let existing = layer.transition(between: leadingClipID, and: trailingClipID)
        let durationRational = RationalTime(cmTime: CMTime(seconds: preset.defaultDuration, preferredTimescale: 600))
        let transition = CutTransition(
            id: existing?.id ?? UUID(),
            presetID: preset.id,
            name: preset.name,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            duration: durationRational,
            alignment: existing?.alignment ?? .center,
            shaderType: preset.shaderType,
            easing: preset.defaultEasing,
            crossfadeAudio: existing?.crossfadeAudio ?? true,
            parameterValues: preset.parameterValues,
            customMetalSource: preset.customMetalSource
        )

        if let executor = commandExecutor {
            guard executor.execute(.setCutTransition(layerID: layer.id, transition: transition)) else {
                return nil
            }
        } else {
            layers[layerIndex].addOrUpdateTransition(transition)
            onClipsTrimmed?()
        }
        selectTransition(transition.id)
        return transition
    }

    /// Cập nhật thông số `CutTransition` và ghi nhận lệnh Undo/Redo (hoặc cập nhật tức thời `commit == false` khi đang kéo thanh trượt).
    public func updateTransition(_ transition: CutTransition, commit: Bool = true) {
        guard let index = layers.firstIndex(where: { $0.transitions.contains(where: { $0.id == transition.id }) }) else {
            return
        }
        let layerID = layers[index].id
        if commit, let executor = commandExecutor {
            _ = executor.execute(.setCutTransition(layerID: layerID, transition: transition))
        } else {
            layers[index].addOrUpdateTransition(transition)
            onClipsTrimmed?()
        }
    }

    /// Xóa một hiệu ứng chuyển cảnh khỏi Timeline (hỗ trợ hoàn tác Cmd+Z).
    public func removeTransition(by id: UUID) {
        guard let index = layers.firstIndex(where: { $0.transitions.contains(where: { $0.id == id }) }) else {
            return
        }
        let layerID = layers[index].id
        if let executor = commandExecutor {
            _ = executor.execute(.removeCutTransition(layerID: layerID, transitionID: id))
        } else {
            layers[index].removeTransition(by: id)
            if selectedTransitionID == id {
                selectedTransitionID = nil
            }
            onClipsTrimmed?()
        }
    }

    /// Chọn một hiệu ứng chuyển cảnh để hiển thị trên Inspector.
    public func selectTransition(_ id: UUID?) {
        selectedTransitionID = id
        if id != nil {
            selectedClipIDs.removeAll()
        }
    }
}

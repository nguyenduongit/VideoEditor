import Foundation
import CoreGraphics
import CoreMedia
import Domain

/// Thông tin điểm nối hợp lệ giữa 2 video/image clip liền kề (không có khoảng cách) khi kéo thả Transition vào Timeline.
public struct TransitionDropJoinTarget: Sendable, Equatable {
    public let layerID: UUID
    public let leadingClipID: UUID
    public let trailingClipID: UUID
    public let cutTime: CMTime
    public let cutCanvasX: CGFloat
    public let overlayWidth: CGFloat
    public let overlayHeight: CGFloat
    public let layerMidY: CGFloat
    public let existingTransitionID: UUID?
}

/// Mở rộng `TimelineViewModel` quản lý `CutTransition` thông qua `TimelineCommandExecutor` (Undo/Redo trọn vẹn).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R7.1 (Transaction Command).
extension TimelineViewModel {
    /// Thêm hoặc thay thế (ghi đè) hiệu ứng chuyển cảnh (`CutTransition`) giữa 2 clip nối sát nhau (không có khoảng cách).
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
        guard (layer.kind == .video || layer.kind == .image),
              !layer.isLocked,
              !layer.isHidden,
              let leadIdx = layer.clips.firstIndex(where: { $0.id == leadingClipID }),
              layer.areClipsContiguous(leadingID: leadingClipID, trailingID: trailingClipID) else {
            return nil
        }

        let existing = layer.transition(between: leadingClipID, and: trailingClipID)
        let leadDuration = layer.clips[leadIdx].timeRange.duration.seconds
        let trailDuration = layer.clips[leadIdx + 1].timeRange.duration.seconds
        let maxAllowed = max(0.1, 2.0 * min(leadDuration, trailDuration))
        let targetDuration = min(preset.defaultDuration, maxAllowed)
        let durationRational = RationalTime(cmTime: CMTime(seconds: targetDuration, preferredTimescale: 600))
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

    /// Xác định vùng điểm nối hợp lệ của 2 video/image clip nối sát nhau tại tọa độ `(canvasX, canvasY)` trên Timeline.
    /// Chỉ trả về kết quả khi 2 clip nối nhau không có khoảng cách và vị trí thả nằm trong vùng chứa điểm nối.
    public func resolveTransitionDropTarget(
        preset: TransitionPreset? = nil,
        canvasX: CGFloat,
        canvasY: CGFloat,
        topSpacerHeight: CGFloat
    ) -> TransitionDropJoinTarget? {
        var currentY = topSpacerHeight
        for layer in layers {
            let h = layerHeight(for: layer.kind)
            let minY = currentY
            let maxY = currentY + h
            currentY = maxY

            guard canvasY >= minY && canvasY <= maxY else { continue }
            guard (layer.kind == .video || layer.kind == .image),
                  !layer.isLocked,
                  !layer.isHidden,
                  layer.clips.count >= 2 else {
                return nil
            }
            return findJoinTargetInLayer(layer, layerHeight: h, layerMidY: minY + h * 0.5, preset: preset, canvasX: canvasX)
        }
        return nil
    }

    private func findJoinTargetInLayer(
        _ layer: TimelineLayer,
        layerHeight: CGFloat,
        layerMidY: CGFloat,
        preset: TransitionPreset?,
        canvasX: CGFloat
    ) -> TransitionDropJoinTarget? {
        var bestTarget: TransitionDropJoinTarget?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for idx in 0..<(layer.clips.count - 1) {
            let lead = layer.clips[idx]
            let trail = layer.clips[idx + 1]
            guard layer.areClipsContiguous(leadingID: lead.id, trailingID: trail.id) else { continue }

            let cutTime = lead.timeRange.end
            let cutX = CGFloat(cutTime.seconds) * pixelsPerSecond
            let maxAllowed = max(0.1, 2.0 * min(lead.timeRange.duration.seconds, trail.timeRange.duration.seconds))
            let targetDur = min(preset?.defaultDuration ?? 2.0, maxAllowed)
            let existing = layer.transition(between: lead.id, and: trail.id)
            let existingDur = existing?.duration.seconds ?? 0.0
            let overlayW = max(14.0, CGFloat(targetDur) * pixelsPerSecond)
            let effectiveZoneW = max(36.0, CGFloat(max(targetDur, existingDur)) * pixelsPerSecond)
            let minZoneX = max(CGFloat(lead.timeRange.start.seconds) * pixelsPerSecond, cutX - effectiveZoneW * 0.5)
            let maxZoneX = min(CGFloat(trail.timeRange.end.seconds) * pixelsPerSecond, cutX + effectiveZoneW * 0.5)

            let dist = abs(canvasX - cutX)
            if canvasX >= minZoneX && canvasX <= maxZoneX && dist < bestDistance {
                bestDistance = dist
                bestTarget = TransitionDropJoinTarget(
                    layerID: layer.id,
                    leadingClipID: lead.id,
                    trailingClipID: trail.id,
                    cutTime: cutTime,
                    cutCanvasX: cutX,
                    overlayWidth: overlayW,
                    overlayHeight: layerHeight,
                    layerMidY: layerMidY,
                    existingTransitionID: existing?.id
                )
            }
        }
        return bestTarget
    }

    /// Thực thi thả một `TransitionPreset` vào vị trí `(canvasX, canvasY)` trên Timeline (hỗ trợ thêm mới hoặc ghi đè transition cũ).
    @discardableResult
    public func dropTransition(
        _ preset: TransitionPreset,
        atCanvasX canvasX: CGFloat,
        canvasY: CGFloat,
        topSpacerHeight: CGFloat
    ) -> CutTransition? {
        guard let target = resolveTransitionDropTarget(
            preset: preset,
            canvasX: canvasX,
            canvasY: canvasY,
            topSpacerHeight: topSpacerHeight
        ) else {
            return nil
        }
        return addOrUpdateCutTransition(preset, between: target.leadingClipID, and: target.trailingClipID)
    }

    /// Tìm kiếm `TransitionPreset` theo ID từ kho mẫu hiện hành hoặc danh mục tích hợp.
    public func lookupTransitionPreset(by id: String) -> TransitionPreset? {
        if let found = dependencies.transitionTemplates.loadAllTemplates().first(where: { $0.id == id }) {
            return found
        }
        return TransitionPreset.builtInCatalog.first(where: { $0.id == id })
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

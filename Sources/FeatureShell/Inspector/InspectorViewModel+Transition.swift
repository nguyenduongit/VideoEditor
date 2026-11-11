import Foundation
import CoreMedia
import OSLog
import Domain

private let transitionInspectorLogger = Logger(subsystem: "VideoEditor", category: "InspectorViewModel+Transition")

/// Mở rộng `InspectorViewModel` cho điều khiển `CutTransition`: Thời lượng, Căn lề, Easing, Audio Crossfade,
/// Tham số Shader động, kéo thanh trượt nguyên tử (R7.5) và lưu Preset lên Supabase.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension InspectorViewModel {

    /// Danh sách thanh trượt tham số động của hiệu ứng chuyển cảnh đang chọn.
    public var activeTransitionParameterDescriptors: [CustomParameterDescriptor] {
        guard let t = selectedTransition else { return [] }
        let allTemplates = dependencies.transitionTemplates.loadAllTemplates()
        if let matched = allTemplates.first(where: { $0.id == t.presetID }), !matched.parameters.isEmpty {
            return matched.parameters
        }
        return TransitionPreset.builtInCatalog.first(where: { $0.shaderType == t.shaderType })?.parameters ?? []
    }

    public func transitionParameterValue(for descriptor: CustomParameterDescriptor) -> Double {
        selectedTransition?.parameterValues[descriptor.id] ?? descriptor.defaultValue
    }

    public func onTransitionSliderEditingChanged(_ isEditing: Bool) {
        guard let current = selectedTransition, let timelineViewModel else { return }
        if isEditing {
            if dragInitialTransition == nil {
                dragInitialTransition = current
            }
        } else {
            if let initial = dragInitialTransition, initial != current {
                timelineViewModel.updateTransition(initial, commit: false)
                timelineViewModel.updateTransition(current, commit: true)
            }
            dragInitialTransition = nil
        }
    }

    /// Giới hạn thời lượng chuyển cảnh tối đa an toàn, không vượt quá tổng 2 nửa độ dài của 2 clip liền kề.
    public var maxAllowedTransitionDuration: Double {
        guard let t = selectedTransition, let timelineViewModel else { return 3.0 }
        for layer in timelineViewModel.layers {
            if let lead = layer.clips.first(where: { $0.id == t.leadingClipID }),
               let trail = layer.clips.first(where: { $0.id == t.trailingClipID }) {
                let limit = 2.0 * min(lead.timeRange.duration.seconds, trail.timeRange.duration.seconds)
                return max(0.2, min(5.0, limit))
            }
        }
        return 3.0
    }

    public func updateTransitionDuration(_ durationSeconds: Double, commit: Bool = true) {
        guard let t = selectedTransition, let timelineViewModel else { return }
        if !commit && dragInitialTransition == nil {
            dragInitialTransition = t
        }
        let maxAllowed = maxAllowedTransitionDuration
        let clamped = max(0.1, min(maxAllowed, durationSeconds))
        var updated = t
        updated.duration = RationalTime(cmTime: CMTime(seconds: clamped, preferredTimescale: 600))
        timelineViewModel.updateTransition(updated, commit: commit)
    }

    public func updateTransitionAlignment(_ alignment: TransitionAlignment) {
        guard let t = selectedTransition, let timelineViewModel else { return }
        var updated = t
        updated.alignment = alignment
        timelineViewModel.updateTransition(updated, commit: true)
    }

    public func updateTransitionEasing(_ easing: TransitionEasing) {
        guard let t = selectedTransition, let timelineViewModel else { return }
        var updated = t
        updated.easing = easing
        timelineViewModel.updateTransition(updated, commit: true)
    }

    public func updateTransitionCrossfadeAudio(_ enabled: Bool) {
        guard let t = selectedTransition, let timelineViewModel else { return }
        var updated = t
        updated.crossfadeAudio = enabled
        timelineViewModel.updateTransition(updated, commit: true)
    }

    public func updateTransitionShaderType(_ shaderType: TransitionShaderType) {
        guard let t = selectedTransition, let timelineViewModel else { return }
        var updated = t
        updated.shaderType = shaderType
        if let builtIn = TransitionPreset.builtInCatalog.first(where: { $0.shaderType == shaderType }) {
            for param in builtIn.parameters where updated.parameterValues[param.id] == nil {
                updated.parameterValues[param.id] = param.defaultValue
            }
        }
        timelineViewModel.updateTransition(updated, commit: true)
    }

    public func updateTransitionParameter(id: String, value: Double, commit: Bool = true) {
        guard let t = selectedTransition, let timelineViewModel else { return }
        if !commit && dragInitialTransition == nil {
            dragInitialTransition = t
        }
        var updated = t
        if let desc = activeTransitionParameterDescriptors.first(where: { $0.id == id }) {
            updated.parameterValues[id] = max(desc.minValue, min(desc.maxValue, value))
        } else {
            updated.parameterValues[id] = value
        }
        timelineViewModel.updateTransition(updated, commit: commit)
    }

    public func saveSelectedTransitionAsPreset(name: String, category: TransitionCategory = .motion) {
        guard let t = selectedTransition else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = TransitionPreset(
            id: "user_trans_\(UUID().uuidString.lowercased())",
            name: trimmed,
            description: "Mẫu chuyển cảnh tùy chỉnh (\(t.shaderType.displayName))",
            category: category == .all ? .motion : category,
            tags: ["custom", t.shaderType.rawValue],
            defaultDuration: t.duration.seconds,
            shaderType: t.shaderType,
            defaultEasing: t.easing,
            parameters: activeTransitionParameterDescriptors,
            parameterValues: t.parameterValues,
            customMetalSource: t.customMetalSource,
            isSystem: false
        )
        dependencies.transitionTemplates.updateInMemoryPreset(preset)
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
        if let repo = dependencies.presetRepositories.transitionRepository {
            Task {
                do {
                    try await repo.savePreset(preset)
                } catch {
                    transitionInspectorLogger.error("Lưu TransitionPreset lên Supabase thất bại: \(error.localizedDescription)")
                }
            }
        }
    }

    public func deleteSelectedTransition() {
        guard let t = selectedTransition, let timelineViewModel else { return }
        timelineViewModel.removeTransition(by: t.id)
        selectedTransitionID = nil
    }
}

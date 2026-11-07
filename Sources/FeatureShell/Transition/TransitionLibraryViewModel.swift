import Foundation
import Observation
import OSLog
import Domain

private let transitionLibraryLogger = Logger(subsystem: "VideoEditor", category: "TransitionLibraryViewModel")

/// Quản lý trạng thái và danh sách mẫu Chuyển cảnh (`TransitionPreset`) bên sidebar trái,
/// đồng bộ bất đồng bộ với bảng `transition_presets` trên Supabase (Offline-First / SWR).
/// Tuân thủ AGENTS.md R3.2 (@Observable) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@Observable
@MainActor
public final class TransitionLibraryViewModel {
    public var selectedCategory: TransitionCategory = .all
    public var searchQuery: String = ""
    public private(set) var templatePresets: [TransitionPreset] = []
    public private(set) var isSyncingRemote = false
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        let deps = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.dependencies = deps
        self.templatePresets = deps.transitionTemplates.loadAllTemplates()
    }

    public var filteredPresets: [TransitionPreset] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return templatePresets.filter { preset in
            let matchesCategory = (selectedCategory == .all) || (preset.category == selectedCategory)
            guard matchesCategory else { return false }
            guard !trimmed.isEmpty else { return true }
            return preset.name.lowercased().contains(trimmed)
                || preset.description.lowercased().contains(trimmed)
                || preset.tags.contains { $0.lowercased().contains(trimmed) }
        }
    }

    public func reloadTemplates() {
        templatePresets = dependencies.transitionTemplates.loadAllTemplates()
        Task { await syncFromRemoteIfAvailable(force: true) }
    }

    public func syncFromRemoteIfAvailable(force: Bool = false) async {
        guard force || !dependencies.transitionTemplates.hasSyncedFromRemote else {
            templatePresets = dependencies.transitionTemplates.loadAllTemplates()
            return
        }
        guard let repo = dependencies.presetRepositories.transitionRepository else {
            templatePresets = dependencies.transitionTemplates.loadAllTemplates()
            return
        }
        isSyncingRemote = true
        defer { isSyncingRemote = false }
        do {
            let fetched = try await repo.fetchPresets()
            templatePresets = fetched
        } catch {
            transitionLibraryLogger.error("Đồng bộ TransitionPresets từ Supabase thất bại: \(error.localizedDescription)")
            templatePresets = dependencies.transitionTemplates.loadAllTemplates()
        }
    }

    /// Thêm hiệu ứng chuyển cảnh vào cặp clip liền kề gần nhất trên Timeline.
    public func applyTransitionToTimeline(_ preset: TransitionPreset) {
        guard let timelineViewModel else { return }

        if let selectedClipID = timelineViewModel.selectedClipIDs.first {
            for layer in timelineViewModel.layers where layer.kind == .video || layer.kind == .image {
                let neighbors = layer.neighbors(of: selectedClipID)
                if let next = neighbors.next {
                    timelineViewModel.addOrUpdateCutTransition(preset, between: selectedClipID, and: next.id)
                    return
                } else if let prev = neighbors.previous {
                    timelineViewModel.addOrUpdateCutTransition(preset, between: prev.id, and: selectedClipID)
                    return
                }
            }
        }

        for layer in timelineViewModel.layers where layer.kind == .video || layer.kind == .image {
            let sortedClips = layer.clips
            if sortedClips.count >= 2 {
                timelineViewModel.addOrUpdateCutTransition(preset, between: sortedClips[0].id, and: sortedClips[1].id)
                return
            }
        }
    }
}

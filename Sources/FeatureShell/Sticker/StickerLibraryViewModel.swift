import Foundation
import Observation
import OSLog
import Domain

private let stickerLibraryLogger = Logger(subsystem: "VideoEditor", category: "StickerLibraryViewModel")

/// Quản lý trạng thái và danh sách mẫu Nhãn dán (SVG / PNG / GIF / APNG) bên sidebar trái,
/// đồng bộ bất đồng bộ với kho `sticker_presets` trên Supabase (Offline-First / SWR).
/// Tuân thủ AGENTS.md R3.2 (@Observable) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@Observable
@MainActor
public final class StickerLibraryViewModel {
    public var selectedCategory: StickerCategory = .all
    public var searchQuery: String = ""
    public private(set) var templatePresets: [StickerPreset] = []
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
        self.templatePresets = deps.stickerTemplates.loadAllTemplates()
    }

    public var filteredPresets: [StickerPreset] {
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
        templatePresets = dependencies.stickerTemplates.loadAllTemplates()
        Task { await syncFromRemoteIfAvailable(force: true) }
    }

    public func syncFromRemoteIfAvailable(force: Bool = false) async {
        guard force || !dependencies.stickerTemplates.hasSyncedFromRemote else {
            templatePresets = dependencies.stickerTemplates.loadAllTemplates()
            return
        }
        guard let repo = dependencies.presetRepositories.stickerRepository else {
            templatePresets = dependencies.stickerTemplates.loadAllTemplates()
            return
        }
        isSyncingRemote = true
        defer { isSyncingRemote = false }
        do {
            let fetched = try await repo.fetchPresets()
            templatePresets = fetched
        } catch {
            stickerLibraryLogger.error("Đồng bộ StickerPresets từ Supabase thất bại: \(error.localizedDescription)")
            templatePresets = dependencies.stickerTemplates.loadAllTemplates()
        }
    }

    public func addStickerToTimeline(_ preset: StickerPreset) {
        guard let timelineViewModel else { return }
        timelineViewModel.addStickerPreset(preset)
    }
}

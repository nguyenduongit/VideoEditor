import Foundation
import Observation
import Domain

/// Quản lý danh sách mẫu Hiệu ứng thị giác (Effect Presets) trực tuyến từ Kho Thư viện Cộng đồng (Supabase).
/// Tuân thủ AGENTS.md R3.2 (@Observable) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@Observable
@MainActor
public final class EffectLibraryViewModel {
    public var selectedCategory: EffectTemplateCategory = .all
    public var selectedSort: CommunitySortOption = .popular
    public var searchQuery: String = ""
    public private(set) var templatePresets: [EffectPreset] = []
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?
    @ObservationIgnored nonisolated(unsafe) private var notificationObserver: (any NSObjectProtocol)?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        let deps = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.dependencies = deps
        self.templatePresets = deps.effectTemplates.loadAllTemplates()
        setupNotificationObserver()
        syncPresetsFromSupabase()
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .presetStoreDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.templatePresets = self.dependencies.effectTemplates.loadAllTemplates()
                self.syncPresetsFromSupabase()
            }
        }
    }

    /// Tương thích ngược với các bài kiểm thử gọi `availableEffects`
    public var availableEffects: [EffectType] {
        let all = EffectType.allCases
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let query = trimmed.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    /// Danh sách EffectPreset đã lọc theo danh mục, từ khóa tìm kiếm và sắp xếp cộng đồng
    public var filteredPresets: [EffectPreset] {
        let currentAuthor = CommunityIdentity.currentAuthorID
        let filtered = templatePresets.filter { preset in
            let matchesCategory = selectedCategory == .all || preset.category == selectedCategory
            guard matchesCategory else { return false }
            if selectedSort == .mine && preset.community.authorID != currentAuthor {
                return false
            }
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            let query = trimmed.lowercased()
            if preset.name.lowercased().contains(query) { return true }
            if preset.description.lowercased().contains(query) { return true }
            if preset.community.authorName.lowercased().contains(query) { return true }
            return preset.tags.contains { $0.lowercased().contains(query) }
        }

        switch selectedSort {
        case .popular:
            return filtered.sorted {
                if $0.isSystem != $1.isSystem { return $0.isSystem && !$1.isSystem }
                return $0.community.downloadsCount > $1.community.downloadsCount
            }
        case .newest, .mine:
            return filtered.sorted { $0.community.createdAtTimestamp > $1.community.createdAtTimestamp }
        }
    }

    public func syncPresetsFromSupabase() {
        Task { [weak self] in
            guard let self, let repo = self.dependencies.presetRepositories.effectRepository else { return }
            if let fresh = try? await repo.fetchPresets() {
                await MainActor.run {
                    self.templatePresets = fresh
                }
            }
        }
    }

    public func reloadTemplates() {
        templatePresets = dependencies.effectTemplates.reload()
        syncPresetsFromSupabase()
    }

    public func addEffectToTimeline(type: EffectType) {
        let config = EffectConfiguration(type: type)
        timelineViewModel?.addEffectClip(named: type.displayName, config: config, durationSeconds: 3.0)
    }

    public func addPresetToTimeline(_ preset: EffectPreset) {
        timelineViewModel?.addEffectClip(
            named: preset.name,
            config: preset.config,
            durationSeconds: preset.defaultDuration,
            originPresetID: preset.isSystem ? nil : preset.id
        )
        incrementDownloadCount(for: preset)
    }

    public func incrementDownloadCount(for preset: EffectPreset) {
        var updated = preset
        updated.community.downloadsCount += 1
        dependencies.effectTemplates.updateInMemoryPreset(updated)
        templatePresets = dependencies.effectTemplates.loadAllTemplates()
        guard !preset.isSystem else { return }
        Task {
            try? await dependencies.presetRepositories.effectRepository?.savePreset(updated)
        }
    }

    public func deletePreset(_ preset: EffectPreset) {
        guard preset.canBeModified(by: CommunityIdentity.currentAuthorID) else { return }
        templatePresets.removeAll { $0.id == preset.id }
        dependencies.effectTemplates.removeInMemoryPreset(id: preset.id)
        Task {
            try? await dependencies.presetRepositories.effectRepository?.deletePreset(id: preset.id)
        }
    }
}

import Foundation
import Observation
import Domain

/// Quản lý trạng thái và thao tác trong thư viện Adjustment Layer (Sidebar trái).
/// Hỗ trợ lọc theo danh mục, tìm kiếm theo tên/tag và nạp JSON script từ Local / Supabase.
/// Tuân thủ R3.2 (@Observable) và R7.1 của AGENTS.md.
@Observable
@MainActor
public final class AdjustmentLibraryViewModel {
    public enum SubTab: String, CaseIterable, Sendable {
        case `default` = "Mặc định"
        case templates = "Presets"
    }

    public var selectedSubTab: SubTab = .default
    public var selectedCategory: AdjustmentTemplateCategory = .all
    public var searchQuery: String = ""
    public private(set) var templatePresets: [AdjustmentPreset] = []
    public weak var timelineViewModel: TimelineViewModel?
    @ObservationIgnored nonisolated(unsafe) private var notificationObserver: (any NSObjectProtocol)?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
        if PresetRepositoryProvider.shared.adjustmentRepository == nil {
            self.templatePresets = AdjustmentPreset.templates
        } else if AdjustmentTemplateLoader.shared.hasSyncedFromRemote {
            self.templatePresets = AdjustmentTemplateLoader.shared.loadAllTemplates()
        } else {
            self.templatePresets = []
        }
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
                self?.syncPresetsFromSupabase()
            }
        }
    }

    public var defaultPreset: AdjustmentPreset {
        .default
    }

    /// Đồng bộ SWR: Tải danh sách mới nhất từ Supabase ngầm trong nền
    public func syncPresetsFromSupabase() {
        Task { [weak self] in
            guard let repo = PresetRepositoryProvider.shared.adjustmentRepository else { return }
            if let fresh = try? await repo.fetchPresets() {
                await MainActor.run {
                    self?.templatePresets = fresh
                    AdjustmentThumbnailRenderer.shared.invalidateCache()
                }
            }
        }
    }

    /// Danh sách preset đã lọc theo category và từ khóa tìm kiếm.
    public var filteredTemplatePresets: [AdjustmentPreset] {
        templatePresets.filter { preset in
            let matchesCategory = selectedCategory == .all || preset.category == selectedCategory
            guard matchesCategory else { return false }
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            let query = trimmed.lowercased()
            if preset.name.lowercased().contains(query) { return true }
            if preset.description.lowercased().contains(query) { return true }
            return preset.tags.contains { $0.lowercased().contains(query) }
        }
    }

    /// Tải lại toàn bộ JSON script từ bộ nhớ cục bộ và cache Supabase.
    public func reloadTemplates() {
        AdjustmentThumbnailRenderer.shared.invalidateCache()
        templatePresets = AdjustmentTemplateLoader.shared.reload()
        syncPresetsFromSupabase()
    }

    /// Xóa 1 preset người dùng tạo khỏi Local Cache và Supabase
    public func deletePreset(_ preset: AdjustmentPreset) {
        guard !preset.isSystem else { return }
        templatePresets.removeAll { $0.id == preset.id }
        AdjustmentThumbnailRenderer.shared.invalidateCache()
        Task {
            try? await PresetRepositoryProvider.shared.adjustmentRepository?.deletePreset(id: preset.id)
        }
    }

    /// Nhập thêm mảng JSON script tải về từ Supabase DB (`adjustment_presets`).
    public func importSupabaseTemplates(jsonPayloads: [String]) {
        AdjustmentThumbnailRenderer.shared.invalidateCache()
        templatePresets = AdjustmentTemplateLoader.shared.mergeSupabaseTemplateScripts(
            jsonPayloads,
            persistToCache: true
        )
    }

    public func addPresetToTimeline(_ preset: AdjustmentPreset) {
        guard let timelineViewModel else { return }
        timelineViewModel.addAdjustmentClip(
            named: preset.name,
            config: preset.config,
            originPresetID: preset.id == "default" ? nil : preset.id
        )
    }
}

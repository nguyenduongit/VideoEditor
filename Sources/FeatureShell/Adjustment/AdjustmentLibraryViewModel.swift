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
        case templates = "Templates"
    }

    public var selectedSubTab: SubTab = .default
    public var selectedCategory: AdjustmentTemplateCategory = .all
    public var searchQuery: String = ""
    public private(set) var templatePresets: [AdjustmentPreset] = []
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
        self.templatePresets = AdjustmentPreset.templates
    }

    public var defaultPreset: AdjustmentPreset {
        .default
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
    }

    /// Nhập thêm mảng JSON script tải về từ Supabase DB (`adjustment_templates.script_json`).
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
            config: preset.config
        )
    }
}

import Foundation
import Observation
import Domain

/// Quản lý trạng thái, bộ lọc danh mục và thao tác trong thư viện Text Layer (Sidebar trái).
/// Hỗ trợ nạp động các kịch bản JSON cục bộ và đồng bộ từ Supabase.
/// Tuân thủ R3.2 (@Observable) và R7.1 của AGENTS.md.
@Observable
@MainActor
public final class TextLibraryViewModel {
    public enum SubTab: String, CaseIterable, Sendable {
        case `default` = "Mặc định"
        case templates = "Templates"
    }

    public var selectedSubTab: SubTab = .default
    public var selectedCategory: TextTemplateCategory = .all
    public var searchQuery: String = ""
    public private(set) var templatePresets: [TextPreset] = []
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
        self.templatePresets = TextPreset.templates
    }

    public var defaultPreset: TextPreset {
        .default
    }

    /// Danh sách mẫu chữ sau khi lọc theo danh mục (`selectedCategory`) và từ khóa (`searchQuery`)
    public var filteredTemplatePresets: [TextPreset] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return templatePresets.filter { preset in
            let matchesCategory = (selectedCategory == .all) || (preset.category == selectedCategory)
            guard matchesCategory else { return false }
            guard !query.isEmpty else { return true }
            let inName = preset.name.lowercased().contains(query)
            let inDesc = preset.description.lowercased().contains(query)
            let inContent = preset.config.content.lowercased().contains(query)
            let inTags = preset.tags.contains { $0.lowercased().contains(query) }
            return inName || inDesc || inContent || inTags
        }
    }

    /// Nạp lại danh sách mẫu chữ từ các thư mục JSON trên đĩa
    public func reloadTemplates() {
        templatePresets = TextTemplateLoader.shared.reload()
    }

    /// Nhập danh sách kịch bản JSON tải về từ bảng `text_templates` trên Supabase
    public func importSupabaseTemplates(jsonPayloads: [String]) {
        templatePresets = TextTemplateLoader.shared.mergeSupabaseTemplateScripts(jsonPayloads)
    }

    public func addPresetToTimeline(_ preset: TextPreset) {
        guard let timelineViewModel else { return }
        timelineViewModel.addTextPreset(preset)
    }
}

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
        case templates = "Presets"
    }

    public var selectedSubTab: SubTab = .default
    public var selectedCategory: TextTemplateCategory = .all
    public var searchQuery: String = ""
    public private(set) var templatePresets: [TextPreset] = []
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?
    /// Cho phép truy cập dọn dẹp NotificationCenter observer trong nonisolated deinit (R8.3).
    @ObservationIgnored nonisolated(unsafe) private var notificationObserver: (any NSObjectProtocol)?

    public init(timelineViewModel: TimelineViewModel? = nil, dependencies: EditorDependencies? = nil) {
        self.timelineViewModel = timelineViewModel
        let deps = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.dependencies = deps
        if deps.presetRepositories.textRepository == nil {
            self.templatePresets = deps.textTemplates.loadAllTemplates()
        } else if deps.textTemplates.hasSyncedFromRemote {
            self.templatePresets = deps.textTemplates.loadAllTemplates()
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

    public var defaultPreset: TextPreset {
        .default
    }

    /// Danh sách toàn bộ mẫu chữ hiển thị với item Mặc định ở vị trí đầu tiên (khi chọn Tất cả và không tìm kiếm)
    public var filteredPresetsWithDefaultFirst: [TextPreset] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedCategory == .all && query.isEmpty {
            let withoutDefault = filteredTemplatePresets.filter { $0.id != defaultPreset.id }
            return [defaultPreset] + withoutDefault
        }
        return filteredTemplatePresets
    }

    /// Đồng bộ SWR: Tải danh sách mới nhất từ Supabase ngầm trong nền
    public func syncPresetsFromSupabase() {
        Task { [weak self] in
            guard let self, let repo = self.dependencies.presetRepositories.textRepository else { return }
            if let fresh = try? await repo.fetchPresets() {
                await MainActor.run {
                    self.templatePresets = fresh
                }
            }
        }
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
        templatePresets = dependencies.textTemplates.reload()
        syncPresetsFromSupabase()
    }

    /// Xóa 1 preset người dùng tạo khỏi Local Cache và Supabase
    public func deletePreset(_ preset: TextPreset) {
        guard !preset.isSystem else { return }
        templatePresets.removeAll { $0.id == preset.id }
        Task {
            try? await dependencies.presetRepositories.textRepository?.deletePreset(id: preset.id)
        }
    }

    /// Nhập danh sách kịch bản JSON tải về từ bảng `text_presets` trên Supabase
    public func importSupabaseTemplates(jsonPayloads: [String]) {
        templatePresets = dependencies.textTemplates.mergeSupabaseTemplateScripts(jsonPayloads)
    }

    public func addPresetToTimeline(_ preset: TextPreset) {
        guard let timelineViewModel else { return }
        timelineViewModel.addTextPreset(preset)
    }
}

import Foundation
import Observation
import Domain

/// Manages the Dev-Authored Stickers System Library (`StickerLibraryItem` — SVG / PNG / GIF / APNG) in the left sidebar.
/// Read-only to end users per AGENTS.md Article 15 (100% local catalog, zero Supabase sync).
@Observable
@MainActor
public final class StickerLibraryViewModel {
    public var selectedCategory: StickerCategory = .all
    public var searchQuery: String = ""
    public private(set) var items: [StickerLibraryItem] = []
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        let deps = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.dependencies = deps
        self.items = deps.stickerLibrary.loadAllItems()
    }

    public var filteredItems: [StickerLibraryItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            let matchesCategory = (selectedCategory == .all) || (item.category == selectedCategory)
            guard matchesCategory else { return false }
            guard !trimmed.isEmpty else { return true }
            return item.name.lowercased().contains(trimmed)
                || item.description.lowercased().contains(trimmed)
                || item.tags.contains { $0.lowercased().contains(trimmed) }
        }
    }

    public func reloadItems() {
        items = dependencies.stickerLibrary.loadAllItems()
    }

    public func addStickerToTimeline(_ item: StickerLibraryItem) {
        timelineViewModel?.addStickerItem(item)
    }
}

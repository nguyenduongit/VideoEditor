import Foundation
import Observation
import Domain

/// Manages the Dev-Authored Effects System Library (`EffectLibraryItem`) in the left sidebar.
/// Read-only to end users per AGENTS.md Article 15 (no Supabase preset sync or user deletion).
@Observable
@MainActor
public final class EffectLibraryViewModel {
    public var selectedCategory: EffectCategory = .all
    public var searchQuery: String = ""
    public private(set) var items: [EffectLibraryItem] = []
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        let deps = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.dependencies = deps
        self.items = deps.effectLibrary.loadAllItems()
    }

    public var availableEffects: [EffectType] {
        let all = EffectType.allCases
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let query = trimmed.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    public var filteredItems: [EffectLibraryItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            let matchesCategory = selectedCategory == .all || item.category == selectedCategory
            guard matchesCategory else { return false }
            guard !trimmed.isEmpty else { return true }
            return item.name.lowercased().contains(trimmed)
                || item.description.lowercased().contains(trimmed)
                || item.tags.contains { $0.lowercased().contains(trimmed) }
        }
    }

    public func reloadItems() {
        items = dependencies.effectLibrary.loadAllItems()
    }

    public func addEffectToTimeline(type: EffectType) {
        let config = EffectConfiguration(type: type)
        timelineViewModel?.addEffectClip(named: type.displayName, config: config, durationSeconds: 3.0)
    }

    public func addToTimeline(_ item: EffectLibraryItem) {
        timelineViewModel?.addEffectClip(
            named: item.name,
            config: item.config,
            durationSeconds: item.defaultDuration,
            originPresetID: nil
        )
    }
}

import Foundation
import Observation
import Domain

/// Manages the Dev-Authored Transitions System Library (`TransitionLibraryItem`) in the left sidebar.
/// Read-only to end users per AGENTS.md Article 15 (100% local Metal catalog, zero Supabase sync).
@Observable
@MainActor
public final class TransitionLibraryViewModel {
    public var selectedCategory: TransitionCategory = .all
    public var searchQuery: String = ""
    public private(set) var items: [TransitionLibraryItem] = []
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        let deps = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.dependencies = deps
        self.items = deps.transitionLibrary.loadAllItems()
    }

    public var filteredItems: [TransitionLibraryItem] {
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
        items = dependencies.transitionLibrary.loadAllItems()
    }

    /// Applies or replaces a system cut transition on contiguous video/image clips on the Timeline.
    public func applyTransitionToTimeline(_ item: TransitionLibraryItem) {
        guard let timelineViewModel else { return }

        if let selectedTransID = timelineViewModel.selectedTransitionID {
            for layer in timelineViewModel.layers where (layer.kind == .video || layer.kind == .image) && !layer.isLocked && !layer.isHidden {
                if let existing = layer.transition(by: selectedTransID),
                   layer.areClipsContiguous(leadingID: existing.leadingClipID, trailingID: existing.trailingClipID) {
                    timelineViewModel.addOrUpdateCutTransition(item, between: existing.leadingClipID, and: existing.trailingClipID)
                    return
                }
            }
        }

        if let selectedClipID = timelineViewModel.selectedClipIDs.first {
            for layer in timelineViewModel.layers where (layer.kind == .video || layer.kind == .image) && !layer.isLocked && !layer.isHidden {
                let neighbors = layer.neighbors(of: selectedClipID)
                if let next = neighbors.next,
                   layer.areClipsContiguous(leadingID: selectedClipID, trailingID: next.id) {
                    timelineViewModel.addOrUpdateCutTransition(item, between: selectedClipID, and: next.id)
                    return
                } else if let prev = neighbors.previous,
                          layer.areClipsContiguous(leadingID: prev.id, trailingID: selectedClipID) {
                    timelineViewModel.addOrUpdateCutTransition(item, between: prev.id, and: selectedClipID)
                    return
                }
            }
        }

        for layer in timelineViewModel.layers where (layer.kind == .video || layer.kind == .image) && !layer.isLocked && !layer.isHidden {
            let sortedClips = layer.clips
            guard sortedClips.count >= 2 else { continue }
            for idx in 0..<(sortedClips.count - 1) {
                let leadID = sortedClips[idx].id
                let trailID = sortedClips[idx + 1].id
                if layer.areClipsContiguous(leadingID: leadID, trailingID: trailID) {
                    timelineViewModel.addOrUpdateCutTransition(item, between: leadID, and: trailID)
                    return
                }
            }
        }
    }
}

import Foundation
import CoreMedia
import Observation
import Domain

/// Manages Audio Library items (`AudioLibraryItem` — Music, SFX, Dance Beat Counter) from Supabase or local fallback.
/// Read-only Cloud Media Feed to end users per AGENTS.md Article 15.
@Observable
@MainActor
public final class AudioSidebarViewModel {
    public var selectedCategory: String = "Music"
    public var searchQuery: String = ""
    public private(set) var items: [AudioLibraryItem] = []
    public private(set) var isLoading: Bool = false

    public let categories = ["Music", "Sound Effects", "Dance Beat"]
    public let dependencies: EditorDependencies
    public weak var timelineViewModel: TimelineViewModel?

    @ObservationIgnored nonisolated(unsafe) private var notificationObserver: (any NSObjectProtocol)?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        self.dependencies = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.items = AudioLibraryItem.builtInCatalog

        setupNotificationObserver()
        syncFromSupabase()
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    public var filteredItems: [AudioLibraryItem] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [AudioLibraryItem]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "audio")
            base = items.filter { favs.contains($0.id) }
        } else if !trimmedQuery.isEmpty {
            base = items
        } else {
            base = items.filter { $0.category == selectedCategory }
        }
        guard !trimmedQuery.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.category.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    public func syncFromSupabase() {
        guard let repo = dependencies.presetRepositories.audioRepository else { return }
        isLoading = true
        Task { [weak self] in
            do {
                let fetched = try await repo.fetchAudioItems()
                guard let self else { return }
                self.items = fetched
                self.isLoading = false
            } catch {
                guard let self else { return }
                self.isLoading = false
            }
        }
    }

    public func addToTimeline(_ item: AudioLibraryItem) {
        if item.id == "audio_dance_beat" {
            timelineViewModel?.addDanceBeatCounter()
        } else {
            let durSeconds = item.duration > 0 ? item.duration : 5.0
            let clip = TimelineClip(
                name: item.name,
                kind: .audio,
                timeRange: .init(
                    start: timelineViewModel?.currentTime ?? .zero,
                    duration: CMTime(seconds: durSeconds, preferredTimescale: 600)
                ),
                mediaURL: item.audioURL
            )
            timelineViewModel?.addClip(clip)
        }
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .presetStoreDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFromSupabase()
            }
        }
    }
}

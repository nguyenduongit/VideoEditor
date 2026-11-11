import Foundation
import CoreMedia
import Observation
import Domain

/// Quản lý trạng thái và thao tác nạp tài nguyên âm thanh (Music, SFX) từ Supabase hoặc Local Seed.
/// Tuân thủ AGENTS.md (Cấp 3 ViewModel, @Observable, @MainActor, File <= 300 dòng).
@Observable
@MainActor
public final class AudioSidebarViewModel {
    public var selectedCategory: String = "Music"
    public var searchQuery: String = ""
    public private(set) var presets: [AudioPreset] = []
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
        self.presets = AudioPreset.builtInCatalog

        setupNotificationObserver()
        syncPresetsFromSupabase()
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    public var filteredItems: [AudioPreset] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [AudioPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "audio")
            base = presets.filter { favs.contains($0.id) }
        } else if !trimmedQuery.isEmpty {
            base = presets
        } else {
            base = presets.filter { $0.category == selectedCategory }
        }
        guard !trimmedQuery.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.category.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    public func syncPresetsFromSupabase() {
        guard let repo = dependencies.presetRepositories.audioRepository else { return }
        isLoading = true
        Task { [weak self] in
            do {
                let fetched = try await repo.fetchPresets()
                guard let self else { return }
                self.presets = fetched
                self.isLoading = false
            } catch {
                guard let self else { return }
                self.isLoading = false
            }
        }
    }

    public func addPresetToTimeline(_ preset: AudioPreset) {
        if preset.id == "audio_dance_beat" {
            timelineViewModel?.addDanceBeatCounter()
        } else {
            let durSeconds = preset.duration > 0 ? preset.duration : 5.0
            let clip = TimelineClip(
                name: preset.name,
                kind: .audio,
                timeRange: .init(
                    start: timelineViewModel?.currentTime ?? .zero,
                    duration: CMTime(seconds: durSeconds, preferredTimescale: 600)
                )
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
                self?.syncPresetsFromSupabase()
            }
        }
    }
}


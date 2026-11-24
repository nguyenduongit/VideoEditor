import Foundation
import SwiftUI
import Observation
import Domain

/// Quản lý trạng thái danh mục Yêu thích (Favorites) cho 7 tab của Sidebar trái.
/// Kết hợp bộ nhớ đệm phản hồi tức thì 60fps (In-Memory + UserDefaults) và đồng bộ Cloud Supabase.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng) và R2.4 của AGENTS.md.
@Observable
@MainActor
public final class SidebarFavoriteManager: Sendable {
    public static let shared = SidebarFavoriteManager()
    public static let favoritesCategory = "favorites"
    public static let dividerCategory = "---"
    private static let allTabs = ["media", "audio", "text", "effect", "transition", "adjustment", "sticker"]
    private static let cloudSyncedTabs = ["media", "audio", "text", "adjustment"]

    public private(set) var favoriteMap: [String: Set<String>] = [:]

    private let userDefaults: UserDefaults
    private var repository: (any FavoriteRepositoryProtocol)?

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadAllFavoritesFromDisk()
    }

    /// Cấu hình kho lưu trữ đám mây Supabase và khởi động đồng bộ ngầm
    public func configure(repository: any FavoriteRepositoryProtocol) {
        self.repository = repository
        syncWithCloud()
    }

    public func isFavorite(id: String, for tab: String) -> Bool {
        favoriteMap[tab]?.contains(id) ?? false
    }

    public func toggleFavorite(id: String, for tab: String) {
        if isFavorite(id: id, for: tab) {
            removeFavorite(id: id, for: tab)
        } else {
            addFavorite(id: id, for: tab)
        }
    }

    public func addFavorite(id: String, for tab: String) {
        var current = favoriteMap[tab] ?? []
        current.insert(id)
        favoriteMap[tab] = current
        saveFavoritesToDisk(for: tab)

        if let repository, Self.cloudSyncedTabs.contains(tab) {
            Task {
                try? await repository.addFavorite(id: id, for: tab)
            }
        }
    }

    public func removeFavorite(id: String, for tab: String) {
        var current = favoriteMap[tab] ?? []
        current.remove(id)
        favoriteMap[tab] = current
        saveFavoritesToDisk(for: tab)

        if let repository, Self.cloudSyncedTabs.contains(tab) {
            Task {
                try? await repository.removeFavorite(id: id, for: tab)
            }
        }
    }

    public func favorites(for tab: String) -> Set<String> {
        favoriteMap[tab] ?? []
    }

    public func syncWithCloud() {
        Task { [weak self] in
            await self?.syncWithCloudNow()
        }
    }

    public func syncWithCloudNow() async {
        guard let repository else { return }
        for tab in Self.cloudSyncedTabs {
            if let cloudFavs = try? await repository.fetchFavorites(for: tab) {
                let localDefaults = (favoriteMap[tab] ?? []).filter { $0.hasPrefix("default") }
                favoriteMap[tab] = cloudFavs.union(localDefaults)
                saveFavoritesToDisk(for: tab)
            }
        }
    }

    private func key(for tab: String) -> String {
        "sidebar_favorites_\(tab)"
    }

    private func saveFavoritesToDisk(for tab: String) {
        let set = favoriteMap[tab] ?? []
        let array = Array(set)
        userDefaults.set(array, forKey: key(for: tab))
    }

    private func loadAllFavoritesFromDisk() {
        var loaded: [String: Set<String>] = [:]
        for tab in Self.allTabs {
            if let array = userDefaults.stringArray(forKey: key(for: tab)) {
                loaded[tab] = Set(array)
            } else {
                loaded[tab] = []
            }
        }
        self.favoriteMap = loaded
    }
}

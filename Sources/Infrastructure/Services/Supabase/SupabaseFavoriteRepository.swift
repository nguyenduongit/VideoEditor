import Foundation
import OSLog
import Domain
import Supabase

private let favRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseFavoriteRepository")

/// Kho lưu trữ đồng bộ mục Yêu thích (Favorites) cho ứng dụng cá nhân (Single-User).
/// Đọc và cập nhật trực tiếp cột `is_favorite` trên chính bảng tài nguyên của từng tab Library trên Supabase,
/// loại bỏ hoàn toàn bảng trung gian `user_favorites`.
/// Tuân thủ AGENTS.md (Pure Domain Protocol implementation, Sendable, File <= 300 dòng).
public final class SupabaseFavoriteRepository: FavoriteRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let lock = NSLock()
    private var inMemoryFavorites: [String: Set<String>] = [:]

    public init(client: SupabaseClient? = SupabaseConfig.makeClient()) {
        self.client = client
    }

    /// Ánh xạ tên tab Sidebar trái sang tên bảng Supabase tương ứng.
    public static func tableName(for tab: String) -> String? {
        switch tab {
        case "media":
            return "stock_media"
        case "audio":
            return "audio_presets"
        case "text":
            return "text_presets"
        case "effect":
            return "effect_presets"
        case "transition":
            return "transition_presets"
        case "adjustment":
            return "adjustment_presets"
        case "sticker":
            return "sticker_presets"
        default:
            return nil
        }
    }

    public func fetchFavorites(for tab: String) async throws -> Set<String> {
        guard let table = Self.tableName(for: tab), let client else {
            return currentFavorites(for: tab)
        }

        do {
            let rows: [FavoriteItemIDRow] = try await client
                .from(table)
                .select("id")
                .eq("is_favorite", value: true)
                .execute()
                .value

            let itemIDs = Set(rows.map(\.id))
            setInMemoryFavorites(itemIDs, for: tab)
            return itemIDs
        } catch {
            favRepoLogger.warning("Failed to fetch is_favorite from table '\(table)' for tab '\(tab)': \(error.localizedDescription)")
            return currentFavorites(for: tab)
        }
    }

    public func addFavorite(id: String, for tab: String) async throws {
        addToInMemory(id: id, for: tab)

        guard let table = Self.tableName(for: tab), let client else { return }
        do {
            try await client
                .from(table)
                .update(FavoriteTogglePayload(is_favorite: true))
                .eq("id", value: id)
                .execute()
        } catch {
            favRepoLogger.error("Failed to set is_favorite=true on table '\(table)': \(error.localizedDescription)")
        }
    }

    public func removeFavorite(id: String, for tab: String) async throws {
        removeFromInMemory(id: id, for: tab)

        guard let table = Self.tableName(for: tab), let client else { return }
        do {
            try await client
                .from(table)
                .update(FavoriteTogglePayload(is_favorite: false))
                .eq("id", value: id)
                .execute()
        } catch {
            favRepoLogger.error("Failed to clear is_favorite=false on table '\(table)': \(error.localizedDescription)")
        }
    }

    // MARK: - In-Memory Cache

    private func currentFavorites(for tab: String) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryFavorites[tab] ?? []
    }

    private func setInMemoryFavorites(_ set: Set<String>, for tab: String) {
        lock.lock()
        defer { lock.unlock() }
        inMemoryFavorites[tab] = set
    }

    private func addToInMemory(id: String, for tab: String) {
        lock.lock()
        defer { lock.unlock() }
        var current = inMemoryFavorites[tab] ?? []
        current.insert(id)
        inMemoryFavorites[tab] = current
    }

    private func removeFromInMemory(id: String, for tab: String) {
        lock.lock()
        defer { lock.unlock() }
        var current = inMemoryFavorites[tab] ?? []
        current.remove(id)
        inMemoryFavorites[tab] = current
    }
}

// MARK: - Supabase DTO Rows

private struct FavoriteItemIDRow: Codable, Sendable {
    let id: String
}

private struct FavoriteTogglePayload: Codable, Sendable {
    let is_favorite: Bool
}

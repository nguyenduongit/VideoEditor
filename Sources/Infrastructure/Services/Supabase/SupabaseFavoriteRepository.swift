import Foundation
import OSLog
import Domain
import Supabase

private let favRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseFavoriteRepository")

/// Kho lưu trữ đồng bộ mục Yêu thích (Favorites) của người dùng qua Supabase Database (`user_favorites`).
/// Sử dụng Client ID ẩn danh (Device UUID) khi chưa đăng nhập, hỗ trợ SWR và phản hồi tức thì.
/// Tuân thủ AGENTS.md (Pure Domain Protocol implementation, Sendable, File <= 300 dòng).
public final class SupabaseFavoriteRepository: FavoriteRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "user_favorites"
    private let lock = NSLock()
    private var inMemoryFavorites: [String: Set<String>] = [:]
    private let clientID: String

    public init(
        client: SupabaseClient? = SupabaseConfig.makeClient(),
        customClientID: String? = nil
    ) {
        self.client = client
        if let customClientID {
            self.clientID = customClientID
        } else {
            let key = "com.videoeditor.client_device_uuid"
            if let saved = UserDefaults.standard.string(forKey: key) {
                self.clientID = saved
            } else {
                let newID = UUID().uuidString
                UserDefaults.standard.set(newID, forKey: key)
                self.clientID = newID
            }
        }
    }

    public func fetchFavorites(for tab: String) async throws -> Set<String> {
        guard let client else {
            return currentFavorites(for: tab)
        }

        do {
            let rows: [UserFavoriteRow] = try await client
                .from(tableName)
                .select()
                .eq("user_id", value: clientID)
                .eq("tab", value: tab)
                .execute()
                .value

            let itemIDs = Set(rows.map(\.item_id))
            setInMemoryFavorites(itemIDs, for: tab)
            return itemIDs
        } catch {
            favRepoLogger.warning("Không thể tải favorites từ Supabase cho tab '\(tab)': \(error.localizedDescription)")
            return currentFavorites(for: tab)
        }
    }

    public func addFavorite(id: String, for tab: String) async throws {
        addToInMemory(id: id, for: tab)

        guard let client else { return }
        let row = UserFavoriteRow(user_id: clientID, tab: tab, item_id: id)
        do {
            try await client.from(tableName).upsert(row).execute()
        } catch {
            favRepoLogger.error("Lỗi khi thêm favorite lên Supabase: \(error.localizedDescription)")
        }
    }

    public func removeFavorite(id: String, for tab: String) async throws {
        removeFromInMemory(id: id, for: tab)

        guard let client else { return }
        do {
            try await client
                .from(tableName)
                .delete()
                .eq("user_id", value: clientID)
                .eq("tab", value: tab)
                .eq("item_id", value: id)
                .execute()
        } catch {
            favRepoLogger.error("Lỗi khi xóa favorite trên Supabase: \(error.localizedDescription)")
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

// MARK: - Supabase DTO Row

private struct UserFavoriteRow: Codable, Sendable {
    let user_id: String
    let tab: String
    let item_id: String
}


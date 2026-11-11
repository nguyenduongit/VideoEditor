import Foundation
import OSLog
import Domain
import Supabase

private let stockRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseStockMediaRepository")

/// Kho lưu trữ tài nguyên đa phương tiện kết nối trực tiếp bảng `stock_items` trên Supabase.
/// Hỗ trợ Offline-First / SWR và Upsert an toàn.
/// Tuân thủ AGENTS.md (Pure Domain Protocol implementation, Sendable, File <= 300 dòng).
public final class SupabaseStockMediaRepository: StockMediaRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "stock_media"
    private let lock = NSLock()
    private var inMemoryCatalog: [StockMediaItem]

    public init(client: SupabaseClient? = SupabaseConfig.makeClient()) {
        self.client = client
        self.inMemoryCatalog = StockMediaItem.builtInCatalog
    }

    public func fetchStockItems() async throws -> [StockMediaItem] {
        guard let client else {
            return currentCatalog()
        }

        do {
            let rows: [StockMediaRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.compactMap { $0.toItem() }
            let systemIDs = Set(StockMediaItem.builtInCatalog.map(\.id))
            let fetchedIDs = Set(fetched.map(\.id))

            if !systemIDs.isSubset(of: fetchedIDs) {
                try? await seedSystemCatalogSafely(preserving: fetched)
            } else {
                updateCatalog(fetched)
            }
            return currentCatalog()
        } catch {
            stockRepoLogger.warning("Không thể tải stock_items từ Supabase, dùng cache: \(error.localizedDescription)")
            return currentCatalog()
        }
    }

    public func saveStockItem(_ item: StockMediaItem) async throws {
        upsertInMemory(item)

        guard let client else {
            NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
            return
        }

        let row = StockMediaRow(from: item)
        do {
            try await client.from(tableName).upsert(row).execute()
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && (ns.code == NSURLErrorNetworkConnectionLost || ns.code == NSURLErrorTimedOut) {
                try await Task.sleep(nanoseconds: 300_000_000)
                try await client.from(tableName).upsert(row).execute()
            } else {
                throw error
            }
        }
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    public func deleteStockItem(id: String) async throws {
        removeInMemory(id: id)

        guard let client else {
            NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
            return
        }

        try await client.from(tableName).delete().eq("id", value: id).execute()
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    public func seedSystemCatalogSafely(preserving existing: [StockMediaItem] = []) async throws {
        let existingIDs = Set(existing.map(\.id))
        let missing = StockMediaItem.builtInCatalog.filter { !existingIDs.contains($0.id) }
        let merged = existing + missing
        updateCatalog(merged)

        guard let client, !missing.isEmpty else { return }
        let rows = missing.map { StockMediaRow(from: $0) }
        _ = try? await client.from(tableName).upsert(rows).execute()
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    // MARK: - Thread-safe Memory Cache

    private func currentCatalog() -> [StockMediaItem] {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryCatalog
    }

    private func updateCatalog(_ items: [StockMediaItem]) {
        lock.lock()
        defer { lock.unlock() }
        self.inMemoryCatalog = items
    }

    private func upsertInMemory(_ item: StockMediaItem) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = inMemoryCatalog.firstIndex(where: { $0.id == item.id }) {
            inMemoryCatalog[idx] = item
        } else {
            inMemoryCatalog.append(item)
        }
    }

    private func removeInMemory(id: String) {
        lock.lock()
        defer { lock.unlock() }
        inMemoryCatalog.removeAll { $0.id == id }
    }
}

// MARK: - Supabase DTO Row

private struct StockMediaRow: Codable, Sendable {
    let id: String
    let name: String
    let category: String
    let media_type: String
    let media_url: String
    let thumbnail_url: String?
    let icon: String?

    init(from item: StockMediaItem) {
        self.id = item.id
        self.name = item.name
        self.category = item.category
        self.media_type = item.type.rawValue
        self.media_url = item.mediaURL.absoluteString
        self.thumbnail_url = item.thumbnailURL?.absoluteString
        self.icon = item.icon
    }

    func toItem() -> StockMediaItem? {
        guard let url = URL(string: media_url) else { return nil }
        let type = MediaType(rawValue: media_type) ?? (media_type == "solid_color" ? .image : .video)
        return StockMediaItem(
            id: id,
            name: name,
            category: category,
            type: type,
            mediaURL: url,
            thumbnailURL: thumbnail_url.flatMap { URL(string: $0) },
            icon: icon ?? "film.fill"
        )
    }
}

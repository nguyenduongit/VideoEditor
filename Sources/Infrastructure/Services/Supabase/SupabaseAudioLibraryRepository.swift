import Foundation
import OSLog
import Domain
import Supabase

private let audioRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseAudioLibraryRepository")

/// Cloud Media Feed repository for Audio items (`public.audio_library` on Supabase) with Offline-First cache.
/// Complies with AGENTS.md (Infrastructure implements Domain Protocol, Sendable, Article 15).
public final class SupabaseAudioLibraryRepository: AudioLibraryRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "audio_library"
    private let lock = NSLock()
    private var inMemoryCatalog: [AudioLibraryItem]

    public init(client: SupabaseClient? = SupabaseConfig.makeClient()) {
        self.client = client
        self.inMemoryCatalog = AudioLibraryItem.builtInCatalog
    }

    public func fetchAudioItems() async throws -> [AudioLibraryItem] {
        guard let client else {
            return currentCatalog()
        }

        do {
            let rows: [AudioLibraryRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toItem() }
            let danceBeat = AudioLibraryItem.builtInCatalog.filter { $0.id == "audio_dance_beat" }
            let merged = danceBeat.filter { db in !fetched.contains(where: { $0.id == db.id }) } + fetched
            updateCatalog(merged)
            return currentCatalog()
        } catch {
            audioRepoLogger.warning("Failed to fetch audio_library from Supabase, falling back to cache: \(error.localizedDescription)")
            return currentCatalog()
        }
    }

    public func saveAudioItem(_ item: AudioLibraryItem) async throws {
        upsertInMemory(item)

        guard let client else {
            NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
            return
        }

        let row = AudioLibraryRow(from: item)
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

    public func deleteAudioItem(id: String) async throws {
        removeInMemory(id: id)

        guard let client else {
            NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
            return
        }

        try await client.from(tableName).delete().eq("id", value: id).execute()
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    public func seedSystemCatalogSafely(preserving existing: [AudioLibraryItem] = []) async throws {
        let existingIDs = Set(existing.map(\.id))
        let missing = AudioLibraryItem.builtInCatalog.filter { !existingIDs.contains($0.id) }
        let merged = existing + missing
        updateCatalog(merged)

        guard let client, !missing.isEmpty else { return }
        let rows = missing.map { AudioLibraryRow(from: $0) }
        _ = try? await client.from(tableName).upsert(rows).execute()
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    // MARK: - Thread-safe Memory Cache

    private func currentCatalog() -> [AudioLibraryItem] {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryCatalog
    }

    private func updateCatalog(_ items: [AudioLibraryItem]) {
        lock.lock()
        defer { lock.unlock() }
        self.inMemoryCatalog = items
    }

    private func upsertInMemory(_ item: AudioLibraryItem) {
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

private struct AudioLibraryRow: Codable, Sendable {
    let id: String
    let name: String
    let category: String
    let duration: Double
    let audio_url: String?
    let icon: String?
    let is_system: Bool?

    init(from item: AudioLibraryItem) {
        self.id = item.id
        self.name = item.name
        self.category = item.category
        self.duration = item.duration
        self.audio_url = item.audioURL?.absoluteString
        self.icon = item.icon
        self.is_system = item.isSystem
    }

    func toItem() -> AudioLibraryItem {
        AudioLibraryItem(
            id: id,
            name: name,
            category: category,
            duration: duration,
            audioURL: audio_url.flatMap { URL(string: $0) },
            icon: icon ?? "music.note",
            isSystem: is_system ?? true
        )
    }
}

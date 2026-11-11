import Foundation
import OSLog
import Domain
import Supabase

private let audioRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseAudioPresetRepository")

/// Kho lưu trữ âm thanh (Music, SFX) kết nối trực tiếp bảng `audio_items` trên Supabase & Storage URL.
/// Hỗ trợ Offline-First / SWR và Upsert an toàn.
/// Tuân thủ AGENTS.md (Pure Domain Protocol implementation, Sendable, File <= 300 dòng).
public final class SupabaseAudioPresetRepository: AudioPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "audio_presets"
    private let lock = NSLock()
    private var inMemoryCatalog: [AudioPreset]

    public init(client: SupabaseClient? = SupabaseConfig.makeClient()) {
        self.client = client
        self.inMemoryCatalog = AudioPreset.builtInCatalog
    }

    public func fetchPresets() async throws -> [AudioPreset] {
        guard let client else {
            return currentCatalog()
        }

        do {
            let rows: [AudioPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            let danceBeat = AudioPreset.builtInCatalog.filter { $0.id == "audio_dance_beat" }
            let merged = danceBeat.filter { db in !fetched.contains(where: { $0.id == db.id }) } + fetched
            updateCatalog(merged)
            return currentCatalog()
        } catch {
            audioRepoLogger.warning("Không thể tải audio_items từ Supabase, dùng cache: \(error.localizedDescription)")
            return currentCatalog()
        }
    }

    public func savePreset(_ preset: AudioPreset) async throws {
        upsertInMemory(preset)

        guard let client else {
            NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
            return
        }

        let row = AudioPresetRow(from: preset)
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

    public func deletePreset(id: String) async throws {
        removeInMemory(id: id)

        guard let client else {
            NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
            return
        }

        try await client.from(tableName).delete().eq("id", value: id).execute()
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    public func seedSystemCatalogSafely(preserving existing: [AudioPreset] = []) async throws {
        let existingIDs = Set(existing.map(\.id))
        let missing = AudioPreset.builtInCatalog.filter { !existingIDs.contains($0.id) }
        let merged = existing + missing
        updateCatalog(merged)

        guard let client, !missing.isEmpty else { return }
        let rows = missing.map { AudioPresetRow(from: $0) }
        _ = try? await client.from(tableName).upsert(rows).execute()
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    // MARK: - Thread-safe Memory Cache

    private func currentCatalog() -> [AudioPreset] {
        lock.lock()
        defer { lock.unlock() }
        return inMemoryCatalog
    }

    private func updateCatalog(_ items: [AudioPreset]) {
        lock.lock()
        defer { lock.unlock() }
        self.inMemoryCatalog = items
    }

    private func upsertInMemory(_ item: AudioPreset) {
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

private struct AudioPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let category: String
    let duration: Double
    let audio_url: String?
    let icon: String?
    let is_system: Bool?

    init(from preset: AudioPreset) {
        self.id = preset.id
        self.name = preset.name
        self.category = preset.category
        self.duration = preset.duration
        self.audio_url = preset.audioURL?.absoluteString
        self.icon = preset.icon
        self.is_system = preset.isSystem
    }

    func toPreset() -> AudioPreset {
        AudioPreset(
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

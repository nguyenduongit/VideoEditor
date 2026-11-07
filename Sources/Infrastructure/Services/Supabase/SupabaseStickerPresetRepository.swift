import Foundation
import OSLog
import Domain
import Supabase

private let stickerRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseStickerPresetRepository")

/// Hiện thực kho lưu trữ mẫu Nhãn dán (`StickerPreset` — Vector SVG nội tuyến & GIF/APNG URL) qua Supabase Database (`sticker_presets`).
/// Áp dụng cơ chế Offline-First / Stale-While-Revalidate (SWR) và Upsert an toàn (không bao giờ xóa bảng người dùng).
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseStickerPresetRepository: StickerPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "sticker_presets"
    private let templateLoader: StickerTemplateLoader

    public init(
        client: SupabaseClient? = SupabaseConfig.makeClient(),
        templateLoader: StickerTemplateLoader = StickerTemplateLoader()
    ) {
        self.client = client
        self.templateLoader = templateLoader
    }

    public func fetchPresets() async throws -> [StickerPreset] {
        guard let client else {
            return templateLoader.loadAllTemplates()
        }

        do {
            let rows: [StickerPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            let systemIDs = Set(StickerPreset.builtInCatalog.map(\.id))
            let fetchedSystemIDs = Set(fetched.filter(\.isSystem).map(\.id))

            if !systemIDs.isSubset(of: fetchedSystemIDs) {
                do {
                    try await seedSystemCatalogSafely(preserving: fetched)
                } catch {
                    stickerRepoLogger.warning("Seed an toàn sticker_presets bỏ qua do lỗi mạng/bảng: \(error.localizedDescription)")
                    templateLoader.setInMemoryTemplates(fetched)
                }
                return templateLoader.loadAllTemplates()
            }

            templateLoader.setInMemoryTemplates(fetched)
            return templateLoader.loadAllTemplates()
        } catch {
            stickerRepoLogger.warning("Không thể tải sticker_presets từ Supabase, dùng cache nội bộ: \(error.localizedDescription)")
            return templateLoader.loadAllTemplates()
        }
    }

    public func savePreset(_ preset: StickerPreset) async throws {
        templateLoader.updateInMemoryPreset(preset)

        guard let client else { return }
        let row = StickerPresetRow(from: preset)
        do {
            try await client
                .from(tableName)
                .upsert(row)
                .execute()
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && (ns.code == NSURLErrorNetworkConnectionLost || ns.code == NSURLErrorTimedOut) {
                try await Task.sleep(nanoseconds: 300_000_000)
                try await client
                    .from(tableName)
                    .upsert(row)
                    .execute()
            } else {
                throw error
            }
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    public func deletePreset(id: String) async throws {
        templateLoader.removeInMemoryPreset(id: id)

        guard let client else { return }
        try await client
            .from(tableName)
            .delete()
            .eq("id", value: id)
            .execute()

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    /// Khởi tạo/cập nhật các mẫu Sticker hệ thống bằng Upsert không phá hủy (bảo toàn 100% mẫu người dùng).
    public func seedSystemCatalogSafely(preserving existingUserPresets: [StickerPreset] = []) async throws {
        let systemCatalog = StickerPreset.builtInCatalog
        let userOnly = existingUserPresets.filter { !$0.isSystem }
        templateLoader.setInMemoryTemplates(systemCatalog + userOnly)

        if let client {
            let rows = systemCatalog.map { StickerPresetRow(from: $0) }
            try await client
                .from(tableName)
                .upsert(rows)
                .execute()
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }
}

// MARK: - Supabase DTO Row

private struct StickerPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let format: String
    let tags: [String]?
    let default_duration: Double?
    let asset_path: String?
    let system_symbol_fallback: String?
    let config: StickerConfiguration
    let is_system: Bool?

    init(from preset: StickerPreset) {
        self.id = preset.id
        self.name = preset.name
        self.description = preset.description
        self.category = preset.category.rawValue
        self.format = preset.format.rawValue
        var mergedTags = preset.tags
        if let metaTag = preset.community.encodeToTag() {
            mergedTags.append(metaTag)
        }
        self.tags = mergedTags
        self.default_duration = preset.defaultDuration
        self.asset_path = preset.assetPath ?? preset.config.sourceURLString
        self.system_symbol_fallback = preset.systemSymbolFallback
        self.config = preset.config
        self.is_system = preset.isSystem
    }

    func toPreset() -> StickerPreset {
        let cat = StickerCategory(rawValue: category) ?? .emoji
        let fmt = StickerFormat(rawValue: format) ?? config.format
        let sys = is_system ?? false
        let (cleanTags, communityMeta) = CommunityMetadata.extract(from: tags, isSystem: sys)
        let builtIn = StickerPreset.builtInCatalog.first(where: { $0.id == id })
        return StickerPreset(
            id: id,
            name: name,
            description: description ?? "",
            category: cat,
            format: fmt,
            tags: cleanTags,
            defaultDuration: default_duration ?? builtIn?.defaultDuration ?? 3.0,
            assetPath: asset_path ?? config.sourceURLString,
            systemSymbolFallback: system_symbol_fallback ?? builtIn?.systemSymbolFallback ?? "face.smiling",
            config: config,
            isSystem: sys,
            community: communityMeta
        )
    }
}

import Foundation
import Domain
import Supabase

/// Hiện thực kho lưu trữ mẫu chữ (Text Presets) qua Supabase Database và Cache cục bộ.
/// Áp dụng cơ chế Offline-First / Stale-While-Revalidate (SWR) với Upsert an toàn (không xóa dữ liệu cộng đồng).
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseTextPresetRepository: TextPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "text_presets"
    private let templateLoader: TextTemplateLoader

    public init(
        client: SupabaseClient? = SupabaseConfig.makeClient(),
        templateLoader: TextTemplateLoader = TextTemplateLoader()
    ) {
        self.client = client
        self.templateLoader = templateLoader
    }

    public func fetchPresets() async throws -> [TextPreset] {
        guard let client else {
            return templateLoader.loadAllTemplates()
        }

        do {
            let rows: [TextPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            templateLoader.setInMemoryTemplates(fetched)
            return templateLoader.loadAllTemplates()
        } catch {
            return templateLoader.loadAllTemplates()
        }
    }

    public func savePreset(_ preset: TextPreset) async throws {
        templateLoader.updateInMemoryPreset(preset)

        guard let client else { return }
        let row = TextPresetRow(from: preset)
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

    /// Khởi tạo/cập nhật các mẫu cục bộ (Basic mặc định luôn giữ local)
    public func seedSystemCatalogSafely(preserving existingUserPresets: [TextPreset] = []) async throws {
        let userOnly = existingUserPresets.filter { !$0.isSystem && $0.id != TextPreset.default.id }
        templateLoader.setInMemoryTemplates([TextPreset.default] + TextPreset.creativeCatalog + userOnly)
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }
}

// MARK: - Supabase DTO Row

private struct TextPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let tags: [String]?
    let preview_badge: String?
    let config: TextConfiguration
    let is_system: Bool?

    init(from preset: TextPreset) {
        self.id = preset.id
        self.name = preset.name
        self.description = preset.description
        self.category = preset.category.rawValue
        var mergedTags = preset.tags
        if let metaTag = preset.community.encodeToTag() {
            mergedTags.append(metaTag)
        }
        self.tags = mergedTags
        self.preview_badge = preset.previewBadge
        self.config = preset.config
        self.is_system = preset.isSystem
    }

    func toPreset() -> TextPreset {
        let cat = TextTemplateCategory(rawValue: category) ?? .trending
        let sys = is_system ?? false
        let (cleanTags, communityMeta) = CommunityMetadata.extract(from: tags, isSystem: sys)
        let builtIn = TextPreset.templates.first(where: { $0.id == id })
        var resolvedConfig = config
        if let builtIn, resolvedConfig.animation.isDefault, !builtIn.config.animation.isDefault {
            resolvedConfig.animation = builtIn.config.animation
        }
        return TextPreset(
            id: id,
            name: name,
            description: description ?? "",
            category: cat,
            tags: cleanTags,
            defaultDuration: builtIn?.defaultDuration ?? 4.0,
            previewBadge: preview_badge ?? builtIn?.previewBadge,
            previewBackgroundHex: builtIn?.previewBackgroundHex ?? "#18181B",
            config: resolvedConfig,
            isSystem: sys,
            community: communityMeta
        )
    }
}

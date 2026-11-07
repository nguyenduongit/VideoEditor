import Foundation
import Domain
import Supabase

/// Hiện thực kho lưu trữ mẫu hiệu ứng thị giác (Effect Presets) qua Supabase Database và Cache RAM.
/// Áp dụng cơ chế Offline-First / Stale-While-Revalidate (SWR) để đảm bảo độ mượt 0ms.
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseEffectPresetRepository: EffectPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "effect_presets"
    private let templateLoader: EffectTemplateLoader

    public init(
        client: SupabaseClient? = SupabaseConfig.makeClient(),
        templateLoader: EffectTemplateLoader = EffectTemplateLoader()
    ) {
        self.client = client
        self.templateLoader = templateLoader
    }

    public func fetchPresets() async throws -> [EffectPreset] {
        guard let client else {
            return templateLoader.loadAllTemplates()
        }

        do {
            let rows: [EffectPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            templateLoader.setInMemoryTemplates(fetched)
            return templateLoader.loadAllTemplates()
        } catch {
            // Mạng lỗi hoặc bảng chưa khởi tạo: An toàn fallback về cache RAM + 5 mẫu hệ thống
            return templateLoader.loadAllTemplates()
        }
    }

    public func savePreset(_ preset: EffectPreset) async throws {
        // 1. Lưu ngay vào RAM cache để giao diện phản hồi tức thì 0ms
        templateLoader.updateInMemoryPreset(preset)

        // 2. Đồng bộ lên Supabase DB (nếu cấu hình trực tuyến khả dụng)
        if let client {
            let row = EffectPresetRow(from: preset)
            do {
                try await client
                    .from(tableName)
                    .upsert(row)
                    .execute()
            } catch {
                // Nếu lỗi kết nối tạm thời thì thử lại sau 300ms; nếu bảng chưa tạo thì vẫn giữ trên RAM cache
                let ns = error as NSError
                if ns.domain == NSURLErrorDomain && (ns.code == NSURLErrorNetworkConnectionLost || ns.code == NSURLErrorTimedOut) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    _ = try? await client
                        .from(tableName)
                        .upsert(row)
                        .execute()
                }
            }
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    public func deletePreset(id: String) async throws {
        // 1. Xóa khỏi RAM cache
        templateLoader.removeInMemoryPreset(id: id)

        // 2. Xóa trên Supabase DB
        if let client {
            _ = try? await client
                .from(tableName)
                .delete()
                .eq("id", value: id)
                .execute()
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    /// Khởi tạo/cập nhật bộ sưu tập Gói Sáng Tạo Mở bằng Upsert an toàn (bảo toàn 100% gói cộng đồng).
    public func seedSystemCatalogSafely(preserving existingUserPresets: [EffectPreset] = []) async throws {
        let catalog = EffectPreset.systemTemplates
        let userOnly = existingUserPresets.filter { !$0.isSystem }
        templateLoader.setInMemoryTemplates(catalog + userOnly)

        if let client {
            let rows = catalog.map { EffectPresetRow(from: $0) }
            try await client
                .from(tableName)
                .upsert(rows)
                .execute()
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }
}

// MARK: - Supabase DTO Row

private struct EffectPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let tags: [String]?
    let preview_badge: String?
    let config: EffectConfiguration
    let is_system: Bool?

    init(from preset: EffectPreset) {
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

    func toPreset() -> EffectPreset {
        let cat = EffectTemplateCategory(rawValue: category) ?? .lightTransition
        let sys = is_system ?? false
        let (cleanTags, communityMeta) = CommunityMetadata.extract(from: tags, isSystem: sys)
        return EffectPreset(
            id: id,
            name: name,
            description: description ?? "",
            category: cat,
            tags: cleanTags,
            previewBadge: preview_badge,
            config: config,
            isSystem: sys,
            community: communityMeta
        )
    }
}


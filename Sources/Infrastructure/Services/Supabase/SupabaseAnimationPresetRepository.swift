import Foundation
import Domain
import Supabase

/// Hiện thực kho lưu trữ gói hoạt ảnh sáng tạo mở (Animation Presets) qua Supabase Database và Cache RAM.
/// Áp dụng cơ chế Offline-First / Stale-While-Revalidate (SWR) để đảm bảo độ mượt 0ms.
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseAnimationPresetRepository: AnimationPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "animation_presets"
    private let templateLoader: AnimationTemplateLoader

    public init(
        client: SupabaseClient? = SupabaseConfig.makeClient(),
        templateLoader: AnimationTemplateLoader = AnimationTemplateLoader()
    ) {
        self.client = client
        self.templateLoader = templateLoader
    }

    public func fetchPresets() async throws -> [AnimationPreset] {
        guard let client else {
            return templateLoader.loadAllTemplates()
        }

        do {
            let rows: [AnimationPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            templateLoader.setInMemoryTemplates(fetched)
            return templateLoader.loadAllTemplates()
        } catch {
            // Mạng lỗi hoặc bảng chưa khởi tạo: An toàn fallback về cache RAM + 15 mẫu hệ thống
            return templateLoader.loadAllTemplates()
        }
    }

    public func savePreset(_ preset: AnimationPreset) async throws {
        templateLoader.updateInMemoryPreset(preset)

        if let client {
            let row = AnimationPresetRow(from: preset)
            do {
                try await client
                    .from(tableName)
                    .upsert(row)
                    .execute()
            } catch {
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
        templateLoader.removeInMemoryPreset(id: id)

        if let client {
            _ = try? await client
                .from(tableName)
                .delete()
                .eq("id", value: id)
                .execute()
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }

    /// Khởi tạo/cập nhật 15 Gói Animation Sáng Tạo Mở bằng Upsert an toàn (bảo toàn 100% gói cộng đồng).
    public func seedSystemCatalogSafely(preserving existingUserPresets: [AnimationPreset] = []) async throws {
        let catalog = AnimationPreset.systemTemplates
        let userOnly = existingUserPresets.filter { !$0.isSystem }
        templateLoader.setInMemoryTemplates(catalog + userOnly)

        if let client {
            let rows = catalog.map { AnimationPresetRow(from: $0) }
            try await client
                .from(tableName)
                .upsert(rows)
                .execute()
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }
}

// MARK: - Supabase DTO Row

private struct AnimationPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let tags: [String]?
    let preview_badge: String?
    let config: CreativeAnimationManifest
    let is_system: Bool?

    init(from preset: AnimationPreset) {
        self.id = preset.id
        self.name = preset.name
        self.description = preset.description
        self.category = preset.phase.rawValue
        var mergedTags = preset.tags
        if let metaTag = preset.community.encodeToTag() {
            mergedTags.append(metaTag)
        }
        self.tags = mergedTags
        self.preview_badge = preset.previewBadge
        self.config = preset.manifest
        self.is_system = preset.isSystem
    }

    func toPreset() -> AnimationPreset {
        let phase = AnimationPhaseCategory(rawValue: category) ?? .inAnimation
        let sys = is_system ?? false
        let (cleanTags, communityMeta) = CommunityMetadata.extract(from: tags, isSystem: sys)
        return AnimationPreset(
            id: id,
            name: name,
            description: description ?? "",
            phase: phase,
            tags: cleanTags,
            previewBadge: preview_badge,
            manifest: config,
            isSystem: sys,
            community: communityMeta
        )
    }
}


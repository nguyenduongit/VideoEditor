import Foundation
import OSLog
import Domain
import Supabase

private let transitionRepoLogger = Logger(subsystem: "VideoEditor", category: "SupabaseTransitionPresetRepository")

/// Hiện thực kho lưu trữ mẫu Chuyển cảnh (`TransitionPreset` — 8 họ GPU Kernel + Custom MSL + Parameters)
/// qua Supabase Database (`transition_presets`).
/// Áp dụng cơ chế Offline-First / Stale-While-Revalidate (SWR) và Upsert an toàn (bảo toàn 100% mẫu người dùng).
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseTransitionPresetRepository: TransitionPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "transition_presets"
    private let templateLoader: TransitionTemplateLoader

    public init(
        client: SupabaseClient? = SupabaseConfig.makeClient(),
        templateLoader: TransitionTemplateLoader = TransitionTemplateLoader()
    ) {
        self.client = client
        self.templateLoader = templateLoader
    }

    public func fetchPresets() async throws -> [TransitionPreset] {
        guard let client else {
            return templateLoader.loadAllTemplates()
        }

        do {
            let rows: [TransitionPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            let systemIDs = Set(TransitionPreset.builtInCatalog.map(\.id))
            let fetchedSystemIDs = Set(fetched.filter(\.isSystem).map(\.id))

            if !systemIDs.isSubset(of: fetchedSystemIDs) {
                do {
                    try await seedSystemCatalogSafely(preserving: fetched)
                } catch {
                    transitionRepoLogger.warning("Seed an toàn transition_presets bỏ qua do lỗi mạng/bảng: \(error.localizedDescription)")
                    templateLoader.setInMemoryTemplates(fetched)
                }
                return templateLoader.loadAllTemplates()
            }

            templateLoader.setInMemoryTemplates(fetched)
            return templateLoader.loadAllTemplates()
        } catch {
            transitionRepoLogger.warning("Không thể tải transition_presets từ Supabase, dùng cache nội bộ: \(error.localizedDescription)")
            return templateLoader.loadAllTemplates()
        }
    }

    public func savePreset(_ preset: TransitionPreset) async throws {
        templateLoader.updateInMemoryPreset(preset)

        guard let client else { return }
        let row = TransitionPresetRow(from: preset)
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

    /// Khởi tạo/cập nhật các mẫu Chuyển cảnh hệ thống bằng Upsert không phá hủy (bảo toàn 100% mẫu người dùng).
    public func seedSystemCatalogSafely(preserving existingUserPresets: [TransitionPreset] = []) async throws {
        let systemCatalog = TransitionPreset.builtInCatalog
        let userOnly = existingUserPresets.filter { !$0.isSystem }
        templateLoader.setInMemoryTemplates(systemCatalog + userOnly)

        if let client {
            let rows = systemCatalog.map { TransitionPresetRow(from: $0) }
            try await client
                .from(tableName)
                .upsert(rows)
                .execute()
        }

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }
}

// MARK: - Supabase DTO Row

private struct TransitionPresetPayload: Codable, Sendable {
    let defaultEasing: TransitionEasing
    let parameters: [CustomParameterDescriptor]
    let parameterValues: [String: Double]
    let customMetalSource: String?
    let previewBadge: String?
}

private struct TransitionPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let shader_type: String
    let tags: [String]?
    let default_duration: Double?
    let icon_name: String?
    let config: TransitionPresetPayload
    let is_system: Bool?

    init(from preset: TransitionPreset) {
        self.id = preset.id
        self.name = preset.name
        self.description = preset.description
        self.category = preset.category.rawValue
        self.shader_type = preset.shaderType.rawValue
        var mergedTags = preset.tags
        if let metaTag = preset.community.encodeToTag() {
            mergedTags.append(metaTag)
        }
        self.tags = mergedTags
        self.default_duration = preset.defaultDuration
        self.icon_name = preset.iconName
        self.config = TransitionPresetPayload(
            defaultEasing: preset.defaultEasing,
            parameters: preset.parameters,
            parameterValues: preset.parameterValues,
            customMetalSource: preset.customMetalSource,
            previewBadge: preset.previewBadge
        )
        self.is_system = preset.isSystem
    }

    func toPreset() -> TransitionPreset {
        let cat = TransitionCategory(rawValue: category) ?? .basic
        let shader = TransitionShaderType(rawValue: shader_type) ?? .dissolve
        let sys = is_system ?? false
        let (cleanTags, communityMeta) = CommunityMetadata.extract(from: tags, isSystem: sys)
        return TransitionPreset(
            id: id,
            name: name,
            description: description ?? "",
            category: cat,
            tags: cleanTags,
            defaultDuration: default_duration ?? 0.5,
            shaderType: shader,
            defaultEasing: config.defaultEasing,
            iconName: icon_name ?? "arrow.left.arrow.right",
            previewBadge: config.previewBadge,
            parameters: config.parameters,
            parameterValues: config.parameterValues,
            customMetalSource: config.customMetalSource,
            isSystem: sys,
            community: communityMeta
        )
    }
}

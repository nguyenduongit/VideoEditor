import Foundation
import Domain
import Supabase

/// Hiện thực kho lưu trữ mẫu màu (Adjustment Presets) qua Supabase Database và Cache cục bộ.
/// Áp dụng cơ chế Offline-First / Stale-While-Revalidate (SWR) để đảm bảo độ mượt 0ms.
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseAdjustmentPresetRepository: AdjustmentPresetRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient?
    private let tableName = "adjustment_presets"

    public init(client: SupabaseClient? = SupabaseConfig.makeClient()) {
        self.client = client
    }

    public func fetchPresets() async throws -> [AdjustmentPreset] {
        guard let client else {
            return AdjustmentTemplateLoader.shared.loadAllTemplates()
        }

        do {
            let rows: [AdjustmentPresetRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toPreset() }
            // Supabase là Nguồn Chân Lý Duy Nhất (Single Source of Truth)
            AdjustmentTemplateLoader.shared.setInMemoryTemplates(fetched)
            return fetched
        } catch {
            // Mạng lỗi hoặc timeout: An toàn fallback về cache RAM hoặc mẫu mặc định
            return AdjustmentTemplateLoader.shared.loadAllTemplates()
        }
    }

    public func savePreset(_ preset: AdjustmentPreset) async throws {
        // 1. Lưu ngay vào RAM cache để giao diện phản hồi tức thì
        AdjustmentTemplateLoader.shared.updateInMemoryPreset(preset)

        // 2. Đồng bộ lên Supabase DB
        guard let client else { return }
        let row = AdjustmentPresetRow(from: preset)
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
        // 1. Xóa khỏi RAM cache
        AdjustmentTemplateLoader.shared.removeInMemoryPreset(id: id)

        // 2. Xóa trên Supabase DB
        guard let client else { return }
        try await client
            .from(tableName)
            .delete()
            .eq("id", value: id)
            .execute()

        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
    }
}

// MARK: - Supabase DTO Row

private struct AdjustmentPresetRow: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let tags: [String]?
    let preview_badge: String?
    let preview_colors_hex: [String]?
    let config: AdjustmentConfiguration
    let is_system: Bool?

    init(from preset: AdjustmentPreset) {
        self.id = preset.id
        self.name = preset.name
        self.description = preset.description
        self.category = preset.category.rawValue
        self.tags = preset.tags
        self.preview_badge = preset.previewBadge
        self.preview_colors_hex = preset.previewColorsHex
        self.config = preset.config
        self.is_system = preset.isSystem
    }

    func toPreset() -> AdjustmentPreset {
        let cat = AdjustmentTemplateCategory(rawValue: category) ?? .cinematic
        return AdjustmentPreset(
            id: id,
            name: name,
            description: description ?? "",
            category: cat,
            tags: tags ?? [],
            previewBadge: preview_badge,
            previewColorsHex: preview_colors_hex ?? ["#27272A", "#52525B"],
            config: config,
            isSystem: is_system ?? false
        )
    }
}

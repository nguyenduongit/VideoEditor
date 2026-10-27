import Testing
import Foundation
import Domain
import Infrastructure

@Suite("Supabase Preset Repository Tests")
struct SupabasePresetRepositoryTests {

    @Test("Adjustment Preset Repository saves, fetches and deletes custom presets")
    func testAdjustmentPresetRepoSaveAndFetch() async throws {
        let repo = SupabaseAdjustmentPresetRepository()

        let testID = "test_custom_color_preset_\(UUID().uuidString.prefix(8))"
        var customConfig = AdjustmentConfiguration()
        customConfig.basic.contrast = 25
        customConfig.basic.exposure = 0.5

        let preset = AdjustmentPreset(
            id: testID,
            name: "Màu Test Rực Rỡ",
            description: "Preset thử nghiệm cho Supabase",
            category: .cinematic,
            tags: ["test", "vibrant"],
            previewColorsHex: ["#FF5500", "#002244"],
            config: customConfig,
            isSystem: false
        )

        // 1. Lưu preset
        try await repo.savePreset(preset)

        // 2. Tải danh sách presets
        let allPresets = try await repo.fetchPresets()
        let found = allPresets.first(where: { $0.id == testID })
        #expect(found != nil)
        #expect(found?.name == "Màu Test Rực Rỡ")
        #expect(found?.config.basic.contrast == 25)
        #expect(found?.isSystem == false)

        // 3. Xóa preset
        try await repo.deletePreset(id: testID)
        let reloaded = try await repo.fetchPresets()
        #expect(reloaded.contains(where: { $0.id == testID }) == false)
    }

    @Test("Text Preset Repository saves, fetches and deletes custom presets")
    func testTextPresetRepoSaveAndFetch() async throws {
        let repo = SupabaseTextPresetRepository()

        let testID = "test_custom_text_preset_\(UUID().uuidString.prefix(8))"
        var customConfig = TextConfiguration()
        customConfig.content = "TIÊU ĐỀ PRO"
        customConfig.fontName = "UVN Bay Buom"
        customConfig.fontSize = 62.0
        customConfig.hasBackground = true

        let preset = TextPreset(
            id: testID,
            name: "Tiêu Đề Lãng Mạn",
            description: "Chữ nghệ thuật Bay Bướm",
            category: .trending,
            tags: ["test", "romantic"],
            config: customConfig,
            isSystem: false
        )

        // 1. Lưu preset
        try await repo.savePreset(preset)

        // 2. Tải danh sách presets
        let allPresets = try await repo.fetchPresets()
        let found = allPresets.first(where: { $0.id == testID })
        #expect(found != nil)
        #expect(found?.name == "Tiêu Đề Lãng Mạn")
        #expect(found?.config.fontName == "UVN Bay Buom")
        #expect(found?.isSystem == false)

        // 3. Xóa preset
        try await repo.deletePreset(id: testID)
        let reloaded = try await repo.fetchPresets()
        #expect(reloaded.contains(where: { $0.id == testID }) == false)
    }

    @Test("Built-in templates are flagged as isSystem = true")
    func testBuiltInTemplatesAreFlaggedAsSystem() {
        let defaultAdjustment = AdjustmentPreset.default
        #expect(defaultAdjustment.isSystem == true)

        let defaultText = TextPreset.default
        #expect(defaultText.isSystem == true)
    }
}

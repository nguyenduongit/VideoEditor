import Testing
import Foundation
import Domain
import Infrastructure

@Suite("Supabase Preset Repository Safe Upsert & Offline SWR Tests", .serialized)
struct SupabasePresetRepositoryTests {

    @Test("Safe seeding preserves custom user presets while populating all built-in creative catalogs")
    func testSafeSeedPreservesUserPresetsAcrossRepositories() async throws {
        let effectRepo = SupabaseEffectPresetRepository(client: nil)
        let adjustmentRepo = SupabaseAdjustmentPresetRepository(client: nil)
        let textRepo = SupabaseTextPresetRepository(client: nil)
        let animationRepo = SupabaseAnimationPresetRepository(client: nil)
        let stickerRepo = SupabaseStickerPresetRepository(client: nil)
        let transitionRepo = SupabaseTransitionPresetRepository(client: nil)

        let userTextPreset = TextPreset(
            id: "community_user_saved_1",
            name: "Mẫu Cộng Đồng Đã Lưu",
            description: "Không được xóa khi seed lại mẫu hệ thống",
            category: .vlog,
            config: TextConfiguration(content: "USER PRESET"),
            isSystem: false
        )

        try await effectRepo.seedSystemCatalogSafely()
        try await adjustmentRepo.seedSystemCatalogSafely()
        try await textRepo.seedSystemCatalogSafely(preserving: [userTextPreset])
        try await animationRepo.seedSystemCatalogSafely()
        try await stickerRepo.seedSystemCatalogSafely()
        try await transitionRepo.seedSystemCatalogSafely()

        let stickers = try await stickerRepo.fetchPresets()
        #expect(!stickers.isEmpty)
        let transitions = try await transitionRepo.fetchPresets()
        #expect(transitions.count >= 9)

        let animations = try await animationRepo.fetchPresets()
        #expect(animations.count >= 15)
        #expect(animations.filter { $0.phase == .inAnimation }.count >= 5)
        #expect(animations.filter { $0.phase == .outAnimation }.count >= 5)
        #expect(animations.filter { $0.phase == .loopAnimation }.count >= 5)

        let effects = try await effectRepo.fetchPresets()
        #expect(effects.count == 9)
        #expect(effects.contains(where: { $0.id == "creative_fx_rgb_glitch" }))
        #expect(effects.contains(where: { $0.id == "creative_fx_vhs_retro" }))

        let adjustments = try await adjustmentRepo.fetchPresets()
        #expect(adjustments.count == 7)
        #expect(adjustments.contains(where: { $0.id == "creative_color_kodak_2383" }))

        let texts = try await textRepo.fetchPresets()
        #expect(texts.count == 6) // 1 default + 4 unified creative + 1 preserved user preset
        #expect(texts.contains(where: { $0.id == "template_neon_cyber_glow" }))
        #expect(texts.contains(where: { $0.id == "template_vlog_badge_banner" }))
        #expect(texts.contains(where: { $0.id == "community_user_saved_1" }))
    }

    @Test("Adjustment Preset Repository saves, fetches and deletes custom presets deterministically")
    func testAdjustmentPresetRepoSaveAndFetch() async throws {
        let repo = SupabaseAdjustmentPresetRepository(client: nil)

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

        try await repo.savePreset(preset)

        let allPresets = try await repo.fetchPresets()
        let found = allPresets.first(where: { $0.id == testID })
        #expect(found != nil)
        #expect(found?.name == "Màu Test Rực Rỡ")
        #expect(found?.config.basic.contrast == 25)
        #expect(found?.isSystem == false)

        try await repo.deletePreset(id: testID)
        let reloaded = try await repo.fetchPresets()
        #expect(reloaded.contains(where: { $0.id == testID }) == false)
    }

    @Test("Text Preset Repository saves, fetches and deletes custom presets deterministically")
    func testTextPresetRepoSaveAndFetch() async throws {
        let loader = TextTemplateLoader()
        let repo = SupabaseTextPresetRepository(client: nil, templateLoader: loader)

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

        try await repo.savePreset(preset)

        let allPresets = try await repo.fetchPresets()
        let found = allPresets.first(where: { $0.id == testID })
        #expect(found != nil)
        #expect(found?.name == "Tiêu Đề Lãng Mạn")
        #expect(found?.config.fontName == "UVN Bay Buom")
        #expect(found?.isSystem == false)

        try await repo.deletePreset(id: testID)
        let reloaded = try await repo.fetchPresets()
        #expect(reloaded.contains(where: { $0.id == testID }) == false)
    }

    @Test("Built-in templates are flagged as isSystem = true")
    func testBuiltInTemplatesAreFlaggedAsSystem() {
        #expect(AdjustmentPreset.default.isSystem == true)
        #expect(TextPreset.default.isSystem == true)
        let allCreativeAreSystem = AdjustmentPreset.creativeCatalog.allSatisfy { $0.isSystem }
            && TextPreset.creativeCatalog.allSatisfy { $0.isSystem }
            && EffectPreset.systemTemplates.allSatisfy { $0.isSystem }
            && AnimationPreset.systemTemplates.allSatisfy { $0.isSystem }
        #expect(allCreativeAreSystem == true)
    }

    @Test("Seed live animation presets to Supabase if configured")
    func testSeedLiveAnimationPresetsToSupabase() async throws {
        guard let client = SupabaseConfig.makeClient() else { return }
        let repo = SupabaseAnimationPresetRepository(client: client)
        let presets = try await repo.fetchPresets()
        #expect(presets.count >= 49)
    }
}

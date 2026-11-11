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
        #expect(transitions.count == 83)
        #expect(transitions.contains(where: { $0.id == "dissolve_default" }))
        #expect(transitions.contains(where: { $0.id == "trans_basic_white_flash" }))
        #expect(transitions.contains(where: { $0.id == "trans_light_white_flash" }))

        let animations = try await animationRepo.fetchPresets()
        #expect(animations.count >= 15)
        #expect(animations.filter { $0.phase == .inAnimation }.count >= 5)
        #expect(animations.filter { $0.phase == .outAnimation }.count >= 5)
        #expect(animations.filter { $0.phase == .loopAnimation }.count >= 5)

        let effects = try await effectRepo.fetchPresets()
        #expect(effects.count == 1)
        #expect(effects.contains(where: { $0.id == "creative_fx_rgb_glitch" }))

        let adjustments = try await adjustmentRepo.fetchPresets()
        #expect(adjustments.count == 2)
        #expect(adjustments.contains(where: { $0.id == "creative_color_kodak_2383" }))

        let texts = try await textRepo.fetchPresets()
        #expect(texts.count == 2) // 1 default + 1 preserved user preset
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

    @Test("Seed and synchronize all 83 live transition presets to Supabase if configured")
    func testSeedLiveTransitionPresetsToSupabase() async throws {
        guard let client = SupabaseConfig.makeClient() else { return }
        let repo = SupabaseTransitionPresetRepository(client: client)
        let presets = try await repo.fetchPresets()
        #expect(presets.count >= 83)
        let whiteFlashBasic = presets.first(where: { $0.id == "trans_basic_white_flash" })
        #expect(whiteFlashBasic?.parameterValues["mode"] == 6.0)
        let whiteFlashLight = presets.first(where: { $0.id == "trans_light_white_flash" })
        #expect(whiteFlashLight?.parameterValues["warmth"] == 0.0)
        #expect(whiteFlashLight?.parameterValues["mode"] == 1.0)
    }

    @Test("Audio Preset Repository saves, fetches and deletes audio presets deterministically")
    func testAudioPresetRepositoryOperations() async throws {
        let repo = SupabaseAudioPresetRepository(client: nil)
        let initial = try await repo.fetchPresets()
        #expect(!initial.isEmpty)
        #expect(initial.contains(where: { $0.id == "audio_bgm_sunny_day" }))
        #expect(initial.contains(where: { $0.id == "audio_dance_beat" }))
        let danceBeat = initial.first(where: { $0.id == "audio_dance_beat" })
        #expect(danceBeat?.category == "Dance Beat")
        #expect(danceBeat?.durationFormatted == "8-Beat")

        let custom = AudioPreset(
            id: "audio_custom_rock",
            name: "Rock Anthem",
            category: "Music",
            duration: 180,
            audioURL: URL(string: "https://example.com/audio/rock.mp3"),
            icon: "guitars.fill",
            isSystem: false
        )
        try await repo.savePreset(custom)

        let updated = try await repo.fetchPresets()
        #expect(updated.contains(where: { $0.id == "audio_custom_rock" }))
        let found = updated.first(where: { $0.id == "audio_custom_rock" })
        #expect(found?.durationFormatted == "03:00")

        try await repo.deletePreset(id: "audio_custom_rock")
        let afterDelete = try await repo.fetchPresets()
        #expect(!afterDelete.contains(where: { $0.id == "audio_custom_rock" }))
    }

    @Test("Stock Media Repository saves, fetches and deletes media items deterministically")
    func testStockMediaRepositoryOperations() async throws {
        let repo = SupabaseStockMediaRepository(client: nil)
        let initial = try await repo.fetchStockItems()
        #expect(!initial.isEmpty)
        #expect(initial.contains(where: { $0.id == "stock_video_intro" }))

        let customItem = StockMediaItem(
            id: "stock_custom_drone",
            name: "Drone Mountains",
            category: "Stock Videos",
            type: .video,
            mediaURL: URL(string: "https://example.com/stock/mountains.mp4")!,
            icon: "mountain.2"
        )
        try await repo.saveStockItem(customItem)

        let updated = try await repo.fetchStockItems()
        #expect(updated.contains(where: { $0.id == "stock_custom_drone" }))

        try await repo.deleteStockItem(id: "stock_custom_drone")
        let afterDelete = try await repo.fetchStockItems()
        #expect(!afterDelete.contains(where: { $0.id == "stock_custom_drone" }))
    }

    @Test("Favorite Repository manages and synchronizes tab favorites deterministically")
    func testFavoriteRepositoryOperations() async throws {
        let repo = SupabaseFavoriteRepository(client: nil, customClientID: "test_device_unit_tests")
        let tab = "audio"

        try await repo.addFavorite(id: "item_fav_1", for: tab)
        try await repo.addFavorite(id: "item_fav_2", for: tab)

        let favorites = try await repo.fetchFavorites(for: tab)
        #expect(favorites.contains("item_fav_1"))
        #expect(favorites.contains("item_fav_2"))

        try await repo.removeFavorite(id: "item_fav_1", for: tab)
        let afterRemove = try await repo.fetchFavorites(for: tab)
        #expect(!afterRemove.contains("item_fav_1"))
        #expect(afterRemove.contains("item_fav_2"))
    }
}

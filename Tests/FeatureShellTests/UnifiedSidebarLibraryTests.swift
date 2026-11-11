import Testing
import Foundation
import SwiftUI
import DesignSystem
@testable import Domain
@testable import FeatureShell

@Suite("UnifiedSidebarLibraryTests")
@MainActor
struct UnifiedSidebarLibraryTests {

    @Test("SidebarFavoriteManager successfully stores, toggles, and retrieves favorites")
    func testSidebarFavoriteManagerAddRemoveToggle() {
        let defaults = UserDefaults(suiteName: "Test_SidebarFavoriteManager_\(UUID().uuidString)")!
        let manager = SidebarFavoriteManager(userDefaults: defaults)

        #expect(!manager.isFavorite(id: "preset_1", for: "text"))

        // Add
        manager.addFavorite(id: "preset_1", for: "text")
        #expect(manager.isFavorite(id: "preset_1", for: "text"))
        #expect(manager.favorites(for: "text").contains("preset_1"))

        // Toggle to off
        manager.toggleFavorite(id: "preset_1", for: "text")
        #expect(!manager.isFavorite(id: "preset_1", for: "text"))

        // Toggle to on
        manager.toggleFavorite(id: "preset_1", for: "text")
        #expect(manager.isFavorite(id: "preset_1", for: "text"))

        // Remove
        manager.removeFavorite(id: "preset_1", for: "text")
        #expect(!manager.isFavorite(id: "preset_1", for: "text"))

        // Independent across tabs
        manager.addFavorite(id: "item_A", for: "media")
        manager.addFavorite(id: "item_B", for: "audio")
        #expect(manager.isFavorite(id: "item_A", for: "media"))
        #expect(!manager.isFavorite(id: "item_A", for: "audio"))
        #expect(manager.isFavorite(id: "item_B", for: "audio"))
    }

    @Test("LibraryScaffoldView constants and categories conform to unified design")
    func testLibraryScaffoldFavoritesConstant() {
        #expect(SidebarFavoriteManager.favoritesCategory == "favorites")
        #expect(LibraryScaffoldView<EmptyView>.divider == "---")
    }

    @Test("TextLibraryView has Default category and default text identifier")
    func testTextLibraryDefaultCategory() {
        #expect(TextLibraryView.defaultCategory == "Default")
        #expect(TextLibraryView.defaultPresetID == "text_default_preset")

        let vm = TimelineViewModel()
        #expect(vm.layers.isEmpty)
        vm.addTextClip(named: "Default Text", config: TextConfiguration(), durationSeconds: 5.0)
        #expect(!vm.layers.isEmpty)
        let addedClip = vm.layers.flatMap(\.clips).first
        #expect(addedClip != nil)
        #expect(addedClip?.kind == .text)
        #expect(addedClip?.timeRange.duration.seconds == 5.0)
    }

    @Test("Sidebar tab categories exclude 'All' and maintain assignable cases")
    func testCategoriesDoNotContainAllAcrossTabs() {
        // Text
        let textCats = TextTemplateCategory.assignableCases
        #expect(!textCats.contains(.all))
        #expect(textCats.count >= 3)

        // Effect
        let effectCats = EffectTemplateCategory.assignableCases
        #expect(!effectCats.contains(.all))
        #expect(effectCats.count >= 4)

        // Transition
        let transCats = TransitionCategory.assignableCases
        #expect(!transCats.contains(.all))
        #expect(transCats.count == 8)

        // Sticker
        let stickerCats = StickerCategory.assignableCases
        #expect(!stickerCats.contains(.all))
        #expect(stickerCats.count >= 4)
    }

    @Test("UnifiedLibraryCardItemView instantiates cleanly with actions and view body")
    func testUnifiedLibraryCardItemViewRendersCleanly() {
        var didAdd = false
        var didFavorite = false
        var didSelect = false

        let card = UnifiedLibraryCardItemView(
            title: "Test Card",
            isFavorite: true,
            isSelected: true,
            onSelect: { didSelect = true },
            onAdd: { didAdd = true },
            onToggleFavorite: { didFavorite = true }
        ) {
            Color.blue
        }

        _ = card.body
        #expect(!didAdd)
        #expect(!didFavorite)
        #expect(!didSelect)
    }

    @Test("DSRoundedStarAsset successfully decodes custom rounded star icon")
    func testDSRoundedStarAssetLoads() {
        let image = DSRoundedStarAsset.image
        #expect(image != nil)
        if let image {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }

    @Test("MediaAssetItemView maintains no-favorites and hover add button capability")
    func testMediaAssetItemViewBehavior() {
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample.mp4"), name: "sample.mp4", type: .video)
        var added = false
        var selected = false
        var deleted = false

        let itemView = MediaAssetItemView(
            asset: asset,
            isSelected: false,
            onSelect: { _ in selected = true },
            onAddToTimeline: { added = true },
            onDelete: { deleted = true }
        ) {
            Color.red
        }

        _ = itemView.body
        #expect(!added)
        #expect(!selected)
        #expect(!deleted)
    }

    @Test("AudioSidebarViewModel provides Dance Beat Counter and routes add action to TimelineViewModel")
    func testAudioSidebarViewModelAndDanceBeatIntegration() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        let audioVM = AudioSidebarViewModel(timelineViewModel: timelineVM)

        #expect(audioVM.categories.contains("Dance Beat"))

        // Default category is Music
        #expect(audioVM.selectedCategory == "Music")
        #expect(audioVM.filteredItems.contains(where: { $0.id == "audio_bgm_sunny_day" }))

        // Switching to Dance Beat category shows audio_dance_beat
        audioVM.selectedCategory = "Dance Beat"
        #expect(audioVM.filteredItems.count == 1)
        let item = audioVM.filteredItems[0]
        #expect(item.id == "audio_dance_beat")
        #expect(item.name == "Dance Beat Counter")
        #expect(item.icon == "figure.dance")
        #expect(item.durationFormatted == "8-Beat")

        // Searching "dance" finds the item
        audioVM.selectedCategory = "Music"
        audioVM.searchQuery = "dance"
        #expect(audioVM.filteredItems.contains(where: { $0.id == "audio_dance_beat" }))
        audioVM.searchQuery = ""

        // Adding preset adds a dance beat counter clip to timeline
        #expect(timelineVM.layers.isEmpty)
        audioVM.addPresetToTimeline(item)
        #expect(!timelineVM.layers.isEmpty)
        let addedClip = timelineVM.layers.flatMap(\.clips).first
        #expect(addedClip != nil)
        #expect(addedClip?.properties["isBeatCounter"]?.asBool == true)
        #expect(addedClip?.kind == .audio)
    }
}

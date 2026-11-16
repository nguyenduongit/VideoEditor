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

    @Test("AdjustmentLibraryView has Default category and default adjustment identifier")
    func testAdjustmentLibraryDefaultCategory() {
        #expect(AdjustmentLibraryView.defaultCategory == "Default")
        #expect(AdjustmentLibraryView.defaultPresetID == "adjustment_default_preset")

        let vm = TimelineViewModel()
        #expect(vm.layers.isEmpty)
        let libraryVM = AdjustmentLibraryViewModel(timelineViewModel: vm)
        libraryVM.addDefaultPresetToTimeline()
        #expect(!vm.layers.isEmpty)
        let addedClip = vm.layers.flatMap(\.clips).first
        #expect(addedClip != nil)
        #expect(addedClip?.kind == .adjustment)
        #expect(addedClip?.name == "Adjustment Layer")
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
        ) { _ in
            Color.blue
        }

        _ = card.body
        #expect(!didAdd)
        #expect(!didFavorite)
        #expect(!didSelect)
    }

    @Test("TextAnimatedThumbnailView instantiates and renders cleanly in static and hovered states")
    func testTextAnimatedThumbnailViewRenders() {
        let preset = TextPreset.neonCyberGlow
        let staticView = TextAnimatedThumbnailView(preset: preset, isHovered: false)
        _ = staticView.body

        let hoveredView = TextAnimatedThumbnailView(preset: preset, isHovered: true)
        _ = hoveredView.body
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

    @Test("TextAnimatedThumbnail and Evaluator execute In, Loop and Out phases during preview")
    func testTextAnimatedThumbnailThreePhasesExecution() {
        let preset = TextPreset.neonCyberGlow
        let effective = TextThumbnailRenderer.effectiveAnimatedConfig(for: preset)
        #expect(effective.animation.hasInAnimation)
        #expect(effective.animation.hasLoopAnimation)
        #expect(effective.animation.hasOutAnimation)

        let duration = TextThumbnailRenderer.effectiveDuration(for: preset)
        #expect(duration == 4.0)

        let frameIn = TextThumbnailRenderer.renderAnimatedFrame(
            for: preset, localTime: 0.4, duration: duration, targetSize: CGSize(width: 120, height: 120)
        )
        let frameLoop = TextThumbnailRenderer.renderAnimatedFrame(
            for: preset, localTime: 2.0, duration: duration, targetSize: CGSize(width: 120, height: 120)
        )
        let frameOut = TextThumbnailRenderer.renderAnimatedFrame(
            for: preset, localTime: 3.8, duration: duration, targetSize: CGSize(width: 120, height: 120)
        )
        #expect(frameIn != nil)
        #expect(frameLoop != nil)
        #expect(frameOut != nil)

        // Verify TextAnimationScript guarantees .loop even for short durations (<= in+out)
        if let script = TextAnimationScriptRegistry.shared.script(for: "title_wave_float") {
            var scriptAnim = TextAnimationConfiguration()
            scriptAnim.scriptInDuration = 1.0
            scriptAnim.scriptOutDuration = 1.0
            let phaseMid = script.resolvePhase(anim: scriptAnim, localTime: 1.0, duration: 2.0)
            if case .loop = phaseMid {
                #expect(Bool(true))
            } else {
                #expect(Bool(false), "Script phase at midpoint of 2.0s should be .loop, got \(phaseMid)")
            }
        }
    }

    @MainActor
    @Test("Text preset preview and Default Text selection state machine syncs two-way")
    func testTextPresetPreviewAndDefaultSelectionStateMachine() throws {
        let timelineVM = TimelineViewModel()
        let registry = TabRegistry()
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM, initialTabID: .text)
        let textVM = TextLibraryViewModel(timelineViewModel: timelineVM)

        textVM.selectPresetForPreview(.neonCyberGlow)
        #expect(shellVM.activePreviewTextPreset?.id == TextPreset.neonCyberGlow.id)
        #expect(textVM.selectedPresetID == TextPreset.neonCyberGlow.id)

        textVM.selectDefaultPresetForPreview()
        let defaultPreview = try #require(shellVM.activePreviewTextPreset)
        #expect(defaultPreview.id == textVM.defaultPreset.id)
        #expect(textVM.selectedPresetID == textVM.defaultPreset.id)
        #expect(TextThumbnailRenderer.isDefaultStaticPreset(defaultPreview) == true)
        #expect(TextThumbnailRenderer.effectiveAnimatedConfig(for: defaultPreview).animation.isDefault == true)

        shellVM.setPreviewTextPreset(nil)
        #expect(shellVM.activePreviewTextPreset == nil)
        #expect(textVM.selectedPresetID == nil)

        textVM.selectPresetForPreview(.neonCyberGlow)
        textVM.addDefaultPresetToTimeline()
        #expect(shellVM.activePreviewTextPreset == nil)
        #expect(textVM.selectedPresetID == nil)
        #expect(!timelineVM.layers.isEmpty)
    }
}

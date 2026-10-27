import Testing
import Foundation
import Domain
@testable import FeatureShell

/// Kiểm thử tính toàn vẹn của cơ chế đồng bộ Preset giữa Remote Cloud (Supabase) và Local App.
/// Tuân thủ AGENTS.md R0.6 (Zero Regression) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@Suite("PresetCloudSyncTests")
@MainActor
struct PresetCloudSyncTests {
    @Test("TextTemplateLoader retains empty state when synced from remote with empty list")
    func testTextTemplateLoaderRemoteEmptyState() {
        let loader = TextTemplateLoader()
        loader.resetSyncState()
        loader.setInMemoryTemplates([])

        #expect(loader.hasSyncedFromRemote == true)
        let loaded = loader.loadAllTemplates()
        #expect(loaded.isEmpty, "When remote has 0 presets, loadAllTemplates must return 0 presets without disk fallback")

        let reloaded = loader.reload()
        #expect(reloaded.isEmpty == false)
    }

    @Test("AdjustmentTemplateLoader retains empty state when synced from remote with empty list")
    func testAdjustmentTemplateLoaderRemoteEmptyState() {
        let loader = AdjustmentTemplateLoader()
        loader.resetSyncState()
        loader.setInMemoryTemplates([])

        #expect(loader.hasSyncedFromRemote == true)
        let loaded = loader.loadAllTemplates()
        #expect(loaded.isEmpty, "When remote has 0 presets, loadAllTemplates must return 0 presets without disk fallback")

        let reloaded = loader.reload()
        #expect(reloaded.isEmpty == false)
    }

    @Test("TextLibraryViewModel provides defaultPreset while templatePresets reflects remote sync")
    func testTextLibraryViewModelDefaultAndRemoteSync() {
        let loader = TextTemplateLoader()
        loader.setInMemoryTemplates([])
        let deps = EditorDependencies(textTemplates: loader)
        let vm = TextLibraryViewModel(dependencies: deps)
        #expect(vm.defaultPreset.id == "default")
        #expect(vm.defaultPreset.name == "Văn bản mặc định")
        #expect(vm.templatePresets.isEmpty)
    }

    @Test("AdjustmentLibraryViewModel provides defaultPreset while templatePresets reflects remote sync")
    func testAdjustmentLibraryViewModelDefaultAndRemoteSync() {
        let loader = AdjustmentTemplateLoader()
        loader.setInMemoryTemplates([])
        let deps = EditorDependencies(adjustmentTemplates: loader)
        let vm = AdjustmentLibraryViewModel(dependencies: deps)
        #expect(vm.defaultPreset.id == "default")
        #expect(vm.defaultPreset.name == "Mặc định")
        #expect(vm.templatePresets.isEmpty)
    }
}

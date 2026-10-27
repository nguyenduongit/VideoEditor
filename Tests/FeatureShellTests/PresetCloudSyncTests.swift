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
        TextTemplateLoader.shared.resetSyncState()
        TextTemplateLoader.shared.setInMemoryTemplates([])

        #expect(TextTemplateLoader.shared.hasSyncedFromRemote == true)
        let loaded = TextTemplateLoader.shared.loadAllTemplates()
        #expect(loaded.isEmpty, "When remote has 0 presets, loadAllTemplates must return 0 presets without disk fallback")

        // Khi reload() thì khôi phục lại fallback để không ảnh hưởng test khác
        let reloaded = TextTemplateLoader.shared.reload()
        #expect(reloaded.isEmpty == false)
    }

    @Test("AdjustmentTemplateLoader retains empty state when synced from remote with empty list")
    func testAdjustmentTemplateLoaderRemoteEmptyState() {
        AdjustmentTemplateLoader.shared.resetSyncState()
        AdjustmentTemplateLoader.shared.setInMemoryTemplates([])

        #expect(AdjustmentTemplateLoader.shared.hasSyncedFromRemote == true)
        let loaded = AdjustmentTemplateLoader.shared.loadAllTemplates()
        #expect(loaded.isEmpty, "When remote has 0 presets, loadAllTemplates must return 0 presets without disk fallback")

        // Khi reload() thì khôi phục lại fallback để không ảnh hưởng test khác
        let reloaded = AdjustmentTemplateLoader.shared.reload()
        #expect(reloaded.isEmpty == false)
    }

    @Test("TextLibraryViewModel provides defaultPreset while templatePresets reflects remote sync")
    func testTextLibraryViewModelDefaultAndRemoteSync() {
        TextTemplateLoader.shared.setInMemoryTemplates([])
        let vm = TextLibraryViewModel()
        #expect(vm.defaultPreset.id == "default")
        #expect(vm.defaultPreset.name == "Văn bản mặc định")
        #expect(vm.templatePresets.isEmpty)

        // Phục hồi lại trạng thái cho các test suite khác
        _ = TextTemplateLoader.shared.reload()
    }

    @Test("AdjustmentLibraryViewModel provides defaultPreset while templatePresets reflects remote sync")
    func testAdjustmentLibraryViewModelDefaultAndRemoteSync() {
        AdjustmentTemplateLoader.shared.setInMemoryTemplates([])
        let vm = AdjustmentLibraryViewModel()
        #expect(vm.defaultPreset.id == "default")
        #expect(vm.defaultPreset.name == "Mặc định")
        #expect(vm.templatePresets.isEmpty)

        // Phục hồi lại trạng thái cho các test suite khác
        _ = AdjustmentTemplateLoader.shared.reload()
    }
}

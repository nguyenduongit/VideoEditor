import SwiftUI
import Testing
import Domain
@testable import FeatureShell

private struct MockThumbnailService: AssetThumbnailServiceProtocol {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data? {
        nil
    }
}

struct TabRegistryTests {
    @Test @MainActor func testRegisterTabsSortsByOrder() {
        let registry = TabRegistry()
        let mediaVM = MediaLibraryViewModel(thumbnailService: MockThumbnailService())

        registry.register(AdjustmentTabDescriptor())
        registry.register(MediaTabDescriptor(mediaViewModel: mediaVM))
        registry.register(TextTabDescriptor())
        registry.register(AudioTabDescriptor())

        #expect(registry.tabs.count == 4)
        #expect(registry.tabs[0].id == TabID.media)
        #expect(registry.tabs[1].id == TabID.audio)
        #expect(registry.tabs[2].id == TabID.text)
        #expect(registry.tabs[3].id == TabID.adjustment)
    }

    @Test @MainActor func testSidebarViewResolution() {
        let registry = TabRegistry()
        let mediaVM = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        registry.register(MediaTabDescriptor(mediaViewModel: mediaVM))

        #expect(registry.sidebarView(for: .media) != nil)
        #expect(registry.sidebarView(for: .audio) == nil)
    }

    @Test @MainActor func testAddingNewTabSeamlesslyWithoutModifyingExistingCode() {
        struct MockEffectsTab: TabDescriptor {
            let id: TabID = "effects"
            let title: String = "Effects"
            let order: Int = 50
            func makeSidebarView() -> AnyView {
                AnyView(Text("Effects Content"))
            }
        }

        let registry = TabRegistry()
        let mediaVM = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        registry.register(MediaTabDescriptor(mediaViewModel: mediaVM))
        registry.register(MockEffectsTab())

        #expect(registry.tabs.count == 2)
        #expect(registry.tabs[1].id == TabID(rawValue: "effects"))
        #expect(registry.sidebarView(for: "effects") != nil)
    }
}

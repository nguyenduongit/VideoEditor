import SwiftUI
import Testing
import Domain
import DesignSystem
@testable import FeatureShell

struct SidebarTabBarTests {
    @Test @MainActor func testSidebarTabItemInitialization() {
        let item1 = DSSidebarTabItem(id: "media", title: "Media", iconName: "photo.on.rectangle")
        #expect(item1.id == "media")
        #expect(item1.title == "Media")
        #expect(item1.iconName == "photo.on.rectangle")
        #expect(item1.isSoon == false)

        let item2 = DSSidebarTabItem(id: "transition", title: "Transition", iconName: "arrow.left.arrow.right", isSoon: true)
        #expect(item2.id == "transition")
        #expect(item2.title == "Transition")
        #expect(item2.iconName == "arrow.left.arrow.right")
        #expect(item2.isSoon == true)
    }

    @Test @MainActor func testSidebarTabBarViewSelection() {
        var selected: String?
        let items = [
            DSSidebarTabItem(id: "media", title: "Media", iconName: "photo.on.rectangle"),
            DSSidebarTabItem(id: "audio", title: "Audio", iconName: "waveform"),
            DSSidebarTabItem(id: "transition", title: "Transition", iconName: "arrow.left.arrow.right", isSoon: true)
        ]

        let _ = DSSidebarTabBar(items: items, selectedID: "audio", onSelect: { selected = $0 })
        #expect(items.count == 3)
        #expect(selected == nil)
    }

    @Test @MainActor func testSidebarViewWithTabItems() {
        let registry = TabRegistry()
        registry.register(TransitionTabDescriptor())
        registry.register(StickerTabDescriptor())

        var selectedTab: TabID?
        let _ = SidebarView(
            tabs: registry.tabs,
            selectedTabID: .transition,
            onSelectTab: { selectedTab = $0 }
        )
        #expect(registry.tabs.count == 2)
        #expect(selectedTab == nil)
    }
}


import Testing
@testable import Domain

struct ShellTabTests {
    @Test func testAllCasesContainRequiredTabs() {
        let expectedCount = 4
        #expect(ShellTab.allCases.count == expectedCount)
        #expect(ShellTab.media.title == "Media")
        #expect(ShellTab.audio.title == "Audio")
        #expect(ShellTab.text.title == "Text")
        #expect(ShellTab.adjustment.title == "Adjustment")
    }

    @Test func testTabIdentifiersMatchRawValues() {
        for tab in ShellTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }
}

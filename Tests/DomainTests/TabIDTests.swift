import Testing
@testable import Domain

struct TabIDTests {
    @Test func testStandardTabConstants() {
        #expect(TabID.media.rawValue == "media")
        #expect(TabID.audio.rawValue == "audio")
        #expect(TabID.text.rawValue == "text")
        #expect(TabID.adjustment.rawValue == "adjustment")
    }

    @Test func testStringLiteralInitialization() {
        let customTab: TabID = "effects"
        #expect(customTab.rawValue == "effects")
        #expect(customTab.id == "effects")
    }

    @Test func testEqualityAndHashable() {
        let first: TabID = "media"
        let second = TabID.media
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }
}

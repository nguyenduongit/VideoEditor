import Foundation
import CoreGraphics
import Testing
@testable import FeatureShell
import Domain

@Suite("CustomFontManagerTests")
@MainActor
struct CustomFontManagerTests {
    @Test func testCustomFontManagerLoadsSystemAndCustomFonts() {
        let manager = CustomFontManager.shared
        #expect(manager.isLoaded == true)
        #expect(manager.fonts.count >= 10)

        // Phải có các font hệ thống mặc định
        #expect(manager.fonts.contains(where: { $0.id == "Helvetica" }))
        #expect(manager.fonts.contains(where: { $0.id == "Impact" }))

        // Nếu có thư mục Sources/Font thì phải load được các font UVN
        let hasCustom = manager.fonts.contains(where: { $0.isCustom })
        #expect(hasCustom == true)
    }

    @Test func testToggleFavoritesAndSorting() {
        let manager = CustomFontManager.shared
        let testFontID = "Impact"

        // Đảm bảo trạng thái ban đầu
        if manager.isFavorite(fontID: testFontID) {
            manager.toggleFavorite(fontID: testFontID)
        }
        #expect(!manager.isFavorite(fontID: testFontID))

        // Bật yêu thích
        manager.toggleFavorite(fontID: testFontID)
        #expect(manager.isFavorite(fontID: testFontID))

        // Kiểm tra sorting: Impact phải nằm trong danh sách favorites
        let (favs, others) = manager.sortedFonts()
        #expect(favs.contains(where: { $0.id == testFontID }))
        #expect(!others.contains(where: { $0.id == testFontID }))

        // Tắt yêu thích
        manager.toggleFavorite(fontID: testFontID)
        #expect(!manager.isFavorite(fontID: testFontID))
        let (favsAfter, othersAfter) = manager.sortedFonts()
        #expect(!favsAfter.contains(where: { $0.id == testFontID }))
        #expect(othersAfter.contains(where: { $0.id == testFontID }))
    }

    @Test func testFontSearchFiltering() {
        let manager = CustomFontManager.shared
        let (favs, others) = manager.sortedFonts(matching: "Helvetica")
        let total = favs.count + others.count
        #expect(total >= 1)
        #expect(favs.contains(where: { $0.id == "Helvetica" }) || others.contains(where: { $0.id == "Helvetica" }))

        let emptySearch = manager.sortedFonts(matching: "NonExistentFontXYZ123")
        #expect(emptySearch.favorites.isEmpty)
        #expect(emptySearch.others.isEmpty)
    }

    @Test func testTextRendererEngineRendersWithCustomFont() {
        let canvasSize = CGSize(width: 640, height: 360)
        var config = TextConfiguration()
        config.content = "Việt Nam Đẹp Tuyệt Vời"
        config.fontName = "UVNBachDang"
        config.fontSize = 32.0

        let image = TextRendererEngine.shared.renderImage(for: config, canvasSize: canvasSize)
        #expect(image != nil)
        #expect(image?.extent.size == canvasSize)
    }
}

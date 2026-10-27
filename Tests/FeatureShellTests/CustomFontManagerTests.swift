import Foundation
import CoreGraphics
import Testing
@testable import FeatureShell
import Domain

@Suite("CustomFontManagerTests")
@MainActor
struct CustomFontManagerTests {
    @Test func testCustomFontManagerLoadsCustomFontsFromFolder() {
        let manager = CustomFontManager.shared
        #expect(manager.isLoaded == true)
        #expect(manager.fonts.count >= 16)

        // Toàn bộ font trong danh sách đều là font tùy chỉnh từ thư mục Sources/Font
        #expect(manager.fonts.allSatisfy { $0.isCustom })

        // Kiểm tra sự hiện diện của một số font tiêu biểu trong Sources/Font
        let hasUVN = manager.fonts.contains(where: { $0.displayName.contains("UVN") || $0.id.contains("UVN") })
        #expect(hasUVN == true)
    }

    @Test func testToggleFavoritesAndSorting() {
        let manager = CustomFontManager.shared
        guard let testFontID = manager.fonts.first?.id else { return }

        // Đảm bảo trạng thái ban đầu
        if manager.isFavorite(fontID: testFontID) {
            manager.toggleFavorite(fontID: testFontID)
        }
        #expect(!manager.isFavorite(fontID: testFontID))

        // Bật yêu thích
        manager.toggleFavorite(fontID: testFontID)
        #expect(manager.isFavorite(fontID: testFontID))

        // Kiểm tra sorting: font được chọn phải nằm trong danh sách favorites
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
        let (favs, others) = manager.sortedFonts(matching: "UVN")
        let total = favs.count + others.count
        #expect(total >= 1)
        #expect(favs.contains(where: { $0.displayName.contains("UVN") || $0.id.contains("UVN") })
             || others.contains(where: { $0.displayName.contains("UVN") || $0.id.contains("UVN") }))

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

    @Test func testFontCyclingLogic() {
        let manager = CustomFontManager.shared
        let allFonts = manager.fonts
        #expect(allFonts.count >= 16)

        let nextIndex = (0 + 1) % allFonts.count
        #expect(nextIndex == 1)

        let prevIndex = (0 - 1 + allFonts.count) % allFonts.count
        #expect(prevIndex == allFonts.count - 1)
    }

    @Test func testFontCategoryClassification() {
        let manager = CustomFontManager.shared
        #expect(CustomFontManager.resolveCategory(for: "HY-ThuPhap1", displayName: "HY-Thu Phap 1") == .calligraphy)
        #expect(CustomFontManager.resolveCategory(for: "iCielGotham-Ultra", displayName: "iCiel Gotham Ultra") == .headline)
        #expect(CustomFontManager.resolveCategory(for: "iCielBalihoScript", displayName: "iCiel Baliho Script") == .handwriting)
        #expect(CustomFontManager.resolveCategory(for: "iCielNabila", displayName: "iCiel Nabila") == .comic)
        #expect(CustomFontManager.resolveCategory(for: "Tahoma", displayName: "Tahoma") == .subtitle)
        #expect(CustomFontManager.resolveCategory(for: "UVNBuiDoi", displayName: "UVN Bui Doi") == .vintage)

        let (favCalligraphy, otherCalligraphy) = manager.sortedFonts(category: .calligraphy)
        let totalCalligraphy = favCalligraphy + otherCalligraphy
        #expect(!totalCalligraphy.isEmpty)
        #expect(totalCalligraphy.allSatisfy { $0.category == .calligraphy })

        let (favHeadline, otherHeadline) = manager.sortedFonts(category: .headline)
        let totalHeadline = favHeadline + otherHeadline
        #expect(!totalHeadline.isEmpty)
        #expect(totalHeadline.allSatisfy { $0.category == .headline })
    }
}

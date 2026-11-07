import Testing
import Foundation
import DesignSystem
@testable import FeatureShell

@Suite("Color Quick Select & More Color Panel Tests")
@MainActor
struct ColorPickerRedesignTests {

    @Test("Default swatches contain 14 items starting with white and black followed by 12 spectral colors")
    func defaultSwatchesStructure() {
        let swatches = TextColorSwatchesRow.defaultSwatches
        #expect(swatches.count == 14, "Phải có đúng 14 ô màu cơ bản")
        #expect(swatches[0] == "#FFFFFF", "Ô đầu tiên phải là Trắng")
        #expect(swatches[1] == "#000000", "Ô thứ hai phải là Đen")

        // 12 ô màu quang phổ
        #expect(swatches[2] == "#EF4444")  // Đỏ
        #expect(swatches[3] == "#F97316")  // Cam
        #expect(swatches[4] == "#F59E0B")  // Vàng nghệ
        #expect(swatches[5] == "#FDE047")  // Vàng chanh
        #expect(swatches[6] == "#84CC16")  // Lime
        #expect(swatches[7] == "#22C55E")  // Xanh lục
        #expect(swatches[8] == "#14B8A6")  // Xanh ngọc
        #expect(swatches[9] == "#06B6D4")  // Cyan
        #expect(swatches[10] == "#3B82F6") // Xanh da trời
        #expect(swatches[11] == "#6366F1") // Xanh chàm
        #expect(swatches[12] == "#A855F7") // Tím
        #expect(swatches[13] == "#EC4899") // Hồng sen
    }

    @Test("Color matching accurately matches identical hex and legacy variations")
    func colorMatchingLogic() {
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#FFFFFF", selectedHex: "#FFFFFF"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#ffffff", selectedHex: "FFFFFF"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#EF4444", selectedHex: "#CF1322"))
        #expect(!TextColorSwatchesRow.isColorMatching(swatchHex: "#000000", selectedHex: "NONE"))
        #expect(!TextColorSwatchesRow.isColorMatching(swatchHex: "NONE", selectedHex: "#FFFFFF"))
    }

    @Test("Clean hex helper handles whitespace and prefix")
    func cleanHexFormatting() {
        #expect(TextColorSwatchesRow.cleanHex(" #3B82F6 ") == "3B82F6")
        #expect(TextColorSwatchesRow.cleanHex("fde047") == "FDE047")
    }

    @Test("DSColorSpectrumPicker bidirectionally converts HSB to HEX and back")
    func hsbHexBidirectionalConversion() {
        // Red: H=0, S=1, B=1 -> #FF0000
        let redHex = DSColorSpectrumPicker.hsbToHex(h: 0.0, s: 1.0, b: 1.0)
        #expect(redHex.uppercased() == "#FF0000")

        // Pure white: S=0, B=1 -> #FFFFFF
        let whiteHex = DSColorSpectrumPicker.hsbToHex(h: 0.0, s: 0.0, b: 1.0)
        #expect(whiteHex.uppercased() == "#FFFFFF")

        // Pure black: B=0 -> #000000
        let blackHex = DSColorSpectrumPicker.hsbToHex(h: 0.0, s: 0.0, b: 0.0)
        #expect(blackHex.uppercased() == "#000000")

        // Hex to HSB conversion
        let (h, s, b) = DSColorSpectrumPicker.hexToHSB("#FF0000")
        #expect(abs(s - 1.0) < 0.05)
        #expect(abs(b - 1.0) < 0.05)
        #expect(abs(h - 0.0) < 0.05 || abs(h - 1.0) < 0.05)
    }
}

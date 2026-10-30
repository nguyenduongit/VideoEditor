import Testing
import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain
@testable import FeatureShell

@Suite("TextAutoFitterTests")
struct TextAutoFitterTests {

    @Test("TextAutoFitter calculates max safe width based on aspect ratio")
    func testMaxSafeWidthCalculation() {
        let verticalCanvas = CGSize(width: 1080, height: 1920) // 9:16
        let horizontalCanvas = CGSize(width: 1920, height: 1080) // 16:9

        let safeVertical = TextAutoFitter.maxSafeWidth(for: verticalCanvas)
        let safeHorizontal = TextAutoFitter.maxSafeWidth(for: horizontalCanvas)

        #expect(safeVertical == 1080.0 * 0.82)
        #expect(safeHorizontal == 1920.0 * 0.85)
    }

    @Test("TextAutoFitter measures single line width accurately")
    func testMeasureSingleLineWidth() {
        let emptyConfig = TextConfiguration(content: "")
        #expect(TextAutoFitter.measureSingleLineWidth(for: emptyConfig) == 0.0)

        let shortConfig = TextConfiguration(content: "Alo", fontSize: 40.0)
        let shortWidth = TextAutoFitter.measureSingleLineWidth(for: shortConfig)
        #expect(shortWidth > 0.0)

        let longConfig = TextConfiguration(content: "Tình ca người đi biển rất dài trên một dòng", fontSize: 40.0)
        let longWidth = TextAutoFitter.measureSingleLineWidth(for: longConfig)
        #expect(longWidth > shortWidth)
    }

    @Test("TextAutoFitter scales down font size for long title on 9:16 canvas")
    func testAutoScaleFontSizeForLongTitle() {
        let canvas916 = CGSize(width: 1080, height: 1920)
        var titleConfig = TextConfiguration(
            content: "Tình ca người đi biển tuyệt đẹp trên sóng hoàng hôn",
            fontSize: 72.0
        )

        let initialWidth = TextAutoFitter.measureSingleLineWidth(for: titleConfig)
        let maxSafe = TextAutoFitter.maxSafeWidth(for: canvas916)
        #expect(initialWidth > maxSafe)

        let didScale = TextAutoFitter.autoScaleFontSize(config: &titleConfig, canvasSize: canvas916)
        #expect(didScale == true)
        #expect(titleConfig.fontSize < 72.0)

        let newWidth = TextAutoFitter.measureSingleLineWidth(for: titleConfig)
        #expect(newWidth <= maxSafe + 10.0)
    }

    @Test("TextAutoFitter leaves already fitting short title untouched")
    func testLeavesShortTitleUntouched() {
        let canvas916 = CGSize(width: 1080, height: 1920)
        var shortConfig = TextConfiguration(
            content: "Vlog 01",
            fontSize: 36.0
        )

        let didScale = TextAutoFitter.autoScaleFontSize(config: &shortConfig, canvasSize: canvas916)
        #expect(didScale == false)
        #expect(shortConfig.fontSize == 36.0)
    }

    #if os(macOS)
    @Test("TextSegmentRenderer tokenizes with natural font kerning without phantom padding")
    func testTokenizeNaturalKerning() {
        let font = NSFont.systemFont(ofSize: 48.0)
        let content = "Tình ca người đi biển"

        let (tokens, totalWidth) = TextSegmentRenderer.tokenize(
            content: content,
            scope: .perCharacter,
            font: font,
            spacing: 0.0
        )

        #expect(tokens.count == content.count)
        // Chiều rộng tổng không bị phình to vượt quá 1080px ở cỡ chữ 48
        #expect(totalWidth < 1080.0)
        #expect(totalWidth > 0.0)
    }
    #endif
}

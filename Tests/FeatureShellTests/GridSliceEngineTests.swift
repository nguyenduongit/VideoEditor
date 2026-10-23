import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("GridSliceEngineTests")
@MainActor
struct GridSliceEngineTests {
    @Test("Default GridConfiguration initializes 3 rows and 1 column equally")
    func testDefaultGridConfiguration() {
        let config = GridConfiguration(rows: 3, columns: 1)
        #expect(config.rows == 3)
        #expect(config.columns == 1)
        #expect(config.isDefault == true)

        #expect(config.rowHeights.count == 3)
        #expect(config.rowOffsets.count == 3)
        #expect(abs(config.rowHeights[0] - 1.0 / 3.0) < 0.001)
        #expect(abs(config.rowHeights[1] - 1.0 / 3.0) < 0.001)
        #expect(abs(config.rowHeights[2] - 1.0 / 3.0) < 0.001)

        #expect(abs(config.rowOffsets[0] - 0.0) < 0.001)
        #expect(abs(config.rowOffsets[1] - 1.0 / 3.0) < 0.001)
        #expect(abs(config.rowOffsets[2] - 2.0 / 3.0) < 0.001)

        #expect(config.colWidths.count == 1)
        #expect(abs(config.colWidths[0] - 1.0) < 0.001)
        #expect(abs(config.colOffsets[0] - 0.0) < 0.001)
    }

    @Test("GridConfiguration JSON serialization and deserialization roundtrip")
    func testGridConfigurationSerialization() {
        var config = GridConfiguration(rows: 2, columns: 2)
        config.selectedTarget = .column(1)
        config.colWidths[1] = 0.8

        guard let encoded = config.encodeToString() else {
            Issue.record("Failed to encode GridConfiguration to JSON string")
            return
        }
        guard let decoded = GridConfiguration.decode(from: encoded) else {
            Issue.record("Failed to decode GridConfiguration from JSON string")
            return
        }

        #expect(decoded.rows == 2)
        #expect(decoded.columns == 2)
        #expect(decoded.selectedTarget == .column(1))
        #expect(abs(decoded.colWidths[1] - 0.8) < 0.001)
    }

    @Test("scaleRow symmetrically expands from center and translates adjacent rows outward")
    func testScaleRowBilateralPush() {
        var config = GridConfiguration(rows: 3, columns: 1)
        let initialH1 = config.rowHeights[1]
        let initialOffset0 = config.rowOffsets[0]
        let initialOffset2 = config.rowOffsets[2]

        // Increase row 1 height by 0.2
        let targetH1 = initialH1 + 0.2
        GridSliceEngine.scaleRow(config: &config, index: 1, newHeight: targetH1)

        #expect(abs(config.rowHeights[1] - targetH1) < 0.001)
        // Row 0 above must have been translated upward (negative offset shift)
        #expect(config.rowOffsets[0] < initialOffset0)
        // Row 2 below must have been translated downward (positive offset shift)
        #expect(config.rowOffsets[2] > initialOffset2)
        // Row 1 offset must shift up by half delta to maintain center
        #expect(abs(config.rowOffsets[0] - (initialOffset0 - 0.1)) < 0.001)
        #expect(abs(config.rowOffsets[2] - (initialOffset2 + 0.1)) < 0.001)
        #expect(config.isDefault == false)
    }

    @Test("scaleColumn symmetrically expands from center and translates adjacent columns outward")
    func testScaleColumnBilateralPush() {
        var config = GridConfiguration(rows: 1, columns: 3)
        let initialW1 = config.colWidths[1]
        let initialOffset0 = config.colOffsets[0]
        let initialOffset2 = config.colOffsets[2]

        // Increase column 1 width by 0.3
        let targetW1 = initialW1 + 0.3
        GridSliceEngine.scaleColumn(config: &config, index: 1, newWidth: targetW1)

        #expect(abs(config.colWidths[1] - targetW1) < 0.001)
        // Col 0 pushed left, Col 2 pushed right
        #expect(abs(config.colOffsets[0] - (initialOffset0 - 0.15)) < 0.001)
        #expect(abs(config.colOffsets[2] - (initialOffset2 + 0.15)) < 0.001)
        #expect(config.isDefault == false)
    }

    @Test("moveHorizontalDivider adjusts adjacent rows without affecting other rows")
    func testMoveHorizontalDivider() {
        var config = GridConfiguration(rows: 3, columns: 1)
        #expect(config.rowDividers.count == 2)
        #expect(abs(config.rowDividers[0] - 1.0 / 3.0) < 0.001)
        // Move divider between row 0 and 1 down to y = 0.45
        GridSliceEngine.moveHorizontalDivider(config: &config, lineIndex: 0, newY: 0.45)

        #expect(abs(config.rowDividers[0] - 0.45) < 0.001)
        #expect(abs(config.rowHeights[0] - 0.45) < 0.001)
        #expect(abs(config.rowOffsets[1] - 0.45) < 0.001)
        // Row 1 bottom was initially at 2/3 ≈ 0.6667
        let expectedRow1H = (2.0 / 3.0) - 0.45
        #expect(abs(config.rowHeights[1] - expectedRow1H) < 0.001)
        // Row 2 is unchanged
        #expect(abs(config.rowOffsets[2] - (2.0 / 3.0)) < 0.001)

        // Verify that divider movement maintains unscaled 1:1 slices (srcH == dstH)
        let bounds0 = config.rowBounds(for: 0)
        let bounds1 = config.rowBounds(for: 1)
        #expect(abs((bounds0.bottom - bounds0.top) - config.rowHeights[0]) < 0.001)
        #expect(abs((bounds1.bottom - bounds1.top) - config.rowHeights[1]) < 0.001)
    }

    @Test("moveVerticalDivider adjusts adjacent columns without affecting other columns")
    func testMoveVerticalDivider() {
        var config = GridConfiguration(rows: 1, columns: 3)
        #expect(config.colDividers.count == 2)
        #expect(abs(config.colDividers[0] - 1.0 / 3.0) < 0.001)
        // Move divider between column 0 and 1 to x = 0.2
        GridSliceEngine.moveVerticalDivider(config: &config, lineIndex: 0, newX: 0.2)

        #expect(abs(config.colDividers[0] - 0.2) < 0.001)
        #expect(abs(config.colWidths[0] - 0.2) < 0.001)
        #expect(abs(config.colOffsets[1] - 0.2) < 0.001)
        let expectedCol1W = (2.0 / 3.0) - 0.2
        #expect(abs(config.colWidths[1] - expectedCol1W) < 0.001)
        #expect(abs(config.colOffsets[2] - (2.0 / 3.0)) < 0.001)

        // Verify unscaled 1:1 slices (srcW == dstW)
        let bounds0 = config.colBounds(for: 0)
        let bounds1 = config.colBounds(for: 1)
        #expect(abs((bounds0.right - bounds0.left) - config.colWidths[0]) < 0.001)
        #expect(abs((bounds1.right - bounds1.left) - config.colWidths[1]) < 0.001)
    }

    @Test("updateGridDimensions reallocates subdivisions cleanly and clamps selection")
    func testUpdateGridDimensions() {
        var config = GridConfiguration(rows: 3, columns: 2)
        config.selectedTarget = .row(2)

        GridSliceEngine.updateGridDimensions(config: &config, rows: 2, columns: 4)
        #expect(config.rows == 2)
        #expect(config.columns == 4)
        #expect(config.rowHeights.count == 2)
        #expect(config.colWidths.count == 4)
        #expect(config.selectedTarget == .row(1))
    }

    @Test("GridSliceCompositor applies slice transformation returning valid CIImage")
    func testGridSliceCompositorRendering() {
        let size = CGSize(width: 300, height: 300)
        let baseImage = CIImage(color: CIColor.red).cropped(to: CGRect(origin: .zero, size: size))
        var config = GridConfiguration(rows: 3, columns: 1)
        config.selectedTarget = .row(1)
        GridSliceEngine.scaleRow(config: &config, index: 1, newHeight: 0.5)

        let result = GridSliceCompositor.applyGrid(to: baseImage, config: config, canvasSize: size)
        #expect(result.extent.size.width == 300)
        #expect(result.extent.size.height == 300)
    }
}

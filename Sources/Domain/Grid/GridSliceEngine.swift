import Foundation

/// Mathematical calculation engine for video grid slicing, bilateral scaling, and line dragging.
/// Complies with R2.3, R3.1, and R7.5 of AGENTS.md.
public enum GridSliceEngine {
    public static let minDimension: Double = 0.05

    public static func makeDefault(rows: Int, columns: Int) -> GridConfiguration {
        GridConfiguration(rows: rows, columns: columns)
    }

    public static func updateGridDimensions(
        config: inout GridConfiguration,
        rows: Int,
        columns: Int
    ) {
        let safeRows = max(1, min(10, rows))
        let safeCols = max(1, min(10, columns))
        if config.rows != safeRows || config.columns != safeCols {
            config = makeDefault(rows: safeRows, columns: safeCols)
        }
    }

    public static func scaleRow(
        config: inout GridConfiguration,
        index: Int,
        newHeight: Double
    ) {
        guard index >= 0, index < config.rows else { return }
        let clampedH = max(minDimension, newHeight)
        let oldH = config.rowHeights[index]
        let delta = clampedH - oldH
        let halfDelta = delta / 2.0

        config.rowHeights[index] = clampedH
        config.rowOffsets[index] -= halfDelta

        // Translate all rows above upwards
        for k in 0..<index {
            config.rowOffsets[k] -= halfDelta
        }

        // Translate all rows below downwards
        for k in (index + 1)..<config.rows {
            config.rowOffsets[k] += halfDelta
        }
    }

    public static func scaleColumn(
        config: inout GridConfiguration,
        index: Int,
        newWidth: Double
    ) {
        guard index >= 0, index < config.columns else { return }
        let clampedW = max(minDimension, newWidth)
        let oldW = config.colWidths[index]
        let delta = clampedW - oldW
        let halfDelta = delta / 2.0

        config.colWidths[index] = clampedW
        config.colOffsets[index] -= halfDelta

        // Translate all columns to the left
        for k in 0..<index {
            config.colOffsets[k] -= halfDelta
        }

        // Translate all columns to the right
        for k in (index + 1)..<config.columns {
            config.colOffsets[k] += halfDelta
        }
    }

    public static func moveHorizontalDivider(
        config: inout GridConfiguration,
        lineIndex: Int,
        newY: Double
    ) {
        guard lineIndex >= 0, lineIndex < config.rows - 1 else { return }
        let topY = config.rowOffsets[lineIndex]
        let bottomY = config.rowOffsets[lineIndex + 1] + config.rowHeights[lineIndex + 1]

        let minY = topY + minDimension
        let maxY = bottomY - minDimension
        guard minY < maxY else { return }

        let clampedY = max(minY, min(maxY, newY))
        config.rowHeights[lineIndex] = clampedY - topY
        config.rowOffsets[lineIndex + 1] = clampedY
        config.rowHeights[lineIndex + 1] = bottomY - clampedY
    }

    public static func moveVerticalDivider(
        config: inout GridConfiguration,
        lineIndex: Int,
        newX: Double
    ) {
        guard lineIndex >= 0, lineIndex < config.columns - 1 else { return }
        let leftX = config.colOffsets[lineIndex]
        let rightX = config.colOffsets[lineIndex + 1] + config.colWidths[lineIndex + 1]

        let minX = leftX + minDimension
        let maxX = rightX - minDimension
        guard minX < maxX else { return }

        let clampedX = max(minX, min(maxX, newX))
        config.colWidths[lineIndex] = clampedX - leftX
        config.colOffsets[lineIndex + 1] = clampedX
        config.colWidths[lineIndex + 1] = rightX - clampedX
    }
}

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
        guard lineIndex >= 0, lineIndex < config.rowDividers.count else { return }
        let prevY = (lineIndex == 0) ? 0.0 : config.rowDividers[lineIndex - 1]
        let nextY = (lineIndex == config.rowDividers.count - 1) ? 1.0 : config.rowDividers[lineIndex + 1]

        let minY = prevY + minDimension
        let maxY = nextY - minDimension
        guard minY < maxY else { return }

        let clampedY = max(minY, min(maxY, newY))
        config.rowDividers[lineIndex] = clampedY

        // Update partition sizes for the adjacent rows without applying scale distortion
        let rowAbove = lineIndex
        let rowBelow = lineIndex + 1

        let boundsAbove = config.rowBounds(for: rowAbove)
        let boundsBelow = config.rowBounds(for: rowBelow)

        config.rowHeights[rowAbove] = boundsAbove.bottom - boundsAbove.top
        config.rowOffsets[rowAbove] = boundsAbove.top

        config.rowHeights[rowBelow] = boundsBelow.bottom - boundsBelow.top
        config.rowOffsets[rowBelow] = boundsBelow.top
    }

    public static func moveVerticalDivider(
        config: inout GridConfiguration,
        lineIndex: Int,
        newX: Double
    ) {
        guard lineIndex >= 0, lineIndex < config.colDividers.count else { return }
        let prevX = (lineIndex == 0) ? 0.0 : config.colDividers[lineIndex - 1]
        let nextX = (lineIndex == config.colDividers.count - 1) ? 1.0 : config.colDividers[lineIndex + 1]

        let minX = prevX + minDimension
        let maxX = nextX - minDimension
        guard minX < maxX else { return }

        let clampedX = max(minX, min(maxX, newX))
        config.colDividers[lineIndex] = clampedX

        // Update partition sizes for the adjacent columns without applying scale distortion
        let colLeft = lineIndex
        let colRight = lineIndex + 1

        let boundsLeft = config.colBounds(for: colLeft)
        let boundsRight = config.colBounds(for: colRight)

        config.colWidths[colLeft] = boundsLeft.right - boundsLeft.left
        config.colOffsets[colLeft] = boundsLeft.left

        config.colWidths[colRight] = boundsRight.right - boundsRight.left
        config.colOffsets[colRight] = boundsRight.left
    }
}

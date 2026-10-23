import SwiftUI
import Domain
import DesignSystem

/// Interactive square grid canvas with draggable divider lines and outer selection node rails.
/// Complies with R3.1, R8.1, and R8.2 of AGENTS.md.
public struct GridInteractiveSquareView: View {
    @Binding var config: GridConfiguration
    let onCommit: () -> Void

    private let squareSize: CGFloat = 200
    private let railSize: CGFloat = 28

    public init(config: Binding<GridConfiguration>, onCommit: @escaping () -> Void) {
        self._config = config
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(alignment: .top, spacing: DSSpacing.xs) {
                gridSquare
                    .frame(width: squareSize, height: squareSize)
                rightRowRail
                    .frame(width: railSize, height: squareSize)
            }
            HStack(alignment: .top, spacing: DSSpacing.xs) {
                bottomColRail
                    .frame(width: squareSize, height: railSize)
                Color.clear
                    .frame(width: railSize, height: railSize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var gridSquare: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))

            // Cell highlights
            cellHighlightsView

            // Divider lines
            horizontalDividersView
            verticalDividersView

            RoundedRectangle(cornerRadius: DSRadius.control)
                .stroke(DSColors.blockBorder, lineWidth: 1.5)
        }
        .clipped()
    }

    private var cellHighlightsView: some View {
        ForEach(0..<config.rows, id: \.self) { r in
            ForEach(0..<config.columns, id: \.self) { c in
                let isRowSelected = config.selectedTarget == .row(r)
                let isColSelected = config.selectedTarget == .column(c)
                let isSelected = isRowSelected || isColSelected

                let cellX = max(0, config.colOffsets[c]) * squareSize
                let cellY = max(0, config.rowOffsets[r]) * squareSize
                let cellW = config.colWidths[c] * squareSize
                let cellH = config.rowHeights[r] * squareSize

                if isSelected && cellW > 0 && cellH > 0 {
                    Rectangle()
                        .fill(DSColors.toggleCyan.opacity(isRowSelected && isColSelected ? 0.35 : 0.18))
                        .frame(width: cellW, height: cellH)
                        .offset(x: cellX, y: cellY)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var horizontalDividersView: some View {
        ForEach(0..<(config.rows - 1), id: \.self) { lineIdx in
            let normY = lineIdx < config.rowDividers.count ? config.rowDividers[lineIdx] : config.rowOffsets[lineIdx + 1]
            let yPos = normY * squareSize
            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(width: squareSize, height: 1.5)
                .position(x: squareSize / 2, y: yPos)
        }
    }

    private var verticalDividersView: some View {
        ForEach(0..<(config.columns - 1), id: \.self) { lineIdx in
            let normX = lineIdx < config.colDividers.count ? config.colDividers[lineIdx] : config.colOffsets[lineIdx + 1]
            let xPos = normX * squareSize
            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 1.5, height: squareSize)
                .position(x: xPos, y: squareSize / 2)
        }
    }

    private var rightRowRail: some View {
        ZStack(alignment: .top) {
            ForEach(0..<config.rows, id: \.self) { r in
                let rowCenterY = (config.rowOffsets[r] + config.rowHeights[r] / 2.0) * squareSize
                let clampedY = max(10, min(squareSize - 10, rowCenterY))
                let isSelected = config.selectedTarget == .row(r)

                Button {
                    config.selectedTarget = .row(r)
                } label: {
                    Circle()
                        .fill(isSelected ? DSColors.toggleCyan : DSColors.inputBackground)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white : DSColors.blockBorder, lineWidth: 1.5)
                        )
                        .overlay(
                            Text("\(r + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isSelected ? Color.black : DSColors.textPrimary)
                        )
                }
                .buttonStyle(.plain)
                .position(x: railSize / 2, y: clampedY)
            }
        }
    }

    private var bottomColRail: some View {
        ZStack(alignment: .leading) {
            ForEach(0..<config.columns, id: \.self) { c in
                let colCenterX = (config.colOffsets[c] + config.colWidths[c] / 2.0) * squareSize
                let clampedX = max(10, min(squareSize - 10, colCenterX))
                let isSelected = config.selectedTarget == .column(c)

                Button {
                    config.selectedTarget = .column(c)
                } label: {
                    Circle()
                        .fill(isSelected ? DSColors.toggleCyan : DSColors.inputBackground)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white : DSColors.blockBorder, lineWidth: 1.5)
                        )
                        .overlay(
                            Text("\(c + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isSelected ? Color.black : DSColors.textPrimary)
                        )
                }
                .buttonStyle(.plain)
                .position(x: clampedX, y: railSize / 2)
            }
        }
    }
}

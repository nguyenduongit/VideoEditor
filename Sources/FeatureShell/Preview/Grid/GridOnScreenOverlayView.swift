import SwiftUI
import Domain
import DesignSystem

/// Interactive on-screen overlay on the Preview canvas rendering grid lines and slice boundaries.
/// Complies with R3.1, R7.5, R8.1, and R8.5 of AGENTS.md.
public struct GridOnScreenOverlayView: View {
    @Bindable var inspectorViewModel: InspectorViewModel
    private let canvasSize: CGSize

    @State private var isDragging: Bool = false

    public init(inspectorViewModel: InspectorViewModel, canvasSize: CGSize) {
        self.inspectorViewModel = inspectorViewModel
        self.canvasSize = canvasSize
    }

    public var body: some View {
        GeometryReader { geo in
            let viewSize = geo.size
            if inspectorViewModel.selectedClip != nil,
               inspectorViewModel.effectiveTab == "Grid" {
                let config = currentConfig
                ZStack {
                    selectionHighlight(config: config, viewSize: viewSize)
                    horizontalDividers(config: config, viewSize: viewSize)
                    verticalDividers(config: config, viewSize: viewSize)
                }
            }
        }
    }

    private var currentConfig: GridConfiguration {
        let str = inspectorViewModel.liveProperties["gridConfig"]?.asString ?? ""
        return GridConfiguration.decode(from: str) ?? GridConfiguration(rows: 3, columns: 1)
    }

    @ViewBuilder
    private func selectionHighlight(config: GridConfiguration, viewSize: CGSize) -> some View {
        if let target = config.selectedTarget {
            switch target {
            case .row(let r):
                if r >= 0 && r < config.rows && r < config.rowOffsets.count && r < config.rowHeights.count {
                    let y = CGFloat(config.rowOffsets[r]) * viewSize.height
                    let h = CGFloat(config.rowHeights[r]) * viewSize.height
                    Rectangle()
                        .fill(DSColors.toggleCyan.opacity(0.12))
                        .overlay(
                            Rectangle()
                                .stroke(DSColors.toggleCyan, lineWidth: 1.5)
                        )
                        .frame(width: viewSize.width, height: max(1, h))
                        .position(x: viewSize.width / 2.0, y: y + h / 2.0)
                        .allowsHitTesting(false)
                }
            case .column(let c):
                if c >= 0 && c < config.columns && c < config.colOffsets.count && c < config.colWidths.count {
                    let x = CGFloat(config.colOffsets[c]) * viewSize.width
                    let w = CGFloat(config.colWidths[c]) * viewSize.width
                    Rectangle()
                        .fill(DSColors.toggleCyan.opacity(0.12))
                        .overlay(
                            Rectangle()
                                .stroke(DSColors.toggleCyan, lineWidth: 1.5)
                        )
                        .frame(width: max(1, w), height: viewSize.height)
                        .position(x: x + w / 2.0, y: viewSize.height / 2.0)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func horizontalDividers(config: GridConfiguration, viewSize: CGSize) -> some View {
        if config.rows > 1 {
            ForEach(0..<(config.rows - 1), id: \.self) { i in
                if i < config.rowDividers.count {
                    let normY = config.rowDividers[i]
                    let y = CGFloat(normY) * viewSize.height

                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: viewSize.width, height: 1.5)
                            .shadow(color: Color.black.opacity(0.6), radius: 1)
                    }
                    .frame(width: viewSize.width, height: 24)
                    .contentShape(Rectangle())
                    .position(x: viewSize.width / 2.0, y: y)
                    .gesture(horizontalDragGesture(dividerIndex: i, viewSize: viewSize))
                }
            }
        }
    }

    @ViewBuilder
    private func verticalDividers(config: GridConfiguration, viewSize: CGSize) -> some View {
        if config.columns > 1 {
            ForEach(0..<(config.columns - 1), id: \.self) { j in
                if j < config.colDividers.count {
                    let normX = config.colDividers[j]
                    let x = CGFloat(normX) * viewSize.width

                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 1.5, height: viewSize.height)
                            .shadow(color: Color.black.opacity(0.6), radius: 1)
                    }
                    .frame(width: 24, height: viewSize.height)
                    .contentShape(Rectangle())
                    .position(x: x, y: viewSize.height / 2.0)
                    .gesture(verticalDragGesture(dividerIndex: j, viewSize: viewSize))
                }
            }
        }
    }

    private func horizontalDragGesture(dividerIndex: Int, viewSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { g in
                guard viewSize.height > 0 else { return }
                if !isDragging {
                    isDragging = true
                    inspectorViewModel.onSliderEditingChanged(key: "gridConfig", isEditing: true)
                }
                var config = currentConfig
                let targetY = Double(g.location.y / viewSize.height)
                GridSliceEngine.moveHorizontalDivider(
                    config: &config,
                    lineIndex: dividerIndex,
                    newY: targetY
                )
                if let str = config.encodeToString() {
                    inspectorViewModel.updateLiveText(key: "gridConfig", text: str)
                }
            }
            .onEnded { _ in
                isDragging = false
                inspectorViewModel.onSliderEditingChanged(key: "gridConfig", isEditing: false)
            }
    }

    private func verticalDragGesture(dividerIndex: Int, viewSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { g in
                guard viewSize.width > 0 else { return }
                if !isDragging {
                    isDragging = true
                    inspectorViewModel.onSliderEditingChanged(key: "gridConfig", isEditing: true)
                }
                var config = currentConfig
                let targetX = Double(g.location.x / viewSize.width)
                GridSliceEngine.moveVerticalDivider(
                    config: &config,
                    lineIndex: dividerIndex,
                    newX: targetX
                )
                if let str = config.encodeToString() {
                    inspectorViewModel.updateLiveText(key: "gridConfig", text: str)
                }
            }
            .onEnded { _ in
                isDragging = false
                inspectorViewModel.onSliderEditingChanged(key: "gridConfig", isEditing: false)
            }
    }
}

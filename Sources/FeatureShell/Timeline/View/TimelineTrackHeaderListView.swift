import SwiftUI
import Domain
import DesignSystem

public struct TimelineTrackHeaderListView: View {
    private let layers: [TimelineLayer]
    private let availableHeight: CGFloat
    private let topSpacerHeight: CGFloat
    private let isVerticalScrollable: Bool
    private let verticalScrollOffset: CGFloat
    private let dropBetweenIndex: Int?
    private let layerHeight: (ClipKind) -> CGFloat
    private let onToggleLock: (UUID) -> Void
    private let onToggleHide: (UUID) -> Void
    private let onToggleMute: (UUID) -> Void

    public init(
        layers: [TimelineLayer],
        availableHeight: CGFloat,
        topSpacerHeight: CGFloat,
        isVerticalScrollable: Bool,
        verticalScrollOffset: CGFloat,
        dropBetweenIndex: Int?,
        layerHeight: @escaping (ClipKind) -> CGFloat,
        onToggleLock: @escaping (UUID) -> Void,
        onToggleHide: @escaping (UUID) -> Void,
        onToggleMute: @escaping (UUID) -> Void
    ) {
        self.layers = layers
        self.availableHeight = availableHeight
        self.topSpacerHeight = topSpacerHeight
        self.isVerticalScrollable = isVerticalScrollable
        self.verticalScrollOffset = verticalScrollOffset
        self.dropBetweenIndex = dropBetweenIndex
        self.layerHeight = layerHeight
        self.onToggleLock = onToggleLock
        self.onToggleHide = onToggleHide
        self.onToggleMute = onToggleMute
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            Color.clear.frame(height: topSpacerHeight)
            ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                TimelineTrackHeaderView(
                    layer: layer,
                    height: layerHeight(layer.kind),
                    onToggleLock: { onToggleLock(layer.id) },
                    onToggleHide: { onToggleHide(layer.id) },
                    onToggleMute: { onToggleMute(layer.id) }
                )
                .overlay(indicatorOverlay(for: index, isBottom: false), alignment: .top)
                .overlay(indicatorOverlay(for: index, isBottom: true), alignment: .bottom)
            }
        }
        .offset(y: isVerticalScrollable ? -verticalScrollOffset : 0)
        .frame(width: DSSize.layerHeaderWidth, height: availableHeight, alignment: .top)
        .clipped()
        .background(DSColors.layerHeaderBackground)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(DSColors.blockBorder), alignment: .trailing)
    }

    @ViewBuilder
    private func indicatorOverlay(for index: Int, isBottom: Bool) -> some View {
        let isTarget = isBottom
            ? (dropBetweenIndex == layers.count && index == layers.count - 1)
            : (dropBetweenIndex == index)
        if isTarget {
            Rectangle().fill(DSColors.dropIndicator).frame(height: 2)
        }
    }
}

import SwiftUI

public struct DSMarqueeSelectionView: View {
    public let rect: CGRect

    public init(rect: CGRect) {
        self.rect = rect
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(DSColors.accent.opacity(0.12))
            Rectangle()
                .stroke(
                    DSColors.accent.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        }
        .frame(width: max(0, rect.width), height: max(0, rect.height))
        .offset(x: rect.minX, y: rect.minY)
        .allowsHitTesting(false)
    }
}

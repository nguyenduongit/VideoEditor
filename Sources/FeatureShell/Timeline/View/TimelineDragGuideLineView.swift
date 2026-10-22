import SwiftUI
import DesignSystem

public struct TimelineDragGuideLineView: View {
    private let screenX: CGFloat
    private let height: CGFloat

    public init(screenX: CGFloat, height: CGFloat) {
        self.screenX = screenX
        self.height = height
    }

    public var body: some View {
        ZStack(alignment: .top) {
            guideBadge
            verticalLine
        }
        .allowsHitTesting(false)
    }

    private var guideBadge: some View {
        Path { path in
            path.move(to: CGPoint(x: screenX - 5, y: 0))
            path.addLine(to: CGPoint(x: screenX + 5, y: 0))
            path.addLine(to: CGPoint(x: screenX + 5, y: 4))
            path.addLine(to: CGPoint(x: screenX, y: 9))
            path.addLine(to: CGPoint(x: screenX - 5, y: 4))
            path.closeSubpath()
        }
        .fill(DSColors.dropIndicator)
        .shadow(color: DSColors.dropIndicator.opacity(0.6), radius: 2, x: 0, y: 1)
    }

    private var verticalLine: some View {
        Rectangle()
            .fill(DSColors.dropIndicator)
            .frame(width: 1.5, height: height)
            .position(x: screenX, y: height / 2)
            .shadow(color: DSColors.dropIndicator.opacity(0.8), radius: 3, x: 0, y: 0)
    }
}

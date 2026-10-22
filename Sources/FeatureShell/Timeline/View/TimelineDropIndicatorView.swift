import SwiftUI
import DesignSystem

public struct TimelineDropIndicatorView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: DSSpacing.none) {
            Circle()
                .fill(DSColors.dropIndicator)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(DSColors.dropIndicator)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
    }
}

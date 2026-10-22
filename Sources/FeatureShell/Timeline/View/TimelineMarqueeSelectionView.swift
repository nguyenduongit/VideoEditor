import SwiftUI
import DesignSystem

public struct TimelineMarqueeSelectionView: View {
    public let rect: CGRect

    public init(rect: CGRect) {
        self.rect = rect
    }

    public var body: some View {
        DSMarqueeSelectionView(rect: rect)
    }
}

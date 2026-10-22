import SwiftUI

public struct DSBlockContainer<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .background(DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.block)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
            )
    }
}

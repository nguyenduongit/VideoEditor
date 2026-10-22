import SwiftUI
import AppKit

public struct ClipTrimHandleView: View {
    private let isLeft: Bool
    private let height: CGFloat
    @Binding private var isHovering: Bool
    private let onSelect: () -> Void
    private let onTrimChanged: (CGFloat) -> Void
    private let onTrimEnded: () -> Void

    public static let handleHitWidth: CGFloat = 12.0

    public init(
        isLeft: Bool,
        height: CGFloat,
        isHovering: Binding<Bool>,
        onSelect: @escaping () -> Void = {},
        onTrimChanged: @escaping (CGFloat) -> Void,
        onTrimEnded: @escaping () -> Void
    ) {
        self.isLeft = isLeft
        self.height = height
        self._isHovering = isHovering
        self.onSelect = onSelect
        self.onTrimChanged = onTrimChanged
        self.onTrimEnded = onTrimEnded
    }

    public var body: some View {
        Color.white.opacity(0.001)
            .frame(width: Self.handleHitWidth, height: height)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                onSelect()
            })
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        onTrimChanged(value.translation.width)
                    }
                    .onEnded { _ in
                        onTrimEnded()
                    }
            )
    }
}

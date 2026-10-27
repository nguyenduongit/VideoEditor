import SwiftUI

/// Nút tăng giảm (Stepper) 2 chiều chuẩn DesignSystem, đồng nhất giao diện toàn hệ thống.
/// Thiết kế gồm 2 mũi tên chevron.up và chevron.down xếp dọc, có hiệu ứng hover và press.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng).
public struct DSStepperButton: View {
    public let onIncrement: () -> Void
    public let onDecrement: () -> Void

    @State private var isHoveredUp: Bool = false
    @State private var isHoveredDown: Bool = false
    @State private var isPressingUp: Bool = false
    @State private var isPressingDown: Bool = false

    public init(
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) {
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    public var body: some View {
        VStack(spacing: 0) {
            chevronButton(
                systemName: "chevron.up",
                isHovered: isHoveredUp,
                isPressing: isPressingUp,
                action: onIncrement
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressingUp {
                            isPressingUp = true
                            onIncrement()
                        }
                    }
                    .onEnded { _ in
                        isPressingUp = false
                    }
            )
            .onHover { isHoveredUp = $0 }

            chevronButton(
                systemName: "chevron.down",
                isHovered: isHoveredDown,
                isPressing: isPressingDown,
                action: onDecrement
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressingDown {
                            isPressingDown = true
                            onDecrement()
                        }
                    }
                    .onEnded { _ in
                        isPressingDown = false
                    }
            )
            .onHover { isHoveredDown = $0 }
        }
        .frame(width: 18, height: 21)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3.5))
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func chevronButton(
        systemName: String,
        isHovered: Bool,
        isPressing: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(isHovered || isPressing ? Color.white : Color.white.opacity(0.75))
            .frame(width: 18, height: 10)
            .background(
                isPressing ? Color.white.opacity(0.24) : (isHovered ? Color.white.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

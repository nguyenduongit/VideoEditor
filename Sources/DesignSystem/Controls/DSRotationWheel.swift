import SwiftUI

/// Compact circular rotation wheel dial.
/// Supports interactive dragging to adjust angle with visual needle and cyan indicator.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSRotationWheel: View {
    @Binding private var angle: Double
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false
    @State private var isHovered = false

    private let size: CGFloat = 22

    public init(
        angle: Binding<Double>,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._angle = angle
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(DSColors.inputBackground)
                .frame(width: size, height: size)

            Circle()
                .stroke(isHovered || isDragging ? Color.white.opacity(0.35) : DSColors.inputBorder, lineWidth: 1)
                .frame(width: size, height: size)

            // Center needle & cyan indicator
            needleView
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(dragGesture)
        .onHover { isHovered = $0 }
    }

    private var needleView: some View {
        let radians = angle * .pi / 180.0
        let radius = (size / 2) - 2
        let endX = cos(radians) * radius
        let endY = sin(radians) * radius

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: size / 2, y: size / 2))
                path.addLine(to: CGPoint(x: size / 2 + endX, y: size / 2 + endY))
            }
            .stroke(Color.white.opacity(0.85), lineWidth: 1.5)

            // Cyan accent dot at needle tip
            Circle()
                .fill(DSColors.toggleCyan)
                .frame(width: 3.5, height: 3.5)
                .offset(x: endX, y: endY)
        }
        .frame(width: size, height: size)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    onEditingChanged?(true)
                }
                let center = CGPoint(x: size / 2, y: size / 2)
                let dx = gesture.location.x - center.x
                let dy = gesture.location.y - center.y
                let rad = atan2(dy, dx)
                var deg = rad * 180.0 / .pi
                if deg < 0 { deg += 360.0 }
                angle = (deg * 10).rounded() / 10
            }
            .onEnded { _ in
                isDragging = false
                onEditingChanged?(false)
            }
    }
}

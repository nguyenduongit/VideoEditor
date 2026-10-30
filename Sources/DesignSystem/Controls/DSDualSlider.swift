import SwiftUI

/// Thanh trượt đôi (Dual Range Slider) chuyên biệt cho thời lượng hoạt ảnh Vào (In) và Ra (Out).
/// Thiết kế đối xứng chuẩn CapCut: Con trượt trên (›) chỉnh In, con trượt dưới (‹) chỉnh Out.
/// Đảm bảo hai con trượt không đè chồng chéo và giữ nguyên tắc độc lập của DesignSystem (R2.4).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng).
public struct DSDualSlider: View {
    @Binding private var inValue: Double
    @Binding private var outValue: Double
    private let totalDuration: Double
    private let minDuration: Double
    private let step: Double
    private let showsInThumb: Bool
    private let showsOutThumb: Bool
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isDraggingIn: Bool = false
    @State private var isDraggingOut: Bool = false

    public init(
        inValue: Binding<Double>,
        outValue: Binding<Double>,
        totalDuration: Double,
        minDuration: Double = 0.1,
        step: Double = 0.05,
        showsInThumb: Bool = true,
        showsOutThumb: Bool = true,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._inValue = inValue
        self._outValue = outValue
        self.totalDuration = max(0.5, totalDuration)
        self.minDuration = minDuration
        self.step = step
        self.showsInThumb = showsInThumb
        self.showsOutThumb = showsOutThumb
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbWidth: CGFloat = 11.0
            let thumbHeight: CGFloat = 13.0
            let usableWidth = max(10.0, width - thumbWidth)
            let maxTotal = totalDuration

            // Tính toán vị trí X cho 2 con trượt
            let inFrac = min(1.0, max(0.0, inValue / maxTotal))
            let inX = (thumbWidth / 2.0) + CGFloat(inFrac) * usableWidth

            let outFrac = min(1.0, max(0.0, outValue / maxTotal))
            let outX = width - ((thumbWidth / 2.0) + CGFloat(outFrac) * usableWidth)

            ZStack(alignment: .leading) {
                // Rãnh trượt nền
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 2.5)

                // Đoạn rãnh hoạt ảnh Vào (In)
                if showsInThumb {
                    Capsule()
                        .fill(Color(red: 0.18, green: 0.72, blue: 0.88))
                        .frame(width: max(0.0, inX), height: 2.5)
                }

                // Đoạn rãnh hoạt ảnh Ra (Out)
                if showsOutThumb {
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.65, blue: 0.22))
                        .frame(width: max(0.0, width - outX), height: 2.5)
                        .offset(x: max(0.0, outX))
                }

                // Con trượt trên (In Duration - ›)
                if showsInThumb {
                    topThumbView(thumbWidth: thumbWidth, thumbHeight: thumbHeight)
                        .offset(x: inX - thumbWidth / 2.0, y: -thumbHeight / 2.0 - 1.0)
                        .gesture(inDragGesture(usableWidth: usableWidth, maxTotal: maxTotal))
                }

                // Con trượt dưới (Out Duration - ‹)
                if showsOutThumb {
                    bottomThumbView(thumbWidth: thumbWidth, thumbHeight: thumbHeight)
                        .offset(x: outX - thumbWidth / 2.0, y: thumbHeight / 2.0 + 1.0)
                        .gesture(outDragGesture(usableWidth: usableWidth, maxTotal: maxTotal))
                }
            }
            .frame(width: width, height: geo.size.height)
            .contentShape(Rectangle())
        }
        .frame(height: 28)
    }

    // MARK: - Subviews & Thumbs

    private func topThumbView(thumbWidth: CGFloat, thumbHeight: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.0)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: -0.5)

            Image(systemName: "chevron.right")
                .font(.system(size: 6.5, weight: .black))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .contentShape(Rectangle())
    }

    private func bottomThumbView(thumbWidth: CGFloat, thumbHeight: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.0)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 0.5)

            Image(systemName: "chevron.left")
                .font(.system(size: 6.5, weight: .black))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Drag Gestures

    private func inDragGesture(usableWidth: CGFloat, maxTotal: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDraggingIn {
                    isDraggingIn = true
                    onEditingChanged?(true)
                }
                let touchX = gesture.location.x
                let fraction = max(0.0, min(1.0, Double(touchX / usableWidth)))
                var raw = fraction * maxTotal
                if step > 0 {
                    raw = (raw / step).rounded() * step
                }
                let maxAllowed = max(minDuration, maxTotal - outValue)
                inValue = max(minDuration, min(maxAllowed, raw))
            }
            .onEnded { _ in
                isDraggingIn = false
                onEditingChanged?(false)
            }
    }

    private func outDragGesture(usableWidth: CGFloat, maxTotal: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDraggingOut {
                    isDraggingOut = true
                    onEditingChanged?(true)
                }
                let touchFromRight = usableWidth - gesture.location.x
                let fraction = max(0.0, min(1.0, Double(touchFromRight / usableWidth)))
                var raw = fraction * maxTotal
                if step > 0 {
                    raw = (raw / step).rounded() * step
                }
                let maxAllowed = max(minDuration, maxTotal - inValue)
                outValue = max(minDuration, min(maxAllowed, raw))
            }
            .onEnded { _ in
                isDraggingOut = false
                onEditingChanged?(false)
            }
    }
}

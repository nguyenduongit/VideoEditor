import SwiftUI
import DesignSystem

/// Slider tuỳ biến hỗ trợ thanh gradient màu và ô nhập số stepper.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) và R8.1 của AGENTS.md.
public struct DSGradientSlider: View {
    private let title: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let defaultValue: Double
    private let gradient: LinearGradient?
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double> = -100.0...100.0,
        defaultValue: Double = 0.0,
        gradient: LinearGradient? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.defaultValue = defaultValue
        self.gradient = gradient
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)

            HStack(spacing: DSSpacing.sm) {
                sliderBar
                DSNumberInput(
                    value: $value,
                    step: 1.0,
                    min: range.lowerBound,
                    max: range.upperBound,
                    fractionDigits: 0,
                    customWidth: 64,
                    onEditingChanged: onEditingChanged
                )
            }
        }
    }

    private var sliderBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbRadius: CGFloat = 6.5
            let trackHeight: CGFloat = 4.0
            let usableWidth = max(1.0, width - thumbRadius * 2)
            let span = max(0.0001, range.upperBound - range.lowerBound)
            let normalized = max(0.0, min(1.0, (value - range.lowerBound) / span))
            let thumbCenter = thumbRadius + CGFloat(normalized) * usableWidth

            ZStack(alignment: .leading) {
                // Background track
                if let gradient {
                    Capsule()
                        .fill(gradient)
                        .frame(height: trackHeight)
                        .padding(.horizontal, thumbRadius)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: trackHeight)
                        .padding(.horizontal, thumbRadius)

                    Capsule()
                        .fill(Color(red: 0.12, green: 0.55, blue: 0.98))
                        .frame(width: max(0, CGFloat(normalized) * usableWidth), height: trackHeight)
                        .padding(.leading, thumbRadius)
                }

                // White circular thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: Color.black.opacity(0.4), radius: 1.5, x: 0, y: 1)
                    .offset(x: thumbCenter - thumbRadius)
            }
            .frame(width: width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        let touchX = gesture.location.x - thumbRadius
                        let fraction = max(0.0, min(1.0, Double(touchX / usableWidth)))
                        let rawValue = range.lowerBound + fraction * span
                        value = max(range.lowerBound, min(range.upperBound, round(rawValue)))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        onEditingChanged?(true)
                        value = defaultValue
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 20)
    }
}

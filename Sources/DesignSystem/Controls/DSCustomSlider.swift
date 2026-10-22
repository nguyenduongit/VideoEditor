import SwiftUI

/// Custom styled slider with bright visible track in dark mode.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSCustomSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let defaultValue: Double?
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01,
        defaultValue: Double? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbRadius: CGFloat = 7
            let trackHeight: CGFloat = 3.5
            let usableWidth = max(1.0, width - thumbRadius * 2)
            let span = max(0.0001, range.upperBound - range.lowerBound)
            let normalized = max(0.0, min(1.0, (value - range.lowerBound) / span))
            let thumbCenter = thumbRadius + CGFloat(normalized) * usableWidth

            ZStack(alignment: .leading) {
                // Background track: bright visible gray contrasting with dark background
                Capsule()
                    .fill(Color.white.opacity(0.26))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbRadius)

                // Active filled track
                Capsule()
                    .fill(Color(red: 0.12, green: 0.55, blue: 0.98))
                    .frame(width: max(0, CGFloat(normalized) * usableWidth), height: trackHeight)
                    .padding(.leading, thumbRadius)

                // White circular thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 1)
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
                        var rawValue = range.lowerBound + fraction * span
                        if step > 0 {
                            rawValue = (rawValue / step).rounded() * step
                        }
                        value = max(range.lowerBound, min(range.upperBound, rawValue))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        resetToDefault()
                    }
            )
        }
        .frame(height: 20)
    }

    private func resetToDefault() {
        guard let defaultValue else { return }
        let clamped = max(range.lowerBound, min(range.upperBound, defaultValue))
        guard value != clamped else { return }
        onEditingChanged?(true)
        value = clamped
        onEditingChanged?(false)
    }
}

import SwiftUI

/// Standard DesignSystem slider with title label, formatted value display, and drag commitment callback.
/// Complies with R6.3, R7.5, and R8.5 of AGENTS.md.
public struct DSSlider: View {
    private let title: String
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let defaultValue: Double?
    private let unit: String?
    private let onEditingChanged: ((Bool) -> Void)?

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01,
        defaultValue: Double? = nil,
        unit: String? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.unit = unit
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Text(formattedValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DSColors.textPrimary)
            }
            DSCustomSlider(
                value: $value,
                range: range,
                step: step,
                defaultValue: defaultValue,
                onEditingChanged: onEditingChanged
            )
        }
    }

    private var formattedValue: String {
        if unit == "%" {
            let percent = Int(round(value * 100))
            return "\(percent)%"
        } else if unit == "x" {
            return String(format: "%.2fx", value)
        } else if let unit {
            return "\(Int(round(value))) \(unit)"
        } else {
            return String(format: "%.2f", value)
        }
    }
}

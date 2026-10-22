import SwiftUI

/// Inspector slider row with top title, smooth horizontal slider spanning 3 columns, and compact number pill in column 4.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSSliderWithInput: View {
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
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .frame(width: DSSize.inspectorColumnWidth, alignment: .leading)

            HStack(spacing: DSSize.inspectorColumnSpacing) {
                // Slider spans 3 columns with high contrast track
                DSCustomSlider(
                    value: $value,
                    range: range,
                    step: step,
                    defaultValue: defaultValue,
                    onEditingChanged: onEditingChanged
                )

                // Value pill in Column 4
                DSNumberInput(
                    value: $value,
                    step: step,
                    min: range.lowerBound,
                    max: range.upperBound,
                    unit: unit,
                    displayMultiplier: unit == "%" ? 100.0 : 1.0,
                    onEditingChanged: onEditingChanged
                )
                .frame(width: DSSize.inspectorColumnWidth)
            }
        }
    }
}

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
    private let leadingIcon: String?
    private let isLeadingIconActive: Bool
    private let leadingIconHelp: String?
    private let isDimmed: Bool
    private let trailingAccessory: AnyView?
    private let accentColor: Color?
    private let onLeadingIconTap: (() -> Void)?
    private let onEditingChanged: ((Bool) -> Void)?

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01,
        defaultValue: Double? = nil,
        unit: String? = nil,
        accentColor: Color? = nil,
        leadingIcon: String? = nil,
        isLeadingIconActive: Bool = false,
        leadingIconHelp: String? = nil,
        isDimmed: Bool = false,
        trailingAccessory: AnyView? = nil,
        onLeadingIconTap: (() -> Void)? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.unit = unit
        self.accentColor = accentColor
        self.leadingIcon = leadingIcon
        self.isLeadingIconActive = isLeadingIconActive
        self.leadingIconHelp = leadingIconHelp
        self.isDimmed = isDimmed
        self.trailingAccessory = trailingAccessory
        self.onLeadingIconTap = onLeadingIconTap
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .frame(alignment: .leading)

            HStack(spacing: DSSize.inspectorColumnSpacing) {
                if let leadingIcon {
                    Button(action: { onLeadingIconTap?() }) {
                        Image(systemName: leadingIcon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isLeadingIconActive ? DSColors.accent : DSColors.textSecondary)
                            .frame(width: 22, height: 22)
                            .background(isLeadingIconActive ? DSColors.activeTabBackground : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help(leadingIconHelp ?? "")
                }

                // Slider spans remaining horizontal space
                DSCustomSlider(
                    value: $value,
                    range: range,
                    step: step,
                    defaultValue: defaultValue,
                    accentColor: accentColor,
                    onEditingChanged: onEditingChanged
                )
                .opacity(isDimmed ? 0.65 : 1.0)

                // Value pill
                DSNumberInput(
                    value: $value,
                    step: step,
                    min: range.lowerBound,
                    max: range.upperBound,
                    unit: unit,
                    displayMultiplier: (unit == "%" && range.upperBound <= 10.0) ? 100.0 : 1.0,
                    onEditingChanged: onEditingChanged
                )
                .frame(width: DSSize.inspectorColumnWidth)

                if let trailingAccessory {
                    trailingAccessory
                        .frame(width: 35, alignment: .center)
                }
            }
        }
    }
}

import SwiftUI

/// Bố cục Slider 2 tầng chuẩn NLE:
/// - Dòng 1: Tiêu đề bên trái.
/// - Dòng 2: Hàng điều khiển cao đúng 26pt gồm Slider (co giãn linh hoạt) + Ô nhập số 60x26pt + Nút Keyframe (nằm chính xác sau ô số).
/// Tuân thủ quy tắc R3.1 (<= 300 dòng, View body <= 80 dòng) và R8.1/R8.2 của AGENTS.md.
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
            if !title.isEmpty {
                headerRow
            }
            sliderRow
        }
    }

    private var headerRow: some View {
        HStack(spacing: DSSpacing.xs) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .frame(height: 16)
    }

    private var sliderRow: some View {
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
                customWidth: 60,
                onEditingChanged: onEditingChanged
            )
            .frame(width: 60)

            if let trailingAccessory {
                trailingAccessory
                    .frame(width: 35, alignment: .center)
            }
        }
        .frame(height: 26)
    }
}

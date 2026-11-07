import SwiftUI

/// Position row with label in column 1, X in column 2, and Y in column 3.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSPositionControl: View {
    private let title: String
    @Binding private var xValue: Double
    @Binding private var yValue: Double
    private let step: Double
    private let isXDisabled: Bool
    private let trailingAccessory: AnyView?
    private let onEditingChanged: ((Bool) -> Void)?

    public init(
        title: String = "Position",
        xValue: Binding<Double>,
        yValue: Binding<Double>,
        step: Double = 1.0,
        isXDisabled: Bool = false,
        trailingAccessory: AnyView? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._xValue = xValue
        self._yValue = yValue
        self.step = step
        self.isXDisabled = isXDisabled
        self.trailingAccessory = trailingAccessory
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: DSSize.inspectorColumnSpacing) {
            // Label in Column 1
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // X block in Column 2
            DSNumberInput(
                value: $xValue,
                step: step,
                prefix: "X",
                onEditingChanged: onEditingChanged
            )
            .disabled(isXDisabled)
            .opacity(isXDisabled ? 0.45 : 1.0)
            .help(isXDisabled ? String(localized: "Trục X đang do AI Auto Pan tự động điều khiển. Tắt Auto Pan trong tab AI để chỉnh thủ công.") : "")
            .frame(width: DSSize.inspectorColumnWidth)

            // Y block in Column 3 (aligned with Scale input below)
            DSNumberInput(
                value: $yValue,
                step: step,
                prefix: "Y",
                onEditingChanged: onEditingChanged
            )
            .frame(width: DSSize.inspectorColumnWidth)

            if let trailingAccessory {
                trailingAccessory
                    .frame(width: 35, alignment: .center)
            } else {
                Color.clear
                    .frame(width: 35, height: 18)
            }
        }
        .frame(height: 28)
    }
}

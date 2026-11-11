import SwiftUI

/// Rotation row with label in column 1, angle in column 2, and dial in column 3.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSRotationControl: View {
    private let title: String
    @Binding private var angle: Double
    private let step: Double
    private let trailingAccessory: AnyView?
    private let onEditingChanged: ((Bool) -> Void)?

    public init(
        title: String = "Rotate",
        angle: Binding<Double>,
        step: Double = 0.1,
        trailingAccessory: AnyView? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._angle = angle
        self.step = step
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

            // Angle pill in Column 2 (aligned with Position X input above)
            DSNumberInput(
                value: $angle,
                step: step,
                unit: "°",
                fractionDigits: 2,
                displayMultiplier: 1.0,
                onEditingChanged: onEditingChanged
            )
            .frame(width: DSSize.inspectorColumnWidth)

            // Circular dial in Column 3 (center-aligned with Position Y, Scale & Opacity inputs)
            DSRotationWheel(
                angle: $angle,
                onEditingChanged: onEditingChanged
            )
            .frame(width: DSSize.inspectorColumnWidth, alignment: .center)

            if let trailingAccessory {
                trailingAccessory
                    .frame(width: 35, alignment: .center)
            } else {
                Color.clear
                    .frame(width: 35, height: 18)
            }
        }
        .frame(height: 26)
    }
}

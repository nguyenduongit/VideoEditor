import SwiftUI

/// Rotation row with label in column 1, angle in column 2, and dial in column 3.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSRotationControl: View {
    private let title: String
    @Binding private var angle: Double
    private let step: Double
    private let onEditingChanged: ((Bool) -> Void)?

    public init(
        title: String = "Rotate",
        angle: Binding<Double>,
        step: Double = 0.1,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._angle = angle
        self.step = step
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: DSSize.inspectorColumnSpacing) {
            // Label in Column 1
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .frame(width: DSSize.inspectorColumnWidth, alignment: .leading)

            // Angle pill in Column 2
            DSNumberInput(
                value: $angle,
                step: step,
                unit: "°",
                fractionDigits: 2,
                displayMultiplier: 1.0,
                onEditingChanged: onEditingChanged
            )
            .frame(width: DSSize.inspectorColumnWidth)

            // Circular dial in Column 3
            DSRotationWheel(
                angle: $angle,
                onEditingChanged: onEditingChanged
            )
            .frame(width: DSSize.inspectorColumnWidth, alignment: .center)

            // Empty Column 4 placeholder for alignment
            Color.clear
                .frame(width: DSSize.inspectorColumnWidth, height: 1)
        }
        .frame(height: 28)
    }
}

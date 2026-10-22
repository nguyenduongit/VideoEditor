import SwiftUI

/// Standard DesignSystem numeric input field with direct text editing and -/+ stepper buttons.
/// Complies with R6.3, R7.5, and R8.2 of AGENTS.md: replaces heavy slider tick marks
/// with lightweight numeric inputs for coordinates and dimensions.
public struct DSNumberField: View {
    private let title: String
    @Binding private var value: Double
    private let step: Double
    private let unit: String?
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var textValue: String = ""

    public init(
        title: String,
        value: Binding<Double>,
        step: Double = 1.0,
        unit: String? = "px",
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.step = step
        self.unit = unit
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)

            Spacer()

            HStack(spacing: DSSpacing.xs) {
                Button(action: decrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DSColors.textSecondary)
                        .frame(width: 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                TextField("", text: $textValue, onCommit: commitText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DSColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)

                if let unit {
                    Text(unit)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                }

                Button(action: increment) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DSColors.textSecondary)
                        .frame(width: 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, 2)
            .background(DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
            )
        }
        .onAppear {
            syncText()
        }
        .onChange(of: value) {
            syncText()
        }
    }

    private func syncText() {
        let rounded = Int(round(value))
        textValue = "\(rounded)"
    }

    private func commitText() {
        if let parsed = Double(textValue.trimmingCharacters(in: .whitespaces)) {
            value = parsed
            onEditingChanged?(true)
            onEditingChanged?(false)
        } else {
            syncText()
        }
    }

    private func decrement() {
        value -= step
        onEditingChanged?(true)
        onEditingChanged?(false)
    }

    private func increment() {
        value += step
        onEditingChanged?(true)
        onEditingChanged?(false)
    }
}

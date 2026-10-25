import SwiftUI

/// Compact dark pill input with prefix, value, unit, and integrated button-style stepper.
/// Supports clicking stepper buttons, scrubbing drag, or direct text editing.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSNumberInput: View {
    @Binding private var value: Double
    private let step: Double
    private let min: Double?
    private let max: Double?
    private let unit: String?
    private let prefix: String?
    private let fractionDigits: Int
    private let displayMultiplier: Double
    private let customWidth: CGFloat?
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isEditingText = false
    @State private var textInput = ""
    @State private var dragStartValue: Double?
    @State private var isHovered = false
    @State private var isHoveredUp = false
    @State private var isHoveredDown = false
    @State private var isPressingUp = false
    @State private var isPressingDown = false
    @State private var holdTask: Task<Void, Never>?
    @FocusState private var isFieldFocused: Bool

    public init(
        value: Binding<Double>,
        step: Double = 1.0,
        min: Double? = nil,
        max: Double? = nil,
        unit: String? = nil,
        prefix: String? = nil,
        fractionDigits: Int? = nil,
        displayMultiplier: Double? = nil,
        customWidth: CGFloat? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.step = step
        self.min = min
        self.max = max
        self.unit = unit
        self.prefix = prefix
        self.customWidth = customWidth
        self.displayMultiplier = displayMultiplier ?? (unit == "%" ? 100.0 : 1.0)
        if let fractionDigits {
            self.fractionDigits = fractionDigits
        } else if unit == "%" {
            self.fractionDigits = 0
        } else if unit == "°" {
            self.fractionDigits = 2
        } else if step < 0.1 {
            self.fractionDigits = 2
        } else if step < 1.0 {
            self.fractionDigits = 1
        } else {
            self.fractionDigits = 0
        }
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                    .padding(.leading, DSSpacing.xs)
            } else {
                Spacer()
                    .frame(width: DSSpacing.xs)
            }

            valueDisplayArea
                .frame(maxWidth: .infinity, alignment: .center)

            stepperButton
                .padding(.trailing, 2)
        }
        .frame(width: customWidth ?? DSSize.inspectorColumnWidth, height: 26)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(isHovered ? Color.white.opacity(0.18) : DSColors.inputBorder, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var valueDisplayArea: some View {
        if isEditingText {
            TextField("", text: $textInput)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DSColors.textPrimary)
                .multilineTextAlignment(.center)
                .focused($isFieldFocused)
                .onSubmit { commitText() }
                .onExitCommand { cancelTextEditing() }
                .onChange(of: isFieldFocused) { _, focused in
                    if !focused && isEditingText {
                        commitText()
                    }
                }
                .onAppear {
                    isFieldFocused = true
                }
        } else {
            Text(formattedValue)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            beginTextEditing()
                        }
                )
                .simultaneousGesture(scrubGesture)
        }
    }

    private var stepperButton: some View {
        VStack(spacing: 0) {
            stepperChevron(
                systemName: "chevron.up",
                isHovered: isHoveredUp,
                isPressing: isPressingUp
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressingUp {
                            isPressingUp = true
                            startContinuousHold(delta: step)
                        }
                    }
                    .onEnded { _ in
                        isPressingUp = false
                        stopContinuousHold()
                    }
            )
            .onHover { isHoveredUp = $0 }

            stepperChevron(
                systemName: "chevron.down",
                isHovered: isHoveredDown,
                isPressing: isPressingDown
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressingDown {
                            isPressingDown = true
                            startContinuousHold(delta: -step)
                        }
                    }
                    .onEnded { _ in
                        isPressingDown = false
                        stopContinuousHold()
                    }
            )
            .onHover { isHoveredDown = $0 }
        }
        .frame(width: 18, height: 21)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3.5))
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .onDisappear {
            stopContinuousHold()
        }
    }

    private func stepperChevron(
        systemName: String,
        isHovered: Bool,
        isPressing: Bool
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(isHovered || isPressing ? Color.white : Color.white.opacity(0.75))
            .frame(width: 18, height: 10)
            .background(
                isPressing ? Color.white.opacity(0.24) : (isHovered ? Color.white.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { gesture in
                if dragStartValue == nil {
                    dragStartValue = value
                    onEditingChanged?(true)
                }
                let base = dragStartValue ?? value
                let delta = gesture.translation.width * (step / displayMultiplier)
                updateClamped(base + delta)
            }
            .onEnded { _ in
                dragStartValue = nil
                onEditingChanged?(false)
            }
    }

    private func startContinuousHold(delta: Double) {
        onEditingChanged?(true)
        updateClamped(value + delta)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                while !Task.isCancelled {
                    updateClamped(value + delta)
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
            } catch {
                // Task cancelled when user releases the stepper button
            }
        }
    }

    private func stopContinuousHold() {
        holdTask?.cancel()
        holdTask = nil
        onEditingChanged?(false)
    }

    private func updateClamped(_ newValue: Double) {
        var v = newValue
        if step > 0 {
            v = (v / step).rounded() * step
        }
        if let min { v = Swift.max(min, v) }
        if let max { v = Swift.min(max, v) }
        value = v
    }

    private var formattedValue: String {
        let displayed = value * displayMultiplier
        let numStr = String(format: "%.\(fractionDigits)f", displayed)
        if let unit {
            return "\(numStr)\(unit)"
        }
        return numStr
    }

    private func beginTextEditing() {
        let displayed = value * displayMultiplier
        textInput = String(format: "%.\(fractionDigits)f", displayed)
        isEditingText = true
        isFieldFocused = true
    }

    private func cancelTextEditing() {
        isEditingText = false
        isFieldFocused = false
    }

    private func commitText() {
        guard isEditingText else { return }
        isEditingText = false
        isFieldFocused = false
        if let parsed = Double(textInput.trimmingCharacters(in: .whitespaces)) {
            onEditingChanged?(true)
            updateClamped(parsed / displayMultiplier)
            onEditingChanged?(false)
        }
    }
}

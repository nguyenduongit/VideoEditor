import SwiftUI
import Domain
import DesignSystem

/// Khối thanh trượt đáy Inspector cho Text Animation chuẩn phong cách CapCut.
/// Hỗ trợ thanh trượt đôi cho Hoạt ảnh Vào (In) & Ra (Out), và thanh đơn cho Vòng lặp (Loop).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng).
public struct TextAnimationSlidersView: View {
    public let selectedSubTab: TextAnimationTabContent.AnimationSubTab
    @Binding public var config: TextConfiguration
    public let clipDuration: Double
    public let onCommit: (TextConfiguration) -> Void
    public let onUpdateLive: (TextConfiguration) -> Void
    public let onEditingEnded: (Bool) -> Void

    public init(
        selectedSubTab: TextAnimationTabContent.AnimationSubTab,
        config: Binding<TextConfiguration>,
        clipDuration: Double = 3.0,
        onCommit: @escaping (TextConfiguration) -> Void,
        onUpdateLive: @escaping (TextConfiguration) -> Void,
        onEditingEnded: @escaping (Bool) -> Void
    ) {
        self.selectedSubTab = selectedSubTab
        self._config = config
        self.clipDuration = max(0.5, clipDuration)
        self.onCommit = onCommit
        self.onUpdateLive = onUpdateLive
        self.onEditingEnded = onEditingEnded
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if selectedSubTab == .loopAnimation {
                loopSpeedControlRow
            } else {
                dualDurationControlRow
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    // MARK: - Dual Duration Row (In & Out)

    private var isDualActive: Bool {
        config.animation.inType != .none && config.animation.outType != .none
    }

    private var dualDurationControlRow: some View {
        HStack(spacing: DSSpacing.xs) {
            Text(String(localized: "Duration"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 48, alignment: .leading)

            if selectedSubTab == .inAnimation || isDualActive {
                inDurationInput
            }

            DSDualSlider(
                inValue: inDurationBinding,
                outValue: outDurationBinding,
                totalDuration: clipDuration,
                minDuration: 0.1,
                step: 0.05,
                showsInThumb: config.animation.inType != .none,
                showsOutThumb: config.animation.outType != .none,
                onEditingChanged: onEditingEnded
            )

            if selectedSubTab == .outAnimation || isDualActive {
                outDurationInput
            }
        }
    }

    private var inDurationInput: some View {
        let maxOut = config.animation.outType == .none ? 0.0 : config.animation.outDuration
        return DSNumberInput(
            value: inDurationBinding,
            step: 0.05,
            min: 0.1,
            max: max(0.1, clipDuration - maxOut),
            unit: "s",
            fractionDigits: 2,
            customWidth: 52,
            onEditingChanged: onEditingEnded
        )
    }

    private var outDurationInput: some View {
        let maxIn = config.animation.inType == .none ? 0.0 : config.animation.inDuration
        return DSNumberInput(
            value: outDurationBinding,
            step: 0.05,
            min: 0.1,
            max: max(0.1, clipDuration - maxIn),
            unit: "s",
            fractionDigits: 2,
            customWidth: 52,
            onEditingChanged: onEditingEnded
        )
    }

    // MARK: - Loop Speed Row

    private var loopSpeedControlRow: some View {
        HStack(spacing: DSSpacing.xs) {
            Text(String(localized: "Speed"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 48, alignment: .leading)

            DSCustomSlider(
                value: loopSpeedBinding,
                range: 0.2...4.0,
                step: 0.1,
                defaultValue: 1.0,
                onEditingChanged: onEditingEnded
            )

            DSNumberInput(
                value: loopSpeedBinding,
                step: 0.1,
                min: 0.2,
                max: 4.0,
                unit: "x",
                fractionDigits: 1,
                customWidth: 52,
                onEditingChanged: onEditingEnded
            )
        }
    }

    // MARK: - Bindings & Mutators

    private var inDurationBinding: Binding<Double> {
        Binding(
            get: { config.animation.inDuration },
            set: { val in
                let maxOut = config.animation.outType == .none ? 0.0 : config.animation.outDuration
                let maxAllowed = max(0.1, clipDuration - maxOut)
                let clamped = max(0.1, min(maxAllowed, val))
                mutate { $0.animation.inDuration = (clamped * 100).rounded() / 100 }
            }
        )
    }

    private var outDurationBinding: Binding<Double> {
        Binding(
            get: { config.animation.outDuration },
            set: { val in
                let maxIn = config.animation.inType == .none ? 0.0 : config.animation.inDuration
                let maxAllowed = max(0.1, clipDuration - maxIn)
                let clamped = max(0.1, min(maxAllowed, val))
                mutate { $0.animation.outDuration = (clamped * 100).rounded() / 100 }
            }
        )
    }

    private var loopSpeedBinding: Binding<Double> {
        Binding(
            get: { config.animation.loopSpeed },
            set: { val in
                let clamped = max(0.2, min(4.0, val))
                mutate { $0.animation.loopSpeed = (clamped * 10).rounded() / 10 }
            }
        )
    }

    private func mutate(_ block: (inout TextConfiguration) -> Void) {
        var c = config
        block(&c)
        onUpdateLive(c)
    }
}

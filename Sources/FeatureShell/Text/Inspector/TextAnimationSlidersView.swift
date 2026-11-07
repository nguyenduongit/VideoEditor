import SwiftUI
import Domain
import DesignSystem

/// Thanh trượt `Duration` hợp nhất duy nhất cho cả 3 pha `In`, `Out` và `Loop`.
/// - Kéo con trượt trái (`›` - Cyan) hoặc nhập số để chỉnh thời lượng `In`.
/// - Kéo con trượt phải (`‹` - Amber) hoặc nhập số để chỉnh thời lượng `Out`.
/// - Phần thời gian còn lại ở giữa (`clipDuration - inDuration - outDuration`) tự động là thời lượng của `Loop` (màu Mint Green).
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
            Text("Duration")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 48, alignment: .leading)

            if config.animation.hasInAnimation {
                inDurationInput
            }

            DSDualSlider(
                inValue: inDurationBinding,
                outValue: outDurationBinding,
                totalDuration: clipDuration,
                minDuration: 0.1,
                step: 0.05,
                showsInThumb: config.animation.hasInAnimation,
                showsOutThumb: config.animation.hasOutAnimation,
                showsLoopSegment: config.animation.hasLoopAnimation,
                onEditingChanged: onEditingEnded
            )

            if config.animation.hasOutAnimation {
                outDurationInput
            } else if !config.animation.hasInAnimation && config.animation.hasLoopAnimation {
                loopRemainingBadge
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    // MARK: - Inputs & Badges

    private var inDurationInput: some View {
        let maxOut = config.animation.hasOutAnimation ? config.animation.outDuration : 0.0
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
        let maxIn = config.animation.hasInAnimation ? config.animation.inDuration : 0.0
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

    private var loopRemainingBadge: some View {
        let inDur = config.animation.hasInAnimation ? config.animation.inDuration : 0.0
        let outDur = config.animation.hasOutAnimation ? config.animation.outDuration : 0.0
        let remaining = max(0.0, clipDuration - inDur - outDur)
        return Text(String(format: "%.2fs", remaining))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(DSColors.textSecondary)
            .frame(width: 52, height: 22)
            .background(DSColors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
    }

    // MARK: - Bindings

    private var inDurationBinding: Binding<Double> {
        Binding(
            get: { config.animation.inDuration },
            set: { val in
                let maxOut = config.animation.hasOutAnimation ? config.animation.outDuration : 0.0
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
                let maxIn = config.animation.hasInAnimation ? config.animation.inDuration : 0.0
                let maxAllowed = max(0.1, clipDuration - maxIn)
                let clamped = max(0.1, min(maxAllowed, val))
                mutate { $0.animation.outDuration = (clamped * 100).rounded() / 100 }
            }
        )
    }

    private func mutate(_ block: (inout TextConfiguration) -> Void) {
        var c = config
        block(&c)
        onUpdateLive(c)
    }
}

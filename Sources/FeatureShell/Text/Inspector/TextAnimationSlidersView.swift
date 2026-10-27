import SwiftUI
import Domain
import DesignSystem

/// Khối điều khiển các thanh trượt thời lượng, gia tốc và hiệu ứng đồ họa cho Text Animation.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R4.3 (đơn nhiệm).
public struct TextAnimationSlidersView: View {
    public let selectedSubTab: TextAnimationTabContent.AnimationSubTab
    @Binding public var config: TextConfiguration
    public let onCommit: (TextConfiguration) -> Void
    public let onUpdateLive: (TextConfiguration) -> Void
    public let onEditingEnded: (Bool) -> Void

    public init(
        selectedSubTab: TextAnimationTabContent.AnimationSubTab,
        config: Binding<TextConfiguration>,
        onCommit: @escaping (TextConfiguration) -> Void,
        onUpdateLive: @escaping (TextConfiguration) -> Void,
        onEditingEnded: @escaping (Bool) -> Void
    ) {
        self.selectedSubTab = selectedSubTab
        self._config = config
        self.onCommit = onCommit
        self.onUpdateLive = onUpdateLive
        self.onEditingEnded = onEditingEnded
    }

    @State private var isAdvancedExpanded: Bool = false

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            tabSpecificSliders
            advancedSection
        }
    }

    @ViewBuilder
    private var tabSpecificSliders: some View {
        switch selectedSubTab {
        case .inAnimation:
            DSSliderWithInput(
                title: "In Duration",
                value: Binding(get: { config.animation.inDuration }, set: { val in mutate { $0.animation.inDuration = val } }),
                range: 0.1...3.0, step: 0.05, defaultValue: 0.5, unit: "s",
                onEditingChanged: onEditingEnded
            )
        case .outAnimation:
            DSSliderWithInput(
                title: "Out Duration",
                value: Binding(get: { config.animation.outDuration }, set: { val in mutate { $0.animation.outDuration = val } }),
                range: 0.1...3.0, step: 0.05, defaultValue: 0.5, unit: "s",
                onEditingChanged: onEditingEnded
            )
        case .loopAnimation:
            DSSliderWithInput(
                title: "Loop Speed",
                value: Binding(get: { config.animation.loopSpeed }, set: { val in mutate { $0.animation.loopSpeed = val } }),
                range: 0.2...4.0, step: 0.1, defaultValue: 1.0, unit: "x",
                onEditingChanged: onEditingEnded
            )
        }
    }

    private var advancedSection: some View {
        VStack(spacing: DSSpacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAdvancedExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Nâng cao")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary)
                    Image(systemName: isAdvancedExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(DSColors.textSecondary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if isAdvancedExpanded {
                VStack(spacing: DSSpacing.xs) {
                    if selectedSubTab == .inAnimation && config.animation.inType == .typewriter1 {
                        DSToggleRow(title: "Hiển thị con trỏ (|)", isOn: Binding(
                            get: { config.animation.isTypewriterCursorVisible },
                            set: { val in var c = config; c.animation.isTypewriterCursorVisible = val; onCommit(c) }
                        ))
                    }
                    if selectedSubTab != .loopAnimation {
                        easingSelectorRow
                    }
                    if !config.animation.isDefault {
                        TextAnimationTimelineBarView(config: config, onCommit: onCommit)
                    }
                    scopeAndStaggerSection
                    vfxSlidersSection
                }
            }
        }
    }

    @ViewBuilder
    private var scopeAndStaggerSection: some View {
        let hasActiveAnim = config.animation.inType != .none || config.animation.outType != .none
        if hasActiveAnim {
            VStack(spacing: DSSpacing.xs) {
                scopeSelectorRow
                if config.animation.scope != .wholeBlock {
                    DSSliderWithInput(
                        title: "Stagger Delay",
                        value: Binding(get: { config.animation.staggerDelay }, set: { val in mutate { $0.animation.staggerDelay = val } }),
                        range: 0.01...0.15, step: 0.005, defaultValue: 0.04, unit: "s",
                        onEditingChanged: onEditingEnded
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var vfxSlidersSection: some View {
        if !config.animation.isDefault {
            VStack(spacing: DSSpacing.xs) {
                DSSliderWithInput(
                    title: "RGB Split (Glitch)",
                    value: Binding(get: { config.animation.rgbSplitIntensity }, set: { val in mutate { $0.animation.rgbSplitIntensity = val } }),
                    range: 0.0...15.0, step: 0.5, defaultValue: 0.0, unit: "px",
                    onEditingChanged: onEditingEnded
                )
                DSSliderWithInput(
                    title: "Light Sweep (Shimmer)",
                    value: Binding(get: { config.animation.lightSweepIntensity }, set: { val in mutate { $0.animation.lightSweepIntensity = val } }),
                    range: 0.0...1.0, step: 0.05, defaultValue: 0.0, unit: "",
                    onEditingChanged: onEditingEnded
                )
                DSToggleRow(title: "Directional Motion Blur", isOn: Binding(
                    get: { config.animation.isMotionBlurEnabled },
                    set: { val in var c = config; c.animation.isMotionBlurEnabled = val; onCommit(c) }
                ))
                DSToggleRow(title: "Mask Clip Box", isOn: Binding(
                    get: { config.animation.isMaskEnabled },
                    set: { val in var c = config; c.animation.isMaskEnabled = val; onCommit(c) }
                ))
            }
        }
    }

    private var scopeSelectorRow: some View {
        HStack(spacing: DSSpacing.xs) {
            Text("Phạm vi")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(TextAnimationScope.allCases) { scope in
                    Button {
                        var c = config; c.animation.scope = scope; onCommit(c)
                    } label: {
                        Text(scope.title)
                            .font(.system(size: 10, weight: config.animation.scope == scope ? .semibold : .regular))
                            .foregroundStyle(config.animation.scope == scope ? DSColors.textPrimary : DSColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(config.animation.scope == scope ? DSColors.activeTabBackground : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var easingSelectorRow: some View {
        HStack(spacing: DSSpacing.xs) {
            Text("Easing")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(TextMotionEasing.allCases) { easing in
                    Button {
                        var c = config; c.animation.motionEasing = easing; onCommit(c)
                    } label: {
                        Text(easing.rawValue)
                            .font(.system(size: 10, weight: config.animation.motionEasing == easing ? .semibold : .regular))
                            .foregroundStyle(config.animation.motionEasing == easing ? DSColors.textPrimary : DSColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(config.animation.motionEasing == easing ? DSColors.activeTabBackground : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mutate(_ block: (inout TextConfiguration) -> Void) {
        var c = config
        block(&c)
        onUpdateLive(c)
    }
}

import SwiftUI
import Domain
import DesignSystem

/// Grid hiển thị danh sách thẻ lựa chọn hoạt ảnh (In, Out, Loop, Combo) kèm mô phỏng trực tiếp.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R4.3 (đơn nhiệm).
public struct TextAnimationCardsGrid: View {
    public let selectedSubTab: TextAnimationTabContent.AnimationSubTab
    public let config: TextConfiguration
    public let onSelectIn: (TextInAnimationType) -> Void
    public let onSelectOut: (TextOutAnimationType) -> Void
    public let onSelectLoop: (TextLoopAnimationType) -> Void
    public let onSelectCombo: (TextComboAnimationType) -> Void

    public init(
        selectedSubTab: TextAnimationTabContent.AnimationSubTab,
        config: TextConfiguration,
        onSelectIn: @escaping (TextInAnimationType) -> Void,
        onSelectOut: @escaping (TextOutAnimationType) -> Void,
        onSelectLoop: @escaping (TextLoopAnimationType) -> Void,
        onSelectCombo: @escaping (TextComboAnimationType) -> Void
    ) {
        self.selectedSubTab = selectedSubTab
        self.config = config
        self.onSelectIn = onSelectIn
        self.onSelectOut = onSelectOut
        self.onSelectLoop = onSelectLoop
        self.onSelectCombo = onSelectCombo
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: DSSpacing.xs)],
                spacing: DSSpacing.xs
            ) {
                switch selectedSubTab {
                case .inAnimation:
                    ForEach(TextInAnimationType.allCases) { item in
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: config.animation.inType == item,
                            previewConfig: makePreviewConfig(inType: item)
                        ) {
                            onSelectIn(item)
                        }
                    }
                case .outAnimation:
                    ForEach(TextOutAnimationType.allCases) { item in
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: config.animation.outType == item,
                            previewConfig: makePreviewConfig(outType: item)
                        ) {
                            onSelectOut(item)
                        }
                    }
                case .loopAnimation:
                    ForEach(TextLoopAnimationType.allCases) { item in
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: config.animation.loopType == item,
                            previewConfig: makePreviewConfig(loopType: item)
                        ) {
                            onSelectLoop(item)
                        }
                    }
                case .comboAnimation:
                    ForEach(TextComboAnimationType.allCases) { item in
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: config.animation.comboType == item,
                            previewConfig: makePreviewConfig(comboType: item)
                        ) {
                            onSelectCombo(item)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(maxHeight: 270)
    }

    // MARK: - Preview Config Helpers

    private func makePreviewConfig(
        inType: TextInAnimationType = .none,
        outType: TextOutAnimationType = .none,
        loopType: TextLoopAnimationType = .none,
        comboType: TextComboAnimationType = .none
    ) -> TextConfiguration {
        var sample = TextConfiguration(content: "Aa", fontSize: 16.0, isBold: true)
        sample.animation = TextAnimationConfiguration(
            inType: inType,
            inDuration: 1.1,
            outType: outType,
            outDuration: 1.1,
            loopType: loopType,
            loopSpeed: 1.4,
            comboType: comboType,
            motionEasing: config.animation.motionEasing
        )
        return sample
    }
}

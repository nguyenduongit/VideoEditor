import SwiftUI
import Domain
import DesignSystem

/// Grid hiển thị danh sách thẻ lựa chọn hoạt ảnh tinh tuyển (Vào, Ra, Vòng lặp) kèm mô phỏng trực tiếp.
/// Thiết kế tinh giản chuẩn CapCut: không phân mảnh category rườm rà, tập trung chất lượng cao từng thẻ.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R4.3 (đơn nhiệm).
public struct TextAnimationCardsGrid: View {
    public let selectedSubTab: TextAnimationTabContent.AnimationSubTab
    public let config: TextConfiguration
    public let onSelectIn: (TextInAnimationType) -> Void
    public let onSelectOut: (TextOutAnimationType) -> Void
    public let onSelectLoop: (TextLoopAnimationType) -> Void

    public init(
        selectedSubTab: TextAnimationTabContent.AnimationSubTab,
        config: TextConfiguration,
        onSelectIn: @escaping (TextInAnimationType) -> Void,
        onSelectOut: @escaping (TextOutAnimationType) -> Void,
        onSelectLoop: @escaping (TextLoopAnimationType) -> Void
    ) {
        self.selectedSubTab = selectedSubTab
        self.config = config
        self.onSelectIn = onSelectIn
        self.onSelectOut = onSelectOut
        self.onSelectLoop = onSelectLoop
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 82), spacing: DSSpacing.xs)],
                spacing: DSSpacing.xs
            ) {
                switch selectedSubTab {
                case .inAnimation:
                    ForEach(TextInAnimationType.allCases) { item in
                        let isSelected = config.animation.inType == item
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: isSelected,
                            previewConfig: makePreviewConfig(inType: item)
                        ) {
                            onSelectIn(item)
                        }
                        .id("in-\(item.rawValue)-\(isSelected)")
                    }
                case .outAnimation:
                    ForEach(TextOutAnimationType.allCases) { item in
                        let isSelected = config.animation.outType == item
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: isSelected,
                            previewConfig: makePreviewConfig(outType: item)
                        ) {
                            onSelectOut(item)
                        }
                        .id("out-\(item.rawValue)-\(isSelected)")
                    }
                case .loopAnimation:
                    ForEach(TextLoopAnimationType.allCases) { item in
                        let isSelected = config.animation.loopType == item
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: isSelected,
                            previewConfig: makePreviewConfig(loopType: item)
                        ) {
                            onSelectLoop(item)
                        }
                        .id("loop-\(item.rawValue)-\(isSelected)")
                    }
                }
            }
            .id("\(selectedSubTab.rawValue)-\(config.animation.inType.rawValue)-\(config.animation.outType.rawValue)-\(config.animation.loopType.rawValue)")
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.xs)
            .padding(.bottom, DSSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview Config Helpers

    private func makePreviewConfig(
        inType: TextInAnimationType = .none,
        outType: TextOutAnimationType = .none,
        loopType: TextLoopAnimationType = .none
    ) -> TextConfiguration {
        var sample = TextConfiguration(content: "Aa", fontSize: 16.0, isBold: true)
        sample.animation = TextAnimationConfiguration(
            inType: inType,
            inDuration: 1.0,
            outType: outType,
            outDuration: 1.0,
            loopType: loopType,
            loopSpeed: 1.2,
            motionEasing: config.animation.motionEasing
        )
        return sample
    }
}

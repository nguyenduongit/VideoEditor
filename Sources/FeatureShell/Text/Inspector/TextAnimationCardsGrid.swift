import SwiftUI
import Domain
import DesignSystem

/// Grid hiển thị danh sách thẻ lựa chọn hoạt ảnh (Vào, Ra, Vòng lặp) kèm bộ lọc danh mục và mô phỏng trực tiếp.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R4.3 (đơn nhiệm).
public struct TextAnimationCardsGrid: View {
    public let selectedSubTab: TextAnimationTabContent.AnimationSubTab
    public let config: TextConfiguration
    public let onSelectIn: (TextInAnimationType) -> Void
    public let onSelectOut: (TextOutAnimationType) -> Void
    public let onSelectLoop: (TextLoopAnimationType) -> Void

    @State private var selectedInCat: TextInAnimationCategory = .all
    @State private var selectedOutCat: TextOutAnimationCategory = .all
    @State private var selectedLoopCat: TextLoopAnimationCategory = .all

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
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            categoryChipsRow
                .padding(.horizontal, DSSpacing.md)

            cardsScrollView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category Filter Chips

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                switch selectedSubTab {
                case .inAnimation:
                    ForEach(TextInAnimationCategory.allCases) { cat in
                        categoryChip(title: cat.rawValue, isSelected: selectedInCat == cat) {
                            selectedInCat = cat
                        }
                    }
                case .outAnimation:
                    ForEach(TextOutAnimationCategory.allCases) { cat in
                        categoryChip(title: cat.rawValue, isSelected: selectedOutCat == cat) {
                            selectedOutCat = cat
                        }
                    }
                case .loopAnimation:
                    ForEach(TextLoopAnimationCategory.allCases) { cat in
                        categoryChip(title: cat.rawValue, isSelected: selectedLoopCat == cat) {
                            selectedLoopCat = cat
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 24)
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isSelected ? DSColors.activeTabBackground : Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .stroke(isSelected ? DSColors.toggleCyan.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cards ScrollView

    private var cardsScrollView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: DSSpacing.xs)],
                spacing: DSSpacing.xs
            ) {
                switch selectedSubTab {
                case .inAnimation:
                    ForEach(filteredInAnimations) { item in
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
                    ForEach(filteredOutAnimations) { item in
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
                    ForEach(filteredLoopAnimations) { item in
                        TextAnimationPreviewCardView(
                            title: item.rawValue,
                            iconName: item.iconName,
                            isSelected: config.animation.loopType == item,
                            previewConfig: makePreviewConfig(loopType: item)
                        ) {
                            onSelectLoop(item)
                        }
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, 2)
            .padding(.bottom, DSSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filter Helpers

    private var filteredInAnimations: [TextInAnimationType] {
        if selectedInCat == .all {
            return TextInAnimationType.allCases
        }
        return [TextInAnimationType.none] + TextInAnimationType.allCases.filter { $0.category == selectedInCat }
    }

    private var filteredOutAnimations: [TextOutAnimationType] {
        if selectedOutCat == .all {
            return TextOutAnimationType.allCases
        }
        return [TextOutAnimationType.none] + TextOutAnimationType.allCases.filter { $0.category == selectedOutCat }
    }

    private var filteredLoopAnimations: [TextLoopAnimationType] {
        if selectedLoopCat == .all {
            return TextLoopAnimationType.allCases
        }
        return [TextLoopAnimationType.none] + TextLoopAnimationType.allCases.filter { $0.category == selectedLoopCat }
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
            inDuration: 1.1,
            outType: outType,
            outDuration: 1.1,
            loopType: loopType,
            loopSpeed: 1.4,
            motionEasing: config.animation.motionEasing
        )
        return sample
    }
}

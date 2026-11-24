import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector hợp nhất cho Module `Text` (1 Lõi Đơn Dòng · 4 Tab: `Text`, `Color`, `Background`, `Animation`).
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, Ubiquitous Language, Hàm <= 50 dòng, Body <= 40 dòng).
public struct TextInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.effectiveTab {
        case "Appearance", "Color":
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextColorTabContent(viewModel: viewModel)
                    .padding(.horizontal, DSSize.inspectorContentPadding)
                    .padding(.vertical, DSSize.inspectorContentPadding)
            }
        case "Animation":
            TextAnimationTabContent(viewModel: viewModel)
        case "Background":
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextBackgroundTabContent(viewModel: viewModel)
                    .padding(.horizontal, DSSize.inspectorContentPadding)
                    .padding(.vertical, DSSize.inspectorContentPadding)
            }
        default:
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextBasicSectionView(viewModel: viewModel)
                    .padding(.horizontal, DSSize.inspectorContentPadding)
                    .padding(.vertical, DSSize.inspectorContentPadding)
            }
        }
    }
}

// MARK: - Subview nội bộ: Tab cơ bản (Text Basic & Typography & Transform)

public struct TextBasicSectionView: View {
    @Bindable var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TextContentAndTypographySection(viewModel: viewModel)
            TextTransformSectionView(viewModel: viewModel)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// Tương thích ngược với tên gọi cũ
public typealias TextBasicTabContent = TextBasicSectionView

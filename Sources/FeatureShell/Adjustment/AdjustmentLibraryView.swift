import SwiftUI
import Domain
import DesignSystem

/// View thư viện Adjustment Layer bên sidebar trái.
/// Gồm 2 tab: "Mặc định" (1 item trung tính) và "Templates" (hệ thống JSON script đa danh mục).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentLibraryView: View {
    @Bindable private var viewModel: AdjustmentLibraryViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 95, maximum: 125), spacing: DSSpacing.md)
    ]

    public init(viewModel: AdjustmentLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            subTabBar
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
            if viewModel.selectedSubTab == .templates {
                categoryFilterBar
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.bottom, DSSpacing.sm)
            }
            Divider()
                .background(DSColors.blockBorder)
            contentScrollView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    private var subTabBar: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(AdjustmentLibraryViewModel.SubTab.allCases, id: \.self) { tab in
                Button(action: {
                    viewModel.selectedSubTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: viewModel.selectedSubTab == tab ? .semibold : .regular))
                        .foregroundStyle(viewModel.selectedSubTab == tab ? DSColors.textPrimary : DSColors.textSecondary)
                        .padding(.vertical, DSSpacing.xs)
                        .padding(.horizontal, DSSpacing.md)
                        .background(
                            viewModel.selectedSubTab == tab ? DSColors.windowBackground : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if viewModel.selectedSubTab == .templates {
                Button(action: { viewModel.reloadTemplates() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Tải lại JSON Adjustment Templates")
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AdjustmentTemplateCategory.allCases, id: \.self) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button(action: {
                        viewModel.selectedCategory = category
                    }) {
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : DSColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? DSColors.accent : DSColors.windowBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            if viewModel.selectedSubTab == .default {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    AdjustmentCardItemView(preset: viewModel.defaultPreset) {
                        viewModel.addPresetToTimeline(viewModel.defaultPreset)
                    }
                }
                .padding(DSSpacing.md)
            } else if viewModel.filteredTemplatePresets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(viewModel.filteredTemplatePresets) { preset in
                        AdjustmentCardItemView(
                            preset: preset,
                            onAdd: { viewModel.addPresetToTimeline(preset) },
                            onDelete: { viewModel.deletePreset(preset) }
                        )
                    }
                }
                .padding(DSSpacing.md)
            }
        }
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("Chưa có Preset nào")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Text("Tùy chỉnh màu sắc trong Inspector và bấm\n\"Lưu thành Preset\" để lưu lên Supabase.")
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

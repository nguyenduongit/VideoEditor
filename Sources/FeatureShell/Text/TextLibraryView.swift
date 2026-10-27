import SwiftUI
import Domain
import DesignSystem

/// View thư viện Text bên sidebar trái.
/// Gồm 2 subtab: "Mặc định" và "Templates" (hỗ trợ lọc theo danh mục JSON Script & đồng bộ Supabase).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextLibraryView: View {
    @Bindable private var viewModel: TextLibraryViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 128), spacing: DSSpacing.md)
    ]

    public init(viewModel: TextLibraryViewModel) {
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
            ForEach(TextLibraryViewModel.SubTab.allCases, id: \.self) { tab in
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
                Button {
                    viewModel.reloadTemplates()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DSColors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DSColors.windowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
                .help("Nạp lại kịch bản JSON Templates")
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TextTemplateCategory.allCases) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? DSColors.activeTabBackground : DSColors.windowBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? DSColors.toggleCyan.opacity(0.75) : DSColors.blockBorder, lineWidth: 0.8)
                            )
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
                    TextCardItemView(preset: viewModel.defaultPreset) {
                        viewModel.addPresetToTimeline(viewModel.defaultPreset)
                    }
                }
                .padding(DSSpacing.md)
            } else if viewModel.filteredTemplatePresets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(viewModel.filteredTemplatePresets) { preset in
                        TextCardItemView(
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
            Text("Tùy chỉnh kiểu chữ trong Inspector và bấm\n\"Lưu thành Preset\" để lưu lên Supabase.")
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

import SwiftUI
import Domain
import DesignSystem

/// View thư viện Adjustment Layer bên sidebar trái.
/// Gồm 2 tab: "Mặc định" (1 item trung tính) và "Templates" (hệ thống JSON script đa danh mục).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentLibraryView: View {
    @Bindable private var viewModel: AdjustmentLibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: AdjustmentLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Tìm kiếm mẫu màu...",
            categories: AdjustmentTemplateCategory.allCases.map(\.rawValue),
            selectedCategory: categoryBinding,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
    }

    private var categoryBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedCategory.rawValue },
            set: { val in
                if let cat = AdjustmentTemplateCategory(rawValue: val) {
                    viewModel.selectedCategory = cat
                }
            }
        )
    }

    private var reloadButton: some View {
        Button(action: { viewModel.reloadTemplates() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 24, height: 24)
                .background(DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        }
        .buttonStyle(.plain)
        .help(String(localized: "Tải lại JSON Adjustment Templates"))
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = viewModel.filteredPresetsWithDefaultFirst
            if presets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(presets) { preset in
                        AdjustmentCardItemView(
                            preset: preset,
                            thumbnailRenderer: viewModel.thumbnailRenderer,
                            onAdd: { viewModel.addPresetToTimeline(preset) },
                            onDelete: preset.isSystem ? nil : { viewModel.deletePreset(preset) }
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
            Text(String(localized: "Chưa có Preset nào"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Text(String(localized: "Tùy chỉnh màu sắc trong Inspector và bấm\n\"Lưu thành Preset\" để lưu lên Supabase."))
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

import SwiftUI
import Domain
import DesignSystem

/// View thư viện Text bên sidebar trái.
/// Gồm 2 subtab: "Mặc định" và "Templates" (hỗ trợ lọc theo danh mục JSON Script & đồng bộ Supabase).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextLibraryView: View {
    @Bindable private var viewModel: TextLibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: TextLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Tìm kiếm mẫu chữ...",
            categories: TextTemplateCategory.allCases.map(\.rawValue),
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
                if let cat = TextTemplateCategory(rawValue: val) {
                    viewModel.selectedCategory = cat
                }
            }
        )
    }

    private var reloadButton: some View {
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
        .help(String(localized: "Nạp lại kịch bản JSON Templates"))
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = viewModel.filteredPresetsWithDefaultFirst
            if presets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(presets) { preset in
                        TextCardItemView(
                            preset: preset,
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
            Text(String(localized: "Tùy chỉnh kiểu chữ trong Inspector và bấm\n\"Lưu thành Preset\" để lưu lên Supabase."))
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

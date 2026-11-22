import SwiftUI
import Domain
import DesignSystem

/// Bảng Thư viện Hiệu ứng thị giác (Effects Library) ở thanh Sidebar bên trái.
/// Gồm 11 danh mục chuẩn quốc tế, lưới 2 cột thẻ hiệu ứng, nút Yêu thích góc trên và nút Thêm góc dưới.
/// Hỗ trợ Thumbnail động 2.0s kết xuất trực tiếp bằng Hybrid GPU Engine khi hover chuột.
/// Tuân thủ AGENTS.md (File <= 300 dòng, View body <= 40 dòng).
public struct EffectLibraryView: View {
    @Bindable private var viewModel: EffectLibraryViewModel
    @State private var selectedCategory: String = EffectTemplateCategory.basic.displayName
    @State private var selectedPresetID: String?

    private let categories = EffectTemplateCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: EffectLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedPresets: [EffectPreset] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [EffectPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "effect")
            base = viewModel.templatePresets.filter { favs.contains($0.id) }
        } else if !trimmed.isEmpty {
            base = viewModel.templatePresets
        } else if let cat = EffectTemplateCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
            base = viewModel.templatePresets.filter { $0.category == cat }
        } else {
            base = viewModel.templatePresets
        }
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.description.localizedCaseInsensitiveContains(trimmed)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Search effects, tags...",
            categories: categories,
            selectedCategory: $selectedCategory,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
    }

    private var reloadButton: some View {
        let size = LibraryScaffoldView<EmptyView>.searchControlHeight
        return Button(action: { viewModel.reloadTemplates() }) {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .fill(DSColors.windowBackground)
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Reload Effects")
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = displayedPresets
            if presets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                    ForEach(presets) { preset in
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: preset.id, for: "effect")
                        UnifiedLibraryCardItemView(
                            title: preset.name,
                            isFavorite: isFav,
                            isSelected: selectedPresetID == preset.id,
                            showsDeleteButton: !preset.isSystem,
                            dragPayload: .effect(preset),
                            onSelect: {
                                selectedPresetID = preset.id
                            },
                            onAdd: {
                                viewModel.addPresetToTimeline(preset)
                            },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: preset.id, for: "effect")
                            },
                            onDelete: {
                                viewModel.deletePreset(preset)
                            }
                        ) { isCardHovered in
                            EffectAnimatedThumbnailView(preset: preset, isHovered: isCardHovered)
                        }
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No effects available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

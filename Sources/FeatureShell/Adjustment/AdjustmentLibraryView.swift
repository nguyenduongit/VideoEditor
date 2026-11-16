import SwiftUI
import Domain
import DesignSystem

/// Left Sidebar view for the Adjustment Layer Library.
/// Features a 100pt vertical category sidebar, 2-column square card grid,
/// top-right 26pt Favorites button, and bottom-right 26pt Add button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct AdjustmentLibraryView: View {
    public static let defaultCategory = "Default"
    public static let defaultPresetID = "adjustment_default_preset"

    @Bindable private var viewModel: AdjustmentLibraryViewModel
    @State private var selectedCategory: String = Self.defaultCategory
    @State private var selectedPresetID: String?

    private let categories = [Self.defaultCategory] + AdjustmentTemplateCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: AdjustmentLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedPresets: [AdjustmentPreset] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let nonDefault = viewModel.templatePresets.filter { $0.id != "default" && $0.id != Self.defaultPresetID }
        let base: [AdjustmentPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "adjustment")
            base = nonDefault.filter { favs.contains($0.id) }
        } else if !trimmed.isEmpty {
            base = nonDefault
        } else if selectedCategory == Self.defaultCategory {
            base = []
        } else if let cat = AdjustmentTemplateCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
            base = nonDefault.filter { $0.category == cat }
        } else {
            base = nonDefault
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
            searchPlaceholder: "Search color presets...",
            categories: categories,
            selectedCategory: $selectedCategory,
            favoritesCount: SidebarFavoriteManager.shared.favorites(for: "adjustment").count,
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
        .help("Reload Adjustment Presets")
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = displayedPresets
            let isDefaultSelected = selectedCategory == Self.defaultCategory
            let isFavSelected = selectedCategory == SidebarFavoriteManager.favoritesCategory
            let isDefaultFav = SidebarFavoriteManager.shared.isFavorite(id: Self.defaultPresetID, for: "adjustment")
                || SidebarFavoriteManager.shared.isFavorite(id: "default", for: "adjustment")
            let trimmedSearch = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
            let matchesSearch = trimmedSearch.isEmpty
                || "Default Adjustment".localizedCaseInsensitiveContains(trimmedSearch)
                || "Adjustment Layer".localizedCaseInsensitiveContains(trimmedSearch)
                || "Mặc định".localizedCaseInsensitiveContains(trimmedSearch)
            let showDefaultCard = ((isDefaultSelected || (isFavSelected && isDefaultFav)) && matchesSearch)
                || (!trimmedSearch.isEmpty && matchesSearch && !isFavSelected)

            if !showDefaultCard && presets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                    if showDefaultCard {
                        defaultAdjustmentCard
                    }

                    ForEach(presets) { preset in
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: preset.id, for: "adjustment")
                        UnifiedLibraryCardItemView(
                            title: preset.name,
                            isFavorite: isFav,
                            isSelected: selectedPresetID == preset.id,
                            onSelect: {
                                selectedPresetID = preset.id
                            },
                            onAdd: {
                                viewModel.addPresetToTimeline(preset)
                            },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: preset.id, for: "adjustment")
                            }
                        ) {
                            adjustmentThumbnail(for: preset)
                        }
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    private var defaultAdjustmentCard: some View {
        let isFav = SidebarFavoriteManager.shared.isFavorite(id: Self.defaultPresetID, for: "adjustment")
            || SidebarFavoriteManager.shared.isFavorite(id: "default", for: "adjustment")
        return UnifiedLibraryCardItemView(
            title: "Default Adjustment",
            isFavorite: isFav,
            isSelected: selectedPresetID == Self.defaultPresetID,
            onSelect: {
                selectedPresetID = Self.defaultPresetID
            },
            onAdd: {
                viewModel.addDefaultPresetToTimeline()
            },
            onToggleFavorite: {
                SidebarFavoriteManager.shared.toggleFavorite(id: Self.defaultPresetID, for: "adjustment")
            }
        ) {
            defaultThumbnailView
        }
    }

    private var defaultThumbnailView: some View {
        VStack(spacing: 4) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(DSColors.clipAdjustment)
            Text("Default")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [DSColors.windowBackground, DSColors.blockBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private func adjustmentThumbnail(for preset: AdjustmentPreset) -> some View {
        ZStack {
            if preset.previewColorsHex.count >= 2 {
                LinearGradient(
                    colors: preset.previewColorsHex.compactMap { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [DSColors.windowBackground, DSColors.clipAdjustment.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No adjustment presets available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

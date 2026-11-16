import SwiftUI
import AppKit
import Domain
import DesignSystem

/// Left Sidebar view for the Text Library.
/// Features a 100pt vertical category sidebar, 2-column square card grid,
/// top-right 26pt Favorites button, and bottom-right 26pt Add button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct TextLibraryView: View {
    public static let defaultCategory = "Default"
    public static let defaultPresetID = "text_default_preset"

    @Bindable private var viewModel: TextLibraryViewModel
    @State private var selectedCategory: String = Self.defaultCategory

    private let categories = [Self.defaultCategory] + TextTemplateCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: TextLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedPresets: [TextPreset] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let nonDefault = viewModel.templatePresets.filter { $0.id != "default" && $0.id != Self.defaultPresetID }
        let base: [TextPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "text")
            base = nonDefault.filter { favs.contains($0.id) }
        } else if !trimmed.isEmpty {
            base = nonDefault
        } else if selectedCategory == Self.defaultCategory {
            base = []
        } else if let cat = TextTemplateCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
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
            searchPlaceholder: "Search text presets...",
            categories: categories,
            selectedCategory: $selectedCategory,
            favoritesCount: totalFavoritesCount,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
    }

    private var totalFavoritesCount: Int {
        SidebarFavoriteManager.shared.favorites(for: "text").count
    }

    private var reloadButton: some View {
        let size = LibraryScaffoldView<EmptyView>.searchControlHeight
        return Button {
            viewModel.reloadTemplates()
        } label: {
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
        .help("Reload Templates")
    }

    private var contentScrollView: some View {
        GeometryReader { geo in
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                let presets = displayedPresets
                let isDefaultSelected = selectedCategory == Self.defaultCategory
                let isFavSelected = selectedCategory == SidebarFavoriteManager.favoritesCategory
                let isDefaultFav = SidebarFavoriteManager.shared.isFavorite(id: Self.defaultPresetID, for: "text")
                    || SidebarFavoriteManager.shared.isFavorite(id: "default", for: "text")
                let trimmedSearch = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
                let matchesSearch = trimmedSearch.isEmpty
                    || "Default Text".localizedCaseInsensitiveContains(trimmedSearch)
                    || "Text".localizedCaseInsensitiveContains(trimmedSearch)
                let showDefaultCard = ((isDefaultSelected || (isFavSelected && isDefaultFav)) && matchesSearch)
                    || (!trimmedSearch.isEmpty && matchesSearch && !isFavSelected)

                VStack(spacing: 0) {
                    if !showDefaultCard && presets.isEmpty {
                        emptyTemplatesView
                    } else {
                        LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                            if showDefaultCard {
                                defaultTextCard
                            }

                            ForEach(presets) { preset in
                                let isFav = SidebarFavoriteManager.shared.isFavorite(id: preset.id, for: "text")
                                UnifiedLibraryCardItemView(
                                    title: preset.name,
                                    isFavorite: isFav,
                                    isSelected: viewModel.selectedPresetID == preset.id,
                                    onSelect: { viewModel.selectPresetForPreview(preset) },
                                    onAdd: { viewModel.addPresetToTimeline(preset) },
                                    onToggleFavorite: {
                                        SidebarFavoriteManager.shared.toggleFavorite(id: preset.id, for: "text")
                                    }
                                ) { isCardHovered in
                                    TextAnimatedThumbnailView(preset: preset, isHovered: isCardHovered)
                                }
                            }
                        }
                        .padding(DSSpacing.sm)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.clearPreviewSelection()
                }
            }
        }
    }

    private var defaultTextCard: some View {
        let isFav = SidebarFavoriteManager.shared.isFavorite(id: Self.defaultPresetID, for: "text")
            || SidebarFavoriteManager.shared.isFavorite(id: "default", for: "text")
        return UnifiedLibraryCardItemView(
            title: "Default Text",
            isFavorite: isFav,
            isSelected: viewModel.selectedPresetID == Self.defaultPresetID || viewModel.selectedPresetID == "default",
            onSelect: {
                viewModel.selectDefaultPresetForPreview()
            },
            onAdd: {
                viewModel.addDefaultPresetToTimeline()
            },
            onToggleFavorite: {
                SidebarFavoriteManager.shared.toggleFavorite(id: Self.defaultPresetID, for: "text")
            }
        ) {
            defaultThumbnailView
        }
    }

    private var defaultThumbnailView: some View {
        VStack(spacing: 4) {
            Text("Aa")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
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


    private var emptyTemplatesView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "textformat")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No text templates available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

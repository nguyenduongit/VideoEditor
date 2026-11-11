import SwiftUI
import Domain
import DesignSystem

/// Left Sidebar view for the Visual Effects Library.
/// Features a 100pt vertical category sidebar, 2-column square card grid,
/// top-right 26pt Favorites button, and bottom-right 26pt Add button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct EffectLibraryView: View {
    @Bindable private var viewModel: EffectLibraryViewModel
    @State private var selectedCategory: String = EffectTemplateCategory.lightTransition.displayName

    private let categories = EffectTemplateCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: EffectLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedPresets: [EffectPreset] {
        let base: [EffectPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "effect")
            base = viewModel.templatePresets.filter { favs.contains($0.id) }
        } else {
            if let cat = EffectTemplateCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
                base = viewModel.templatePresets.filter { $0.category == cat }
            } else {
                base = viewModel.templatePresets
            }
        }
        guard !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchQuery) }
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Search effects, tags...",
            categories: categories,
            selectedCategory: $selectedCategory,
            favoritesCount: SidebarFavoriteManager.shared.favorites(for: "effect").count,
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
                            onAdd: {
                                viewModel.addPresetToTimeline(preset)
                            },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: preset.id, for: "effect")
                            }
                        ) {
                            effectThumbnail(for: preset)
                        }
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private func effectThumbnail(for preset: EffectPreset) -> some View {
        ZStack {
            LinearGradient(
                colors: [DSColors.windowBackground, DSColors.clipEffect.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: effectIcon(for: preset))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(DSColors.clipEffect)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func effectIcon(for preset: EffectPreset) -> String {
        switch preset.category {
        case .lightTransition: return "wand.and.stars"
        case .partyBeat: return "bolt.fill"
        case .cinematic: return "camera.filters"
        case .motionShake: return "waveform.path.ecg"
        default: return "sparkles"
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

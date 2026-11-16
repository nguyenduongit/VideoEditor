import SwiftUI
import Domain
import DesignSystem

/// Left Sidebar view for the Transitions Library.
/// Features a 100pt vertical category sidebar, 2-column square card grid,
/// top-right 26pt Favorites button, and bottom-right 26pt Add button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct TransitionLibraryView: View {
    @Bindable private var viewModel: TransitionLibraryViewModel
    @State private var selectedCategory: String = TransitionCategory.basic.displayName
    @State private var selectedPresetID: String?

    private let categories = TransitionCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: TransitionLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedPresets: [TransitionPreset] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [TransitionPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "transition")
            base = viewModel.templatePresets.filter { favs.contains($0.id) }
        } else if !trimmed.isEmpty {
            base = viewModel.templatePresets
        } else {
            if let cat = TransitionCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
                base = viewModel.templatePresets.filter { $0.category == cat }
            } else {
                base = viewModel.templatePresets
            }
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
            searchPlaceholder: "Search transitions...",
            categories: categories,
            selectedCategory: $selectedCategory,
            favoritesCount: SidebarFavoriteManager.shared.favorites(for: "transition").count,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
        .task {
            await viewModel.syncFromRemoteIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetStoreDidUpdate)) { _ in
            viewModel.reloadTemplates()
        }
    }

    private var reloadButton: some View {
        let size = LibraryScaffoldView<EmptyView>.searchControlHeight
        return Button(action: {
            viewModel.reloadTemplates()
            Task { await viewModel.syncFromRemoteIfAvailable(force: true) }
        }) {
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
        .help("Reload Transitions")
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = displayedPresets
            if presets.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                    ForEach(presets) { preset in
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: preset.id, for: "transition")
                        UnifiedLibraryCardItemView(
                            title: preset.name,
                            isFavorite: isFav,
                            isSelected: selectedPresetID == preset.id,
                            onSelect: {
                                selectedPresetID = preset.id
                            },
                            onAdd: {
                                viewModel.applyTransitionToTimeline(preset)
                            },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: preset.id, for: "transition")
                            }
                        ) { isCardHovered in
                            transitionThumbnail(for: preset, isHovered: isCardHovered)
                        }
                        .draggable({
                            TransitionDragSessionState.shared.activePresetID = preset.id
                            return "transition:\(preset.id)"
                        }()) {
                            cyanDragPreview(for: preset)
                        }
                        .help("\(preset.name) — \(preset.description)")
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    private func cyanDragPreview(for preset: TransitionPreset) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSRadius.small)
                .fill(DSColors.toggleCyan.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                )

            Rectangle()
                .fill(Color.white.opacity(0.90))
                .frame(width: 1.5, height: 32)

            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "hourglass")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.white)
                )
        }
        .frame(width: 100, height: 32)
        .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
    }

    @ViewBuilder
    private func transitionThumbnail(for preset: TransitionPreset, isHovered: Bool) -> some View {
        TransitionAnimatedThumbnailView(preset: preset, isHovered: isHovered)
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No transitions available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

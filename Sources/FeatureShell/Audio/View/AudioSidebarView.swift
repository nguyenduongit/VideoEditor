import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Left Sidebar view for the Audio Library and Dance Beat Counter utility.
/// Provides a 2-column grid layout with top-right 26pt Favorites button and bottom-right 26pt Add button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct AudioSidebarView: View {
    @State private var viewModel: AudioSidebarViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(timelineViewModel: TimelineViewModel? = nil, dependencies: EditorDependencies? = nil) {
        _viewModel = State(wrappedValue: AudioSidebarViewModel(
            timelineViewModel: timelineViewModel,
            dependencies: dependencies
        ))
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Search audio, tools...",
            categories: viewModel.categories,
            selectedCategory: $viewModel.selectedCategory,
            favoritesCount: SidebarFavoriteManager.shared.favorites(for: "audio").count,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
    }

    private var reloadButton: some View {
        let size = LibraryScaffoldView<EmptyView>.searchControlHeight
        return Button(action: {
            viewModel.syncPresetsFromSupabase()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .fill(DSColors.blockBackground)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Reload audio")
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                ForEach(viewModel.filteredItems) { item in
                    let isFav = SidebarFavoriteManager.shared.isFavorite(id: item.id, for: "audio")
                    UnifiedLibraryCardItemView(
                        title: item.name,
                        isFavorite: isFav,
                        onAdd: {
                            viewModel.addPresetToTimeline(item)
                        },
                        onToggleFavorite: {
                            SidebarFavoriteManager.shared.toggleFavorite(id: item.id, for: "audio")
                        }
                    ) {
                        thumbnail(for: item)
                    }
                }
            }
            .padding(DSSpacing.sm)
        }
    }

    @ViewBuilder
    private func thumbnail(for item: AudioPreset) -> some View {
        VStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(item.id == "audio_dance_beat" ? DSColors.accent : DSColors.toggleCyan)

            Text(item.durationFormatted)
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
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
}

import SwiftUI
import DesignSystem

/// Card component displaying 1 item in the unified 2-column Left Sidebar grid.
/// Features a 1:1 square thumbnail, title label below, top-right 26pt Favorites (★) button,
/// and bottom-right 26pt Add (+) button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct UnifiedLibraryCardItemView<Thumbnail: View>: View {
    private let title: String
    private let isFavorite: Bool
    private let isSelected: Bool
    private let showsFavoriteButton: Bool
    private let showsDeleteButton: Bool
    private let showsAddButton: Bool
    private let externalIsHovered: Bool?
    private let onSelect: () -> Void
    private let onAdd: () -> Void
    private let onToggleFavorite: () -> Void
    private let onDelete: () -> Void
    private let thumbnail: () -> Thumbnail

    @State private var localIsHovered: Bool = false

    private var isHovered: Bool {
        externalIsHovered ?? localIsHovered
    }

    public init(
        title: String,
        isFavorite: Bool,
        isSelected: Bool = false,
        showsFavoriteButton: Bool = true,
        showsDeleteButton: Bool = false,
        showsAddButton: Bool = true,
        isHovered: Bool? = nil,
        onSelect: @escaping () -> Void = {},
        onAdd: @escaping () -> Void = {},
        onToggleFavorite: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        @ViewBuilder thumbnail: @escaping () -> Thumbnail
    ) {
        self.title = title
        self.isFavorite = isFavorite
        self.isSelected = isSelected
        self.showsFavoriteButton = showsFavoriteButton
        self.showsDeleteButton = showsDeleteButton
        self.showsAddButton = showsAddButton
        self.externalIsHovered = isHovered
        self.onSelect = onSelect
        self.onAdd = onAdd
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
        self.thumbnail = thumbnail
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            thumbnailContainer
            titleLabel
        }
        .frame(maxWidth: .infinity)
        .onHover { localIsHovered = $0 }
    }

    private var thumbnailContainer: some View {
        ZStack {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    thumbnail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                )
                .background(DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .stroke(
                            isSelected ? DSColors.toggleCyan : (isHovered ? DSColors.toggleCyan.opacity(0.5) : DSColors.blockBorder),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                }

            if showsFavoriteButton && (isHovered || isFavorite) {
                favoriteButtonOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if showsDeleteButton && isHovered {
                deleteButtonOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if showsAddButton && isHovered {
                addButtonOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var deleteButtonOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.red.opacity(0.95))
                    }
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            Spacer()
        }
        .padding(DSSpacing.xs)
    }

    private var favoriteButtonOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onToggleFavorite) {
                    DSRoundedStarView(isFavorite: isFavorite, size: 22)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
            }
            Spacer()
        }
        .padding(DSSpacing.xs)
    }

    private var addButtonOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onAdd) {
                    ZStack {
                        Circle()
                            .fill(DSColors.toggleCyan)
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add to Timeline")
            }
        }
        .padding(DSSpacing.xs)
    }

    private var titleLabel: some View {
        Text(title)
            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

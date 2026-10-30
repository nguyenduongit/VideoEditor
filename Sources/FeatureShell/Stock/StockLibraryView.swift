import SwiftUI
import Domain
import DesignSystem

/// Giao diện Thư viện Mẫu (Stock Library) đồng bộ từ Supabase.
/// Đồng nhất lưới 3 cột với item hình vuông bo góc DSRadius.block như Text và Adjustment.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct StockLibraryView: View {
    @Bindable private var viewModel: StockLibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: StockLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Tìm kiếm mẫu, B-roll...",
            categories: StockLibraryViewModel.categories,
            selectedCategory: $viewModel.selectedCategory
        ) {
            contentArea
        }
    }

    private var contentArea: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let items = viewModel.filteredItems
            if items.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(items) { item in
                        StockCardItemView(item: item) {
                            viewModel.addItemToTimeline(item)
                        }
                    }
                }
                .padding(DSSpacing.md)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "film.stack")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text(String(localized: "Không tìm thấy mẫu"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Text(String(localized: "Thử tìm kiếm từ khóa khác hoặc chuyển danh mục."))
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

private struct StockCardItemView: View {
    let item: StockLibraryItem
    let onAdd: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            squareThumbnailBox
            nameLabel
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onAdd()
        }
        .help(item.title)
    }

    private var squareThumbnailBox: some View {
        ZStack {
            if item.mediaType == "solid_color" || item.id == "stock_black_screen" {
                RoundedRectangle(cornerRadius: DSRadius.block)
                    .fill(Color.black)
                RoundedRectangle(cornerRadius: DSRadius.block)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                Image(systemName: "square.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: DSRadius.block)
                    .fill(LinearGradient(
                        colors: [DSColors.layerTrackBackground, DSColors.activeTabBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Image(systemName: iconForCategory(item.category))
                    .font(.system(size: 26))
                    .foregroundStyle(DSColors.textSecondary.opacity(0.45))
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(isHovered ? DSColors.toggleCyan : DSColors.blockBorder, lineWidth: isHovered ? 1.5 : 1)
        )
        .overlay(alignment: .bottomLeading) {
            if let duration = item.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(DSSpacing.xs)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                plusButton
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var nameLabel: some View {
        Text(item.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isHovered ? DSColors.textPrimary : DSColors.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var plusButton: some View {
        Button(action: onAdd) {
            ZStack {
                Circle()
                    .fill(DSColors.trafficZoom)
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 22, height: 22)
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(DSSpacing.xs)
        .help("Thêm vào Timeline")
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Màu nền": return "square.fill"
        case "Video mẫu": return "play.rectangle"
        case "Hình nền": return "paintpalette"
        case "B-roll": return "camera.metering.matrix"
        case "Green screen": return "person.crop.rectangle"
        case "Chuyển cảnh": return "wand.and.stars"
        default: return "film"
        }
    }
}

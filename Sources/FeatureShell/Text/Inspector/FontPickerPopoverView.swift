import SwiftUI
import DesignSystem

/// Giao diện danh sách chọn phông chữ dạng Popover hỗ trợ tìm kiếm và đánh dấu sao yêu thích.
/// Phông chữ được đánh dấu sao sẽ tự động hiển thị ở nhóm trên cùng với icon ngôi sao vàng.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct FontPickerPopoverView: View {
    public let selectedFont: String
    public let onSelect: (String) -> Void
    public let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedCategory: FontCategory = .all
    private var fontManager: CustomFontManager { CustomFontManager.shared }

    public init(
        selectedFont: String,
        onSelect: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.selectedFont = selectedFont
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchHeader
            categoryFilterBar
            Divider().opacity(0.15)
            fontList
        }
        .frame(width: 280, height: 380)
        .background(DSColors.blockBackground)
    }

    // MARK: - Subviews

    private var searchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)

            TextField("Tìm kiếm phông chữ...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(DSColors.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(DSColors.windowBackground)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(FontCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button(action: { selectedCategory = category }) {
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.white : DSColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(isSelected ? DSColors.accent : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(DSColors.blockBackground)
    }

    private var fontList: some View {
        let (favorites, others) = fontManager.sortedFonts(matching: searchText, category: selectedCategory)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if !favorites.isEmpty {
                    sectionHeader(title: "Yêu thích", icon: "star.fill", count: favorites.count, iconColor: .yellow)
                    ForEach(favorites) { item in
                        fontRow(item: item, isFavorite: true)
                    }
                    Divider().opacity(0.15).padding(.vertical, 4)
                }

                if !others.isEmpty {
                    let sectionTitle = selectedCategory == .all ? "Tất cả phông chữ" : selectedCategory.rawValue
                    sectionHeader(title: sectionTitle, icon: "textformat", count: others.count, iconColor: DSColors.textSecondary)
                    ForEach(others) { item in
                        fontRow(item: item, isFavorite: false)
                    }
                } else if favorites.isEmpty {
                    emptySearchPlaceholder
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }

    private func sectionHeader(title: String, icon: String, count: Int, iconColor: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(iconColor)
            Text("\(title) (\(count))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var emptySearchPlaceholder: some View {
        VStack(spacing: 4) {
            Text("Không tìm thấy phông chữ phù hợp")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private func fontRow(item: CustomFontItem, isFavorite: Bool) -> some View {
        let isSelected = item.id.caseInsensitiveCompare(selectedFont) == .orderedSame

        return HStack(spacing: 6) {
            // Nút ngôi sao yêu thích bên trái
            Button(action: {
                fontManager.toggleFavorite(fontID: item.id)
            }) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(isFavorite ? Color.yellow : DSColors.textSecondary.opacity(0.35))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Bỏ yêu thích" : "Thêm vào yêu thích")

            // Nút chọn font
            Button(action: {
                onSelect(item.id)
                onDismiss()
            }) {
                HStack {
                    Text(item.displayName)
                        .font(fontForItem(item))
                        .foregroundStyle(isSelected ? DSColors.accent : DSColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DSColors.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(isSelected ? DSColors.activeTabBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func fontForItem(_ item: CustomFontItem) -> Font {
        if item.isCustom {
            return Font.custom(item.id, size: 12, relativeTo: .body)
        }
        return .system(size: 12, weight: .regular)
    }
}

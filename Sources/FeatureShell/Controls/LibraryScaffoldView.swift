import SwiftUI
import DesignSystem

/// Component khung layout dùng chung cho Sidebar trái của tất cả các Tab (Media, Stock Library, Text, Adjustment, Effects).
/// Cung cấp thanh tìm kiếm nhanh, thanh lọc danh mục cuộn ngang, nút thao tác phụ và khu vực nội dung cuộn.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) và R2.4 của AGENTS.md.
public struct LibraryScaffoldView<Content: View>: View {
    private let searchPlaceholder: String
    @Binding private var searchQuery: String
    private let hasSearch: Bool

    private let categories: [String]
    private let selectedCategory: Binding<String>?

    private let trailingAction: AnyView?
    private let content: () -> Content

    public init(
        searchQuery: Binding<String>? = nil,
        searchPlaceholder: String = "Tìm kiếm...",
        categories: [String] = [],
        selectedCategory: Binding<String>? = nil,
        trailingAction: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        if let searchQuery {
            self._searchQuery = searchQuery
            self.hasSearch = true
        } else {
            self._searchQuery = .constant("")
            self.hasSearch = false
        }
        self.searchPlaceholder = searchPlaceholder
        self.categories = categories
        self.selectedCategory = selectedCategory
        self.trailingAction = trailingAction
        self.content = content
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            headerSection
            if hasSearch || !categories.isEmpty {
                Divider()
                    .background(DSColors.blockBorder)
            }
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    @ViewBuilder
    private var headerSection: some View {
        if hasSearch || trailingAction != nil || !categories.isEmpty {
            VStack(spacing: DSSpacing.xs) {
                if hasSearch || trailingAction != nil {
                    HStack(spacing: DSSpacing.xs) {
                        if hasSearch {
                            searchBar
                        }
                        if let trailingAction {
                            trailingAction
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.top, DSSpacing.sm)
                }

                if !categories.isEmpty, let selectedCategory {
                    categoryChipsBar(selected: selectedCategory)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.bottom, DSSpacing.xs)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)

            TextField(searchPlaceholder, text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textPrimary)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private func categoryChipsBar(selected: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selected.wrappedValue == category
                    Button(action: {
                        selected.wrappedValue = category
                    }) {
                        Text(category)
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? DSColors.activeTabBackground : DSColors.windowBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : DSColors.blockBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

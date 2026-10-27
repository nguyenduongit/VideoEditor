import SwiftUI
import Domain
import DesignSystem

/// Giao diện danh sách chọn Action dạng Popover hỗ trợ tìm kiếm và chọn nhanh tác vụ tự động.
/// Thiết kế đồng nhất theo phong cách của FontPickerPopoverView trong Dark Editor.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct ActionPickerPopoverView: View {
    public let selectedActionID: String?
    public let actions: [CustomAction]
    public let onSelect: (CustomAction) -> Void
    public let onDismiss: () -> Void

    @State private var searchText: String = ""

    public init(
        selectedActionID: String?,
        actions: [CustomAction],
        onSelect: @escaping (CustomAction) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.selectedActionID = selectedActionID
        self.actions = actions
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    private var filteredActions: [CustomAction] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return actions
        }
        return actions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider().opacity(0.15)
            actionList
        }
        .frame(width: 280, height: 320)
        .background(DSColors.blockBackground)
    }

    // MARK: - Subviews

    private var searchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)

            TextField(String(localized: "Tìm kiếm Action..."), text: $searchText)
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

    private var actionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if !filteredActions.isEmpty {
                    sectionHeader(count: filteredActions.count)
                    ForEach(filteredActions) { action in
                        actionRow(action: action)
                    }
                } else {
                    emptySearchPlaceholder
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }

    private func sectionHeader(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
                .foregroundStyle(DSColors.accent)
            Text(String(localized: "Danh sách Action (\(count))"))
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
            Text(String(localized: "Không tìm thấy Action phù hợp"))
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func actionRow(action: CustomAction) -> some View {
        let isSelected = action.id == selectedActionID

        return Button(action: {
            onSelect(action)
        }) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? DSColors.accent : DSColors.textSecondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : DSColors.textPrimary)
                        .lineLimit(1)

                    Text(String(localized: "\(action.taskIDs.count) tác vụ"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DSColors.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

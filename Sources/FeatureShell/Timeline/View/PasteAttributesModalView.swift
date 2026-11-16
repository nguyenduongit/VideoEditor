import SwiftUI
import Domain
import DesignSystem

/// Popover/Modal nhỏ cho phép người dùng tích chọn các nhóm thuộc tính khi Paste Attributes.
public struct PasteAttributesModalView: View {
    public let sourceClipName: String
    public let targetCount: Int
    public let availableCategories: [ClipAttributeCategory]
    @Binding public var selectedCategories: Set<ClipAttributeCategory>
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    public init(
        sourceClipName: String,
        targetCount: Int,
        availableCategories: [ClipAttributeCategory],
        selectedCategories: Binding<Set<ClipAttributeCategory>>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sourceClipName = sourceClipName
        self.targetCount = targetCount
        self.availableCategories = availableCategories
        self._selectedCategories = selectedCategories
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            headerView
            quickSelectRow
            categoryChecklistView
            footerButtonsView
        }
        .padding(DSSpacing.md)
        .frame(width: 320)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
    }

    private var headerView: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Paste Attributes"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                Text("From \"\(sourceClipName)\" → \(targetCount) clip\(targetCount > 1 ? "s" : "")")
                    .font(.system(size: 10.5))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var quickSelectRow: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(String(localized: "Select All")) {
                selectedCategories = Set(availableCategories)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DSColors.accent)

            Text("·").foregroundStyle(DSColors.textSecondary)

            Button(String(localized: "Clear")) {
                selectedCategories.removeAll()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DSColors.textSecondary)

            Spacer()
        }
    }

    private var categoryChecklistView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(availableCategories) { category in
                categoryRow(category)
            }
            if availableCategories.contains(.textStyle) {
                Text(String(localized: "Note: Destination text content is always preserved."))
                    .font(.system(size: 10))
                    .foregroundStyle(DSColors.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(DSSpacing.sm)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func categoryRow(_ category: ClipAttributeCategory) -> some View {
        let isSelected = selectedCategories.contains(category)
        return Button {
            if isSelected {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                Image(systemName: category.systemImage)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(width: 16)
                Text(category.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                Spacer()
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footerButtonsView: some View {
        HStack(spacing: DSSpacing.sm) {
            Spacer()
            Button(String(localized: "Cancel"), action: onCancel)
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DSColors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .foregroundStyle(DSColors.textSecondary)

            Button(String(localized: "Paste"), action: onConfirm)
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(selectedCategories.isEmpty ? DSColors.inputBackground : DSColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .foregroundStyle(selectedCategories.isEmpty ? DSColors.textSecondary : Color.white)
                .disabled(selectedCategories.isEmpty)
        }
        .font(.system(size: 12, weight: .semibold))
    }
}

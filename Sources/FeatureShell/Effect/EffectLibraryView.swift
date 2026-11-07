import SwiftUI
import Domain
import DesignSystem

/// View thư viện Hiệu ứng thị giác (Effects) kết nối Kho Thư viện Cộng đồng trên sidebar trái.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct EffectLibraryView: View {
    @Bindable private var viewModel: EffectLibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: EffectLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Tìm hiệu ứng, tác giả, tag...",
            categories: EffectTemplateCategory.allCases.map(\.rawValue),
            selectedCategory: categoryBinding,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
    }

    private var categoryBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedCategory.rawValue },
            set: { val in
                if let cat = EffectTemplateCategory(rawValue: val) {
                    viewModel.selectedCategory = cat
                }
            }
        )
    }

    private var reloadButton: some View {
        Button(action: { viewModel.reloadTemplates() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 24, height: 24)
                .background(DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        }
        .buttonStyle(.plain)
        .help(String(localized: "Đồng bộ lại Kho Hiệu ứng Cộng đồng"))
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = viewModel.filteredPresets
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(presets) { preset in
                    EffectCardItemView(
                        preset: preset,
                        onAdd: { viewModel.addPresetToTimeline(preset) },
                        onDelete: preset.canBeModified(by: CommunityIdentity.currentAuthorID)
                            ? { viewModel.deletePreset(preset) }
                            : nil
                    )
                }
            }
            .padding(DSSpacing.md)
        }
    }
}

/// Card hình vuông hiển thị mẫu hiệu ứng thị giác (EffectPreset) kèm thông tin tác giả cộng đồng.
private struct EffectCardItemView: View {
    let preset: EffectPreset
    let onAdd: () -> Void
    let onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 3) {
            squareThumbnailBox
            nameLabel
            authorLabel
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onAdd()
        }
        .contextMenu {
            Button(action: onAdd) {
                Label(String(localized: "Thêm vào Timeline"), systemImage: "plus.circle")
            }
            if let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(String(localized: "Xóa khỏi Thư viện"), systemImage: "trash")
                }
            }
        }
        .help("\(preset.name) — Tác giả: \(preset.community.authorName)\n\(preset.description)")
    }

    private var squareThumbnailBox: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DSColors.windowBackground,
                    DSColors.activeTabBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                Circle()
                    .fill(DSColors.clipEffect.opacity(isHovered ? 0.25 : 0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: preset.config.type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DSColors.clipEffect)
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(isHovered ? DSColors.toggleCyan : DSColors.blockBorder, lineWidth: isHovered ? 1.5 : 1)
        )
        .overlay(alignment: .topLeading) {
            if !preset.isSystem {
                Text("★ \(preset.community.downloadsCount)")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(5)
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
        Text(preset.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isHovered ? DSColors.textPrimary : DSColors.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var authorLabel: some View {
        Text(preset.isSystem ? "Hệ thống" : "@\(preset.community.authorName)")
            .font(.system(size: 9))
            .foregroundStyle(DSColors.textSecondary.opacity(0.65))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var plusButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(DSColors.accent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .padding(6)
    }
}

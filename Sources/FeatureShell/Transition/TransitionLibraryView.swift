import SwiftUI
import Domain
import DesignSystem

/// View thư viện Mẫu chuyển cảnh (Transitions) bên sidebar trái.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TransitionLibraryView: View {
    @Bindable private var viewModel: TransitionLibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: TransitionLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Tìm kiếm mẫu chuyển cảnh...",
            categories: TransitionCategory.allCases.map(\.rawValue),
            selectedCategory: categoryBinding,
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

    private var categoryBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedCategory.rawValue },
            set: { val in
                if let cat = TransitionCategory(rawValue: val) {
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
        .help(String(localized: "Tải lại danh sách chuyển cảnh"))
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = viewModel.filteredPresets
            if presets.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(presets) { preset in
                        transitionCard(preset)
                    }
                }
                .padding(DSSpacing.md)
            }
        }
    }

    private func transitionCard(_ preset: TransitionPreset) -> some View {
        Button(action: { viewModel.applyTransitionToTimeline(preset) }) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .fill(DSColors.windowBackground)
                        .frame(height: 72)

                    Image(systemName: preset.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(DSColors.accent)
                }

                Text(preset.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                    .lineLimit(1)

                Text(preset.description)
                    .font(.system(size: 9.5))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(2)

                HStack {
                    Text("\(String(format: "%.1f", preset.defaultDuration))s")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DSColors.accent)
                }
                .padding(.top, 2)
            }
            .padding(DSSpacing.sm)
            .background(DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text(String(localized: "Không tìm thấy chuyển cảnh"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}


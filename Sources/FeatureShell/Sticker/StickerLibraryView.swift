import SwiftUI
import AppKit
import Domain
import DesignSystem

/// View thư viện Nhãn dán (SVG Vector & GIF / APNG Stickers) bên sidebar trái,
/// kết xuất trực tiếp hình thu nhỏ Vector SVG sắc nét ngay trên thẻ chọn.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct StickerLibraryView: View {
    @Bindable private var viewModel: StickerLibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: StickerLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Tìm kiếm nhãn dán SVG, GIF, emoji...",
            categories: StickerCategory.allCases.map(\.rawValue),
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
                if let cat = StickerCategory(rawValue: val) {
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
        .help(String(localized: "Tải lại danh sách nhãn dán"))
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = viewModel.filteredPresets
            if presets.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(presets) { preset in
                        stickerCard(preset)
                    }
                }
                .padding(DSSpacing.md)
            }
        }
    }

    private func stickerCard(_ preset: StickerPreset) -> some View {
        Button(action: { viewModel.addStickerToTimeline(preset) }) {
            VStack(spacing: DSSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .fill(DSColors.windowBackground)
                        .frame(height: 72)

                    stickerThumbnail(for: preset)

                    VStack {
                        HStack {
                            Spacer()
                            Text(preset.format.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(preset.format == .svg ? DSColors.toggleCyan : DSColors.textSecondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(DSColors.blockBackground.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Spacer()
                    }
                    .padding(4)
                }

                Text(preset.name)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(DSSpacing.xs)
            .background(DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func stickerThumbnail(for preset: StickerPreset) -> some View {
        if let svg = preset.config.svgMarkup,
           !svg.isEmpty,
           let cgImg = TextSVGAndAssetCache.shared.rasterizeSVG(svg, targetSize: CGSize(width: 96, height: 96)) {
            Image(decorative: cgImg, scale: 2.0)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
        } else {
            Image(systemName: preset.systemSymbolFallback)
                .font(.system(size: 28))
                .foregroundStyle(DSColors.toggleCyan)
        }
    }

    private var emptyView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "face.smiling")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text(String(localized: "Không tìm thấy nhãn dán"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}

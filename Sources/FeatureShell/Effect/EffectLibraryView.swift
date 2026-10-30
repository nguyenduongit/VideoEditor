import SwiftUI
import Domain
import DesignSystem

/// View thư viện Hiệu ứng thị giác (Effects) trên sidebar trái.
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
            searchPlaceholder: "Tìm kiếm hiệu ứng..."
        ) {
            contentScrollView
        }
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(viewModel.availableEffects) { effect in
                    EffectCardItemView(effect: effect) {
                        viewModel.addEffectToTimeline(type: effect)
                    }
                }
            }
            .padding(DSSpacing.md)
        }
    }
}

/// Card hình vuông hiển thị hiệu ứng thị giác (Effect), đồng nhất với TextCardItemView và AdjustmentCardItemView.
private struct EffectCardItemView: View {
    let effect: EffectType
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
        .help(effect.description.isEmpty ? effect.displayName : effect.description)
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
                Image(systemName: effect.iconName)
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
        Text(effect.displayName)
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
}

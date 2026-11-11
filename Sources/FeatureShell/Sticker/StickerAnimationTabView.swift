import SwiftUI
import Domain
import DesignSystem

/// Tab `"Animation"` chuyên dụng cho Nhãn dán (Sticker):
/// Chỉ hỗ trợ Loop Animation (Vòng lặp vô tận) tinh tuyển, loại bỏ hoàn toàn In và Out.
/// Cho phép điều chỉnh tốc độ Loop (Loop Speed 0.25x – 4.0x) và xem trước trực quan.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 40 dòng) của AGENTS.md.
public struct StickerAnimationTabView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                loopGridSection
                speedSection
            }
            .padding(DSSize.inspectorContentPadding)
        }
    }

    private var currentConfig: StickerConfiguration {
        viewModel.stickerConfiguration
    }

    private let loopTypes: [TextLoopAnimationType] = [
        .none,
        .pulse,
        .sway,
        .wobble,
        .bounce,
        .spin,
        .float,
        .shake,
        .breathe,
        .wave,
        .flicker
    ]

    private let gridColumns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    private var loopGridSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "HIỆU ỨNG VÒNG LẶP (LOOP)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            LazyVGrid(columns: gridColumns, spacing: DSSpacing.sm) {
                ForEach(loopTypes) { type in
                    let isSelected = currentConfig.animation.loopType == type
                    loopCard(type: type, isSelected: isSelected)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func loopCard(type: TextLoopAnimationType, isSelected: Bool) -> some View {
        Button(action: { selectLoopType(type) }) {
            VStack(spacing: DSSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .fill(isSelected ? DSColors.toggleCyan.opacity(0.18) : DSColors.windowBackground)
                        .frame(height: 44)

                    Image(systemName: type.iconName)
                        .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                }

                Text(type.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(DSSpacing.xs)
            .background(isSelected ? DSColors.toggleCyan.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(isSelected ? DSColors.toggleCyan : DSColors.blockBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "TỐC ĐỘ VÒNG LẶP"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Tốc độ",
                value: Binding(
                    get: { currentConfig.animation.loopSpeed },
                    set: { val in
                        var cfg = currentConfig
                        cfg.animation.loopSpeed = val
                        cfg.playbackSpeed = val
                        viewModel.updateStickerConfiguration(cfg, commit: false)
                    }
                ),
                range: 0.25...4.0,
                step: 0.05,
                defaultValue: 1.0,
                unit: "x",
                onEditingChanged: { isEditing in
                    if !isEditing {
                        viewModel.updateStickerConfiguration(currentConfig, commit: true)
                    }
                }
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func selectLoopType(_ type: TextLoopAnimationType) {
        var cfg = currentConfig
        cfg.animation.loopType = type
        cfg.animation.inType = .none
        cfg.animation.outType = .none
        cfg.animation.scriptId = "none"
        viewModel.updateStickerConfiguration(cfg, commit: true)
    }
}


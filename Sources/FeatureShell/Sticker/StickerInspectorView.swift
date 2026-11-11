import SwiftUI
import Domain
import DesignSystem

/// Bảng Inspector chuyên dụng cho Tab `"Sticker"` (Vector SVG / PNG / GIF / APNG).
/// Thiết kế tinh gọn thuần túy Transform: Scale, Vị trí (X, Y), Xoay, Độ mờ, Lật ngang/dọc kèm Keyframes.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 40 dòng, Hàm <= 50 dòng) của AGENTS.md.
public struct StickerInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            headerSection
            transformSection
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var currentConfig: StickerConfiguration {
        viewModel.stickerConfiguration
    }

    private var isAnimatedSticker: Bool {
        currentConfig.format.isAnimated || (currentConfig.svgMarkup?.contains("@keyframes") == true)
    }

    private var headerSection: some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .fill(DSColors.toggleCyan.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: currentConfig.systemSymbolFallback ?? "face.smiling")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DSColors.toggleCyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.selectedClip?.name ?? "Nhãn dán")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if isAnimatedSticker {
                        Text(String(localized: "ĐỘNG"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(DSColors.toggleCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DSColors.toggleCyan.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text(String(localized: "TĨNH"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(DSColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DSColors.blockBorder.opacity(0.6))
                            .clipShape(Capsule())
                    }

                    Text(currentConfig.format.displayName)
                        .font(.system(size: 10.5))
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var transformSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "BỐ CỤC (TRANSFORM)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Scale",
                value: Binding(
                    get: { viewModel.liveNumber(for: "scale", default: 1.0) },
                    set: { viewModel.updateLiveValue(key: "scale", value: $0) }
                ),
                range: 0.1...5.0,
                step: 0.05,
                defaultValue: 1.0,
                unit: "x",
                trailingAccessory: keyframeControl(for: ["scale"], defaultVal: 1.0),
                onEditingChanged: { viewModel.onSliderEditingChanged(key: "scale", isEditing: $0) }
            )

            DSPositionControl(
                title: "Vị trí",
                xValue: Binding(
                    get: { viewModel.liveNumber(for: "positionX", default: 0.0) },
                    set: { viewModel.updateLiveValue(key: "positionX", value: $0) }
                ),
                yValue: Binding(
                    get: { viewModel.liveNumber(for: "positionY", default: 0.0) },
                    set: { viewModel.updateLiveValue(key: "positionY", value: $0) }
                ),
                step: 1.0,
                trailingAccessory: keyframeControl(for: ["positionX", "positionY"], defaultVal: nil),
                onEditingChanged: { viewModel.onSliderEditingChanged(key: "position", isEditing: $0) }
            )

            DSRotationControl(
                title: "Xoay",
                angle: Binding(
                    get: { viewModel.liveNumber(for: "rotation", default: 0.0) },
                    set: { viewModel.updateLiveValue(key: "rotation", value: $0) }
                ),
                step: 0.5,
                trailingAccessory: keyframeControl(for: ["rotation"], defaultVal: 0.0),
                onEditingChanged: { viewModel.onSliderEditingChanged(key: "rotation", isEditing: $0) }
            )

            DSSliderWithInput(
                title: "Độ mờ",
                value: Binding(
                    get: { viewModel.liveNumber(for: "opacity", default: 1.0) },
                    set: { viewModel.updateLiveValue(key: "opacity", value: $0) }
                ),
                range: 0.0...1.0,
                step: 0.01,
                defaultValue: 1.0,
                unit: "%",
                trailingAccessory: keyframeControl(for: ["opacity"], defaultVal: 1.0),
                onEditingChanged: { viewModel.onSliderEditingChanged(key: "opacity", isEditing: $0) }
            )

            flipControlsRow
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var flipControlsRow: some View {
        let cfg = currentConfig
        return HStack(spacing: DSSpacing.sm) {
            flipButton(
                title: "Lật ngang",
                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                isActive: cfg.flipHorizontal
            ) {
                var updated = cfg
                updated.flipHorizontal.toggle()
                viewModel.updateStickerConfiguration(updated, commit: true)
            }

            flipButton(
                title: "Lật dọc",
                icon: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                isActive: cfg.flipVertical
            ) {
                var updated = cfg
                updated.flipVertical.toggle()
                viewModel.updateStickerConfiguration(updated, commit: true)
            }
        }
    }

    private func flipButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(String(localized: String.LocalizationValue(title)))
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? Color.white : DSColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(isActive ? DSColors.accent : DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func keyframeControl(for keys: [String], defaultVal: Double?) -> AnyView? {
        var defaults: [String: Double] = [:]
        if let defaultVal, keys.count == 1 { defaults[keys[0]] = defaultVal }
        return AnyView(
            DSKeyframeControl(
                hasKeyframesOnTrack: viewModel.hasKeyframes(for: keys),
                isAtKeyframe: viewModel.hasKeyframeAtPlayhead(for: keys),
                canGoPrevious: viewModel.canJumpToPreviousKeyframe(for: keys),
                canGoNext: viewModel.canJumpToNextKeyframe(for: keys),
                selectedCurveID: viewModel.activeInterpolation(for: keys).rawValue,
                curveOptions: viewModel.keyframeCurveOptions,
                onToggleKeyframe: { viewModel.toggleKeyframe(for: keys, defaultValues: defaults) },
                onPreviousKeyframe: { viewModel.jumpToPreviousKeyframe(for: keys) },
                onNextKeyframe: { viewModel.jumpToNextKeyframe(for: keys) },
                onSelectCurve: { if let i = KeyframeInterpolation(rawValue: $0) { viewModel.setInterpolation(i, for: keys) } },
                onClearAllKeyframes: { viewModel.clearAllKeyframes(for: keys) }
            )
        )
    }
}

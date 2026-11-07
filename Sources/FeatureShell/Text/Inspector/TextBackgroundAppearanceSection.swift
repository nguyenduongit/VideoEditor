import SwiftUI
import Domain
import DesignSystem

/// Khối điều chỉnh Kích thước, Độ lệch tâm, Bo góc, Làm mềm biên GPU (`Feather`), Viền khung (`Border`),
/// Bóng đổ khung (`Box Shadow`) và Hòa trộn (`Blend Mode`) cho Tab `"Background"` của Module `Text`.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng, Hàm <= 50 dòng) của AGENTS.md.
public struct TextBackgroundAppearanceSection: View {
    public let config: TextConfiguration
    public let onUpdate: (TextConfiguration, Bool) -> Void

    public init(
        config: TextConfiguration,
        onUpdate: @escaping (TextConfiguration, Bool) -> Void
    ) {
        self.config = config
        self.onUpdate = onUpdate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sizingAndOffsetCard
            boxStylingCard
            borderAndShadowCard
        }
    }

    // MARK: - Sizing & Offset Card

    private var sizingAndOffsetCard: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Kích thước & Vị trí khung nền"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            Picker("Chế độ kích thước", selection: Binding(
                get: { bg.fitToTextBounds },
                set: { fit in
                    var u = config
                    u.background.fitToTextBounds = fit
                    onUpdate(u, true)
                }
            )) {
                Text(String(localized: "Ôm theo chữ")).tag(true)
                Text(String(localized: "Kích thước tự do")).tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if bg.fitToTextBounds {
                DSSliderWithInput(
                    title: "Đệm ngang (Padding X)",
                    value: Binding(
                        get: { bg.paddingX },
                        set: { var u = config; u.background.paddingX = $0; onUpdate(u, false) }
                    ),
                    range: 0.0...140.0, step: 1.0, defaultValue: 24.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
                DSSliderWithInput(
                    title: "Đệm dọc (Padding Y)",
                    value: Binding(
                        get: { bg.paddingY },
                        set: { var u = config; u.background.paddingY = $0; onUpdate(u, false) }
                    ),
                    range: 0.0...90.0, step: 1.0, defaultValue: 12.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
            } else {
                DSSliderWithInput(
                    title: "Chiều rộng (Width)",
                    value: Binding(
                        get: { bg.customWidth },
                        set: { var u = config; u.background.customWidth = $0; onUpdate(u, false) }
                    ),
                    range: 40.0...1920.0, step: 4.0, defaultValue: 360.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
                DSSliderWithInput(
                    title: "Chiều cao (Height)",
                    value: Binding(
                        get: { bg.customHeight },
                        set: { var u = config; u.background.customHeight = $0; onUpdate(u, false) }
                    ),
                    range: 24.0...1080.0, step: 2.0, defaultValue: 110.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
            }

            DSPositionControl(
                title: "Lệch tâm nền",
                xValue: Binding(
                    get: { bg.offsetX },
                    set: { var u = config; u.background.offsetX = $0; onUpdate(u, false) }
                ),
                yValue: Binding(
                    get: { bg.offsetY },
                    set: { var u = config; u.background.offsetY = $0; onUpdate(u, false) }
                ),
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    // MARK: - Box Styling Card

    private var boxStylingCard: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Hình dáng & Hòa trộn"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Bo góc (Corner Radius)",
                value: Binding(
                    get: { bg.cornerRadius },
                    set: { var u = config; u.background.cornerRadius = $0; onUpdate(u, false) }
                ),
                range: 0.0...100.0, step: 1.0, defaultValue: 14.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Làm mềm biên (Feather)",
                value: Binding(
                    get: { bg.featherRadius },
                    set: { var u = config; u.background.featherRadius = $0; onUpdate(u, false) }
                ),
                range: 0.0...40.0, step: 0.5, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Độ mờ nền (Opacity)",
                value: Binding(
                    get: { bg.opacity * 100.0 },
                    set: { var u = config; u.background.opacity = $0 / 100.0; onUpdate(u, false) }
                ),
                range: 0.0...100.0, step: 1.0, defaultValue: 85.0, unit: "%",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            HStack {
                Text(String(localized: "Chế độ hòa trộn"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { bg.blendMode },
                    set: { var u = config; u.background.blendMode = $0; onUpdate(u, true) }
                )) {
                    ForEach(TextLayerBlendMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 135)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    // MARK: - Border & Box Shadow Card

    private var borderAndShadowCard: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Viền & Bóng đổ khung nền"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Độ dày viền khung",
                value: Binding(
                    get: { bg.borderWidth },
                    set: { var u = config; u.background.borderWidth = $0; onUpdate(u, false) }
                ),
                range: 0.0...20.0, step: 0.5, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            TextColorSwatchesRow(
                title: "Màu viền khung",
                selectedHex: bg.borderColorHex
            ) { hex in
                var u = config
                u.background.borderColorHex = hex
                onUpdate(u, true)
            }

            Divider().background(DSColors.blockBorder)

            TextColorSwatchesRow(title: "Màu bóng khung (Box Shadow)", selectedHex: bg.shadowColorHex) { hex in
                var u = config
                u.background.shadowColorHex = hex
                u.background.hasShadow = true
                onUpdate(u, true)
            }
            DSSliderWithInput(
                title: "Độ nhòe bóng khung (Shadow Blur)",
                value: Binding(
                    get: { bg.hasShadow ? bg.shadowBlur : 0.0 },
                    set: { val in
                        var u = config
                        u.background.shadowBlur = val
                        u.background.hasShadow = val > 0.01 || u.background.shadowDistance > 0.01
                        onUpdate(u, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Khoảng cách bóng khung (Shadow Distance)",
                value: Binding(
                    get: { bg.hasShadow ? bg.shadowDistance : 0.0 },
                    set: { val in
                        var u = config
                        u.background.shadowDistance = val
                        u.background.hasShadow = val > 0.01 || u.background.shadowBlur > 0.01
                        onUpdate(u, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }
}

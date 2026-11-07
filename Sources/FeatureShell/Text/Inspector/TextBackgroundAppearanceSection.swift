import SwiftUI
import Domain
import DesignSystem

/// Subtab `"Layout"` và `"Style"` cho Tab `"Background"` của Module `Text`.
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
            TextBackgroundLayoutSection(config: config, onUpdate: onUpdate)
            TextBackgroundStyleSection(config: config, onUpdate: onUpdate)
        }
    }
}

// MARK: - Subtab 2: Layout (Size & Offset)

public struct TextBackgroundLayoutSection: View {
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
        let bg = config.background
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Size & Offset")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            Picker("Size Mode", selection: Binding(
                get: { bg.fitToTextBounds },
                set: { fit in
                    var u = config
                    u.background.fitToTextBounds = fit
                    onUpdate(u, true)
                }
            )) {
                Text("Fit to Text").tag(true)
                Text("Custom Size").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if bg.fitToTextBounds {
                DSSliderWithInput(
                    title: "Padding X",
                    value: Binding(
                        get: { bg.paddingX },
                        set: { var u = config; u.background.paddingX = $0; onUpdate(u, false) }
                    ),
                    range: 0.0...140.0, step: 1.0, defaultValue: 24.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
                DSSliderWithInput(
                    title: "Padding Y",
                    value: Binding(
                        get: { bg.paddingY },
                        set: { var u = config; u.background.paddingY = $0; onUpdate(u, false) }
                    ),
                    range: 0.0...90.0, step: 1.0, defaultValue: 12.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
            } else {
                DSSliderWithInput(
                    title: "Width",
                    value: Binding(
                        get: { bg.customWidth },
                        set: { var u = config; u.background.customWidth = $0; onUpdate(u, false) }
                    ),
                    range: 40.0...1920.0, step: 4.0, defaultValue: 360.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
                DSSliderWithInput(
                    title: "Height",
                    value: Binding(
                        get: { bg.customHeight },
                        set: { var u = config; u.background.customHeight = $0; onUpdate(u, false) }
                    ),
                    range: 24.0...1080.0, step: 2.0, defaultValue: 110.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
            }

            Divider().background(DSColors.blockBorder)

            DSPositionControl(
                title: "Offset",
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

            DSToggleRow(
                title: "Animate with Text",
                isOn: Binding(
                    get: { bg.animateWithText },
                    set: { var u = config; u.background.animateWithText = $0; onUpdate(u, true) }
                )
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }
}

// MARK: - Subtab 3: Style (Corner, Feather, Border & Shadow)

public struct TextBackgroundStyleSection: View {
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
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            cornerAndFeatherControls
            Divider().background(DSColors.blockBorder)
            borderControls
            Divider().background(DSColors.blockBorder)
            shadowControls
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var cornerAndFeatherControls: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Corner Radius",
                value: Binding(
                    get: { bg.cornerRadius },
                    set: { var u = config; u.background.cornerRadius = $0; onUpdate(u, false) }
                ),
                range: 0.0...100.0, step: 1.0, defaultValue: 14.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Feather",
                value: Binding(
                    get: { bg.featherRadius },
                    set: { var u = config; u.background.featherRadius = $0; onUpdate(u, false) }
                ),
                range: 0.0...40.0, step: 0.5, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
    }

    private var borderControls: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            TextColorSwatchesRow(
                title: "Border Color",
                selectedHex: bg.borderColorHex,
                allowNone: true
            ) { hex in
                var u = config
                if hex.uppercased() == "NONE" {
                    u.background.borderColorHex = "NONE"
                } else {
                    u.background.borderColorHex = hex
                    if u.background.borderWidth <= 0.1 {
                        u.background.borderWidth = 2.0
                    }
                }
                onUpdate(u, true)
            }

            DSSliderWithInput(
                title: "Border Width",
                value: Binding(
                    get: { bg.borderWidth },
                    set: { var u = config; u.background.borderWidth = $0; onUpdate(u, false) }
                ),
                range: 0.0...20.0, step: 0.5, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
    }

    private var shadowControls: some View {
        let bg = config.background
        let hasShadow = bg.hasShadow && bg.shadowColorHex.uppercased() != "NONE"
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            TextColorSwatchesRow(
                title: "Shadow Color",
                selectedHex: hasShadow ? bg.shadowColorHex : "NONE",
                allowNone: true
            ) { hex in
                var u = config
                u.background.hasShadow = true
                if hex.uppercased() == "NONE" {
                    u.background.shadowColorHex = "NONE"
                } else {
                    u.background.shadowColorHex = hex
                    if u.background.shadowBlur <= 0.1 && u.background.shadowDistance <= 0.1 {
                        u.background.shadowBlur = 8.0
                        u.background.shadowDistance = 4.0
                    }
                }
                onUpdate(u, true)
            }

            DSSliderWithInput(
                title: "Shadow Blur",
                value: Binding(
                    get: { bg.shadowBlur },
                    set: { val in
                        var u = config
                        u.background.hasShadow = true
                        u.background.shadowBlur = val
                        onUpdate(u, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 8.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Shadow Distance",
                value: Binding(
                    get: { bg.shadowDistance },
                    set: { val in
                        var u = config
                        u.background.hasShadow = true
                        u.background.shadowDistance = val
                        onUpdate(u, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 4.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Shadow Angle",
                value: Binding(
                    get: { bg.shadowAngleDegrees },
                    set: { var u = config; u.background.hasShadow = true; u.background.shadowAngleDegrees = $0; onUpdate(u, false) }
                ),
                range: -180.0...180.0, step: 1.0, defaultValue: -45.0, unit: "°",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
    }
}

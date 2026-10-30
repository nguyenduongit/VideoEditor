import SwiftUI
import Domain
import DesignSystem

/// Bảng Inspector chuyên dụng cho clip Hiệu ứng thị giác (Effect Layer).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct EffectInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            headerSection
            Divider().background(DSColors.blockBorder)
            slidersSection
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var headerSection: some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .fill(DSColors.clipEffect.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: currentConfig.type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DSColors.clipEffect)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(currentConfig.type.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)

                Text(currentConfig.type.description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "THÔNG SỐ HIỆU ỨNG"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            // 1. Cường độ (Intensity)
            DSSlider(
                title: String(localized: "Cường độ"),
                value: Binding(
                    get: { currentConfig.intensity },
                    set: { val in updateConfig { $0.intensity = val } }
                ),
                range: 0.0...1.0,
                step: 0.01,
                unit: "%",
                onEditingChanged: { editing in
                    if !editing { commitConfig() }
                }
            )

            // 2. Tốc độ (Speed)
            DSSlider(
                title: String(localized: "Tốc độ"),
                value: Binding(
                    get: { currentConfig.speed },
                    set: { val in updateConfig { $0.speed = val } }
                ),
                range: 0.2...3.0,
                step: 0.05,
                unit: "x",
                onEditingChanged: { editing in
                    if !editing { commitConfig() }
                }
            )

            // 3. Bán kính làm mờ (chỉ cho Cinematic Blur)
            if currentConfig.type == .cinematicBlur {
                DSSlider(
                    title: String(localized: "Bán kính mờ"),
                    value: Binding(
                        get: { currentConfig.blurRadius },
                        set: { val in updateConfig { $0.blurRadius = val } }
                    ),
                    range: 2.0...80.0,
                    step: 1.0,
                    unit: "px",
                    onEditingChanged: { editing in
                        if !editing { commitConfig() }
                    }
                )
            }
        }
    }

    private var currentConfig: EffectConfiguration {
        let str = viewModel.liveProperties["effectConfig"]?.asString
            ?? viewModel.selectedClip?.properties["effectConfig"]?.asString ?? ""
        return EffectConfiguration.decode(from: str) ?? EffectConfiguration()
    }

    private func updateConfig(_ mutate: (inout EffectConfiguration) -> Void) {
        var cfg = currentConfig
        mutate(&cfg)
        if let json = cfg.encodeToJSON() {
            viewModel.updateLiveText(key: "effectConfig", text: json)
            viewModel.updateLiveValue(key: "intensity", value: cfg.intensity)
            viewModel.updateLiveValue(key: "speed", value: cfg.speed)
        }
    }

    private func commitConfig() {
        if let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "effectConfig", text: json)
        }
    }
}

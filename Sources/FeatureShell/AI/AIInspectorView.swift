import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Unified Inspector view for the AI tab, providing 2 accordions:
/// 1. Auto Pan (horizontal subject tracking)
/// 2. Kéo dài chân (3-zone vertical body proportion with dynamic depth lines & constant 0.9-1.3 stretch ratio)
/// Both share a single Apple Vision analysis pass.
/// Complies with R3.1, R8.1, and R8.2 of AGENTS.md.
public struct AIInspectorView: View {
    @Bindable var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var isAnalyzing: Bool {
        guard let clip = viewModel.selectedClip else { return false }
        return viewModel.timelineViewModel?.isTrackingSubject(for: clip.id) ?? false
    }

    private var analysisProgress: Double {
        guard let clip = viewModel.selectedClip else { return 0.0 }
        return viewModel.timelineViewModel?.trackingProgress(for: clip.id) ?? 0.0
    }

    private var autoPanConfig: AutoPanConfiguration {
        if let live = viewModel.liveProperties["autoPanConfig"]?.asString,
           let config = AutoPanConfiguration.decode(from: live) {
            return config
        }
        if let prop = viewModel.selectedClip?.properties["autoPanConfig"]?.asString,
           let config = AutoPanConfiguration.decode(from: prop) {
            return config
        }
        return .default
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            sharedVisionAnalysisCard

            DSCollapsibleSection(
                title: "Auto Pan",
                defaultExpanded: true,
                onReset: { resetAutoPan() }
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    autoPanToggleRow
                    smoothnessSlider
                    autoPanDescriptionNote
                }
            }

            DSCollapsibleSection(
                title: "Kéo dài chân",
                defaultExpanded: true,
                onReset: { resetLegStretch() }
            ) {
                GridInspectorView(viewModel: viewModel)
            }
        }
        .onChange(of: viewModel.selectedClip?.properties["autoPanConfig"]) {
            viewModel.syncWithSelection()
        }
    }

    private var sharedVisionAnalysisCard: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: { startAnalysis() }) {
                HStack(spacing: 4) {
                    if isAnalyzing {
                        ProgressView()
                            .controlSize(.small)
                        Text("\(Int(analysisProgress * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Analyze")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isAnalyzing ? DSColors.textSecondary.opacity(0.4) : DSColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzing)

            if !autoPanConfig.keyframes.isEmpty {
                Text("\(autoPanConfig.keyframes.count) frame")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            } else if isAnalyzing {
                Text("Đang quét...")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.toggleCyan)
            }

            Spacer()

            if !autoPanConfig.keyframes.isEmpty && !isAnalyzing {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.18, green: 0.8, blue: 0.35))
                    .help("Đã phân tích hoàn tất")
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DSColors.windowBackground.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var autoPanToggleRow: some View {
        let binding = Binding<Bool>(
            get: { autoPanConfig.isEnabled },
            set: { newValue in
                var updated = autoPanConfig
                updated.isEnabled = newValue
                commitAutoPanConfig(updated)
            }
        )
        return DSToggleRow(title: "Bật Auto Pan", isOn: binding)
    }

    private var smoothnessSlider: some View {
        let binding = Binding<Double>(
            get: { autoPanConfig.smoothness },
            set: { newValue in
                var updated = autoPanConfig
                updated.smoothness = newValue
                updateLiveAutoPanConfig(updated)
            }
        )
        return DSSliderWithInput(
            title: "Độ mượt mà",
            value: binding,
            range: 0.0...1.0,
            step: 0.05,
            defaultValue: 0.5,
            unit: "%",
            onEditingChanged: { editing in
                if !editing {
                    commitAutoPanConfig(autoPanConfig)
                }
            }
        )
        .opacity(autoPanConfig.isEnabled ? 1.0 : 0.45)
        .disabled(!autoPanConfig.isEnabled)
    }

    private var autoPanDescriptionNote: some View {
        Text("Tự động căn giữa nhân vật theo trục ngang (X). Camera chỉ lia trong phạm vi khung hình gốc để không lộ viền đen.")
            .font(.system(size: 11))
            .foregroundStyle(DSColors.textSecondary)
            .lineSpacing(2)
    }

    private func updateLiveAutoPanConfig(_ config: AutoPanConfiguration) {
        if let encoded = config.encodeToString() {
            viewModel.updateLiveText(key: "autoPanConfig", text: encoded)
        }
    }

    private func commitAutoPanConfig(_ config: AutoPanConfiguration) {
        if let encoded = config.encodeToString() {
            viewModel.updateDiscreteString(key: "autoPanConfig", value: encoded)
        }
    }

    private func resetAutoPan() {
        var updated = autoPanConfig
        updated.isEnabled = false
        updated.smoothness = 0.5
        commitAutoPanConfig(updated)
    }

    private func resetLegStretch() {
        let resetCfg = GridConfiguration(rows: 3, columns: 1, isEnabled: false, legStretchRatio: 1.0, isDynamicLines: true)
        if let encoded = resetCfg.encodeToString() {
            viewModel.updateDiscreteString(key: "gridConfig", value: encoded)
        }
    }

    private func startAnalysis() {
        guard let clip = viewModel.selectedClip else { return }
        viewModel.timelineViewModel?.startSubjectTracking(
            for: clip.id,
            smoothness: autoPanConfig.smoothness
        )
    }
}

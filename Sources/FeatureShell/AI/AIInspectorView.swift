import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Inspector view for the AI tab, providing Auto Pan controls.
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
            DSCollapsibleSection(
                title: "Auto Pan",
                defaultExpanded: true,
                onReset: { resetAutoPan() }
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    toggleRow
                    statusIndicator
                    actionButton
                    smoothnessSlider
                    descriptionNote
                }
            }
        }
        .onChange(of: viewModel.selectedClip?.properties["autoPanConfig"]) {
            viewModel.syncWithSelection()
        }
    }

    private var toggleRow: some View {
        let binding = Binding<Bool>(
            get: { autoPanConfig.isEnabled },
            set: { newValue in
                var updated = autoPanConfig
                updated.isEnabled = newValue
                commitConfig(updated)
            }
        )
        return DSToggleRow(title: "Auto Pan", isOn: binding)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isAnalyzing {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Đang nhận diện nhân vật... \(Int(analysisProgress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColors.toggleCyan)
                }
                ProgressView(value: analysisProgress, total: 1.0)
                    .tint(DSColors.toggleCyan)
            }
            .padding(.vertical, 2)
        } else if autoPanConfig.keyframes.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.yellow.opacity(0.85))
                Text("Chưa phân tích nhân vật")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.green.opacity(0.9))
                Text("Đã phân tích (\(autoPanConfig.keyframes.count) điểm tracking)")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textPrimary)
            }
        }
    }

    private var actionButton: some View {
        DSActionButton(
            title: isAnalyzing ? "Đang phân tích..." : (autoPanConfig.keyframes.isEmpty ? "Phân tích nhân vật" : "Phân tích lại")
        ) {
            startAnalysis()
        }
        .disabled(isAnalyzing)
        .opacity(isAnalyzing ? 0.6 : 1.0)
    }

    private var smoothnessSlider: some View {
        let binding = Binding<Double>(
            get: { autoPanConfig.smoothness },
            set: { newValue in
                var updated = autoPanConfig
                updated.smoothness = newValue
                updateLiveConfig(updated)
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
                    commitConfig(autoPanConfig)
                }
            }
        )
    }

    private var descriptionNote: some View {
        Text("Auto Pan tự động áp dụng Aspect Fill và lia khung hình để nhân vật chính luôn ở giữa theo trục dọc. Camera chỉ pan trong phạm vi video, tự động dừng lại khi chạm biên để không xuất hiện viền đen. Bạn có thể điều chỉnh thêm Tỉ lệ (Scale) ở tab Video.")
            .font(.system(size: 11))
            .foregroundStyle(DSColors.textSecondary)
            .lineSpacing(2)
            .padding(.top, DSSpacing.xs)
    }

    private func updateLiveConfig(_ config: AutoPanConfiguration) {
        if let encoded = config.encodeToString() {
            viewModel.updateLiveText(key: "autoPanConfig", text: encoded)
        }
    }

    private func commitConfig(_ config: AutoPanConfiguration) {
        if let encoded = config.encodeToString() {
            viewModel.updateDiscreteString(key: "autoPanConfig", value: encoded)
        }
    }

    private func resetAutoPan() {
        commitConfig(.default)
    }

    private func startAnalysis() {
        guard let clip = viewModel.selectedClip else { return }
        viewModel.timelineViewModel?.startSubjectTracking(
            for: clip.id,
            smoothness: autoPanConfig.smoothness
        )
    }
}

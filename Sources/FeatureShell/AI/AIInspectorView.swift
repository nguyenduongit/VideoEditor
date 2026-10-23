import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Inspector view for the AI tab, providing Auto Pan controls.
/// Complies with R3.1, R8.1, and R8.2 of AGENTS.md.
public struct AIInspectorView: View {
    @Bindable var viewModel: InspectorViewModel

    @State private var isAnalyzing: Bool = false
    @State private var analysisProgress: Double = 0.0
    @State private var errorMessage: String? = nil

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var autoPanConfig: AutoPanConfiguration {
        guard let str = viewModel.liveProperties["autoPanConfig"]?.asString,
              let config = AutoPanConfiguration.decode(from: str) else {
            return .default
        }
        return config
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
                    zoomSlider
                    smoothnessSlider
                    descriptionNote
                }
            }
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

    private var zoomSlider: some View {
        let binding = Binding<Double>(
            get: { autoPanConfig.zoom },
            set: { newValue in
                var updated = autoPanConfig
                updated.zoom = newValue
                updateLiveConfig(updated)
            }
        )
        return DSSliderWithInput(
            title: "Thu phóng",
            value: binding,
            range: 1.0...2.5,
            step: 0.05,
            defaultValue: 1.25,
            unit: "×",
            onEditingChanged: { editing in
                if !editing {
                    commitConfig(autoPanConfig)
                }
            }
        )
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
        Text("Auto Pan tự động di chuyển khung hình để nhân vật chính luôn ở giữa theo trục dọc. Camera chỉ pan trong phạm vi video, tự động dừng lại khi chạm biên để không xuất hiện viền đen.")
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
        guard let clip = viewModel.selectedClip, let url = clip.mediaURL else { return }
        guard let trackingService = viewModel.timelineViewModel?.subjectTrackingService else { return }

        isAnalyzing = true
        analysisProgress = 0.0

        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let sourceDuration = CMTimeMultiplyByFloat64(clip.timeRange.duration, multiplier: speed)
        let mediaRange = CMTimeRange(start: clip.sourceStartTime, duration: sourceDuration)

        Task {
            do {
                let rawKeyframes = try await trackingService.trackSubject(
                    in: url,
                    timeRange: mediaRange,
                    samplesPerSecond: 1.5,
                    smoothness: autoPanConfig.smoothness,
                    onProgress: { progress in
                        Task { @MainActor in
                            analysisProgress = progress
                        }
                    }
                )
                let keyframes = rawKeyframes.map { kf in
                    AutoPanKeyframe(
                        timeSeconds: speed == 1.0 ? kf.timeSeconds : (kf.timeSeconds / speed),
                        normalizedX: kf.normalizedX,
                        confidence: kf.confidence
                    )
                }
                await MainActor.run {
                    var updated = autoPanConfig
                    updated.isEnabled = true
                    if updated.zoom < 1.05 {
                        updated.zoom = 1.25
                    }
                    updated.keyframes = keyframes
                    commitConfig(updated)
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }
}

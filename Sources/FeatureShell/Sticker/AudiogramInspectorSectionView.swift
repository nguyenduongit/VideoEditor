import SwiftUI
import Domain
import DesignSystem

/// Inspector customization card for Audio-Reactive Audiogram Stickers (`style`, `colors`, `sensitivity`, `bars`, `glow`, `beat pulse`).
public struct AudiogramInspectorSectionView: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var isPickingPrimary = false
    @State private var isPickingSecondary = false

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var audiogram: StickerAudiogramConfiguration {
        viewModel.stickerConfiguration.audiogram ?? StickerAudiogramConfiguration()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            headerWithStatusRow
            stylePickerRow
            colorPickersRow
            slidersSection
            togglesSection
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var headerWithStatusRow: some View {
        let tempo = viewModel.resolvedAudioTempoForSelectedClip
        return HStack(spacing: DSSpacing.xs) {
            Text("AUDIO VISUALIZER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            if tempo.hasAudioUnderneath {
                let label = tempo.bpm.map { "\(tempo.sourceClipName ?? "Audio") • \(Int($0)) BPM" }
                    ?? (tempo.sourceClipName ?? "Audio Track")
                Label(label, systemImage: "waveform")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DSColors.toggleCyan)
                    .lineLimit(1)
            } else {
                Text("Preview Wave")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
    }

    private var stylePickerRow: some View {
        HStack {
            Text("Style")
                .font(.system(size: 12))
                .foregroundStyle(DSColors.textPrimary)
            Spacer()
            Picker("Style", selection: styleBinding) {
                ForEach(StickerAudiogramStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .frame(width: 175)
        }
    }

    private var colorPickersRow: some View {
        HStack(spacing: DSSpacing.md) {
            colorSwatchButton(title: "Primary", hex: audiogram.primaryColorHex, isPresented: $isPickingPrimary) { newHex in
                updateAudiogram(commit: true) { $0.primaryColorHex = newHex }
            }
            colorSwatchButton(title: "Accent", hex: audiogram.secondaryColorHex, isPresented: $isPickingSecondary) { newHex in
                updateAudiogram(commit: true) { $0.secondaryColorHex = newHex }
            }
        }
    }

    private func colorSwatchButton(
        title: String,
        hex: String,
        isPresented: Binding<Bool>,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Button {
            isPresented.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .frame(maxWidth: .infinity)
            .background(DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: isPresented, arrowEdge: .bottom) {
            DSColorSpectrumPicker(initialHex: hex, onSelect: onSelect)
        }
    }

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Sensitivity",
                value: Binding(
                    get: { audiogram.sensitivity },
                    set: { val in updateAudiogram(commit: false) { $0.sensitivity = val } }
                ),
                range: 0.4...2.5,
                step: 0.05,
                defaultValue: 1.15,
                unit: "x",
                onEditingChanged: commitIfFinished
            )

            DSSliderWithInput(
                title: "Bar Density",
                value: Binding(
                    get: { Double(audiogram.barCount) },
                    set: { val in updateAudiogram(commit: false) { $0.barCount = Int(val.rounded()) } }
                ),
                range: 8...36,
                step: 2,
                defaultValue: 20,
                onEditingChanged: commitIfFinished
            )
        }
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            DSToggleRow(
                title: "Beat Punch",
                isOn: Binding(
                    get: { audiogram.reactsToBeat },
                    set: { val in updateAudiogram(commit: true) { $0.reactsToBeat = val } }
                )
            )
            DSToggleRow(
                title: "Reactive Glow",
                isOn: Binding(
                    get: { audiogram.isGlowEnabled },
                    set: { val in updateAudiogram(commit: true) { $0.isGlowEnabled = val } }
                )
            )
        }
    }

    private var styleBinding: Binding<StickerAudiogramStyle> {
        Binding(
            get: { audiogram.style },
            set: { newStyle in
                updateAudiogram(commit: true) { $0.style = newStyle }
            }
        )
    }

    private func commitIfFinished(_ isEditing: Bool) {
        if !isEditing {
            viewModel.updateStickerConfiguration(viewModel.stickerConfiguration, commit: true)
        }
    }

    private func updateAudiogram(commit: Bool, _ mutate: (inout StickerAudiogramConfiguration) -> Void) {
        var cfg = viewModel.stickerConfiguration
        var ag = cfg.audiogram ?? StickerAudiogramConfiguration()
        mutate(&ag)
        cfg.audiogram = ag
        cfg.systemSymbolFallback = ag.style.symbolName
        viewModel.updateStickerConfiguration(cfg, commit: commit)
    }
}

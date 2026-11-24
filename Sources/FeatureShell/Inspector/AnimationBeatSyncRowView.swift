import SwiftUI
import Domain
import DesignSystem

/// Shared compact Beat Sync row (toggle + Bar Multiplier picker + Auto Audio BPM indicator / manual fallback)
/// used identically across both Text Animation and Sticker Animation Inspector panels.
public struct AnimationBeatSyncRowView: View {
    @Binding private var isBeatSyncEnabled: Bool
    @Binding private var beatBarMode: AnimationBeatBarMode
    @Binding private var beatBPM: Double
    private let audioTempo: ResolvedAudioTempo
    private let onEditingChanged: (Bool) -> Void

    public init(
        isBeatSyncEnabled: Binding<Bool>,
        beatBarMode: Binding<AnimationBeatBarMode>,
        beatBPM: Binding<Double>,
        audioTempo: ResolvedAudioTempo,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self._isBeatSyncEnabled = isBeatSyncEnabled
        self._beatBarMode = beatBarMode
        self._beatBPM = beatBPM
        self.audioTempo = audioTempo
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Toggle(isOn: $isBeatSyncEnabled) {
                Label("Beat Sync", systemImage: "metronome")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer(minLength: 4)

            if isBeatSyncEnabled {
                barModePicker
                tempoBadgeOrFallback
            }
        }
    }

    private var barModePicker: some View {
        Picker("Bar", selection: $beatBarMode) {
            ForEach(AnimationBeatBarMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 88)
        .help("Musical cycle unit for Loop phase")
    }

    @ViewBuilder
    private var tempoBadgeOrFallback: some View {
        if let detectedBPM = audioTempo.bpm {
            HStack(spacing: 3) {
                Image(systemName: "waveform")
                    .font(.system(size: 9, weight: .semibold))
                Text("\(Int(detectedBPM)) BPM")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(DSColors.toggleCyan)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(DSColors.toggleCyan.opacity(0.14))
            .clipShape(Capsule())
            .help("Synced automatically to audio track: \(audioTempo.sourceClipName ?? "Audio")")
        } else if audioTempo.needsBeatAnalysis {
            Text("Analyzing…")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
        } else {
            DSNumberInput(
                value: $beatBPM,
                step: 1.0, min: 40.0, max: 240.0, unit: "BPM", fractionDigits: 0,
                isFlexibleWidth: false, onEditingChanged: onEditingChanged
            )
            .frame(width: 96)
            .help("Fallback manual tempo when no audio clip sits underneath")
        }
    }
}

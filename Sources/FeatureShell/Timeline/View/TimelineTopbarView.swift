import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelineTopbarView: View {
    private let currentTime: CMTime
    @Binding private var pixelsPerSecond: CGFloat
    private let minPixelsPerSecond: CGFloat
    private let maxPixelsPerSecond: CGFloat
    private let zoomPercentageText: String
    private let onZoomIn: () -> Void
    private let onZoomOut: () -> Void
    private let onResetZoom: () -> Void
    private let onSplit: () -> Void
    private let canSplit: Bool
    private let canSyncAudio: Bool
    private let isSyncingAudio: Bool
    private let onSyncAudio: () -> Void

    public init(
        currentTime: CMTime = .zero,
        pixelsPerSecond: Binding<CGFloat>,
        minPixelsPerSecond: CGFloat = TimelineZoom.minPPS(),
        maxPixelsPerSecond: CGFloat = TimelineZoom.maxPPS(),
        zoomPercentageText: String = "100%",
        canSplit: Bool = false,
        canSyncAudio: Bool = false,
        isSyncingAudio: Bool = false,
        onZoomIn: @escaping () -> Void = {},
        onZoomOut: @escaping () -> Void = {},
        onResetZoom: @escaping () -> Void = {},
        onSplit: @escaping () -> Void = {},
        onSyncAudio: @escaping () -> Void = {}
    ) {
        self.currentTime = currentTime
        self._pixelsPerSecond = pixelsPerSecond
        self.minPixelsPerSecond = minPixelsPerSecond
        self.maxPixelsPerSecond = maxPixelsPerSecond
        self.zoomPercentageText = zoomPercentageText
        self.canSplit = canSplit
        self.canSyncAudio = canSyncAudio
        self.isSyncingAudio = isSyncingAudio
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onResetZoom = onResetZoom
        self.onSplit = onSplit
        self.onSyncAudio = onSyncAudio
    }

    public init(currentTime: CMTime = .zero) {
        self.currentTime = currentTime
        self._pixelsPerSecond = .constant(TimelineZoom.defaultPPS)
        self.minPixelsPerSecond = TimelineZoom.minPPS()
        self.maxPixelsPerSecond = TimelineZoom.maxPPS()
        self.zoomPercentageText = "100%"
        self.canSplit = false
        self.canSyncAudio = false
        self.isSyncingAudio = false
        self.onZoomIn = {}
        self.onZoomOut = {}
        self.onResetZoom = {}
        self.onSplit = {}
        self.onSyncAudio = {}
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            timecodeDisplay
            if canSplit {
                splitButton
            }
            if canSyncAudio {
                syncAudioButton
            }
            Spacer()
            zoomControls
        }
        .animation(.easeInOut(duration: 0.15), value: canSplit)
        .animation(.easeInOut(duration: 0.15), value: canSyncAudio)
        .padding(.horizontal, DSSpacing.lg)
        .frame(height: DSSize.timelineTopbarHeight)
        .background(DSColors.blockBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
    }

    private var splitButton: some View {
        TimelineToolbarActionButton(
            icon: "scissors",
            title: "Split",
            help: "Split clip at playhead (⌘B / S)",
            action: onSplit
        )
    }

    private var syncAudioButton: some View {
        TimelineToolbarActionButton(
            icon: "waveform.badge.magnifyingglass",
            title: "Sync Audio",
            isLoading: isSyncingAudio,
            isDisabled: isSyncingAudio,
            help: "Tự động khớp âm thanh của 2 clip được chọn theo dạng sóng (waveform)",
            action: onSyncAudio
        )
    }

    private var timecodeDisplay: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)
            Text(formattedTimecode)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DSColors.textPrimary)
        }
    }

    private var zoomControls: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: onZoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Zoom Out (⌘-)")

            Slider(
                value: $pixelsPerSecond,
                in: minPixelsPerSecond...max(minPixelsPerSecond + 0.1, maxPixelsPerSecond)
            )
            .frame(width: 90)
            .controlSize(.mini)

            Button(action: onZoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Zoom In (⌘+)")

            Button(action: onResetZoom) {
                Text(zoomPercentageText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .help("Reset Zoom (⇧Z)")
        }
    }

    private var formattedTimecode: String {
        TimeRational.formatTimecode(time: currentTime)
    }
}

private struct TimelineToolbarActionButton: View {
    let icon: String
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.65)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isDisabled ? DSColors.textSecondary.opacity(0.6) : DSColors.textPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .fill(isHovered && !isDisabled ? Color.white.opacity(0.10) : DSColors.layerTrackBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(isHovered && !isDisabled ? Color.white.opacity(0.20) : DSColors.blockBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { isHovered = $0 }
        .help(help)
    }
}


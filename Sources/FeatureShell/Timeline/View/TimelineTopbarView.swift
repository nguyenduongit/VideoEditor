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
    private let canExtractAudio: Bool
    private let onExtractAudio: () -> Void
    private let canSyncAudio: Bool
    private let isSyncingAudio: Bool
    private let onSyncAudio: () -> Void
    private let canMarkBeats: Bool
    private let isDetectingBeats: Bool
    private let hasBeats: Bool
    private let activeBeatMode: AudioBeatDetectionMode?
    private let onAutoMarkBeats: (AudioBeatDetectionMode) -> Void
    private let onToggleBeatAtPlayhead: () -> Void
    private let onClearBeats: () -> Void

    public init(
        currentTime: CMTime = .zero,
        pixelsPerSecond: Binding<CGFloat>,
        minPixelsPerSecond: CGFloat = TimelineZoom.minPPS(),
        maxPixelsPerSecond: CGFloat = TimelineZoom.maxPPS(),
        zoomPercentageText: String = "100%",
        canSplit: Bool = false,
        canExtractAudio: Bool = false,
        canSyncAudio: Bool = false,
        isSyncingAudio: Bool = false,
        canMarkBeats: Bool = false,
        isDetectingBeats: Bool = false,
        hasBeats: Bool = false,
        activeBeatMode: AudioBeatDetectionMode? = nil,
        onZoomIn: @escaping () -> Void = {},
        onZoomOut: @escaping () -> Void = {},
        onResetZoom: @escaping () -> Void = {},
        onSplit: @escaping () -> Void = {},
        onExtractAudio: @escaping () -> Void = {},
        onSyncAudio: @escaping () -> Void = {},
        onAutoMarkBeats: @escaping (AudioBeatDetectionMode) -> Void = { _ in },
        onToggleBeatAtPlayhead: @escaping () -> Void = {},
        onClearBeats: @escaping () -> Void = {}
    ) {
        self.currentTime = currentTime
        self._pixelsPerSecond = pixelsPerSecond
        self.minPixelsPerSecond = minPixelsPerSecond
        self.maxPixelsPerSecond = maxPixelsPerSecond
        self.zoomPercentageText = zoomPercentageText
        self.canSplit = canSplit
        self.canExtractAudio = canExtractAudio
        self.onExtractAudio = onExtractAudio
        self.canSyncAudio = canSyncAudio
        self.isSyncingAudio = isSyncingAudio
        self.canMarkBeats = canMarkBeats
        self.isDetectingBeats = isDetectingBeats
        self.hasBeats = hasBeats
        self.activeBeatMode = activeBeatMode
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onResetZoom = onResetZoom
        self.onSplit = onSplit
        self.onSyncAudio = onSyncAudio
        self.onAutoMarkBeats = onAutoMarkBeats
        self.onToggleBeatAtPlayhead = onToggleBeatAtPlayhead
        self.onClearBeats = onClearBeats
    }

    public init(currentTime: CMTime = .zero) {
        self.init(
            currentTime: currentTime,
            pixelsPerSecond: .constant(TimelineZoom.defaultPPS)
        )
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            timecodeDisplay
            if canSplit {
                splitButton
            }
            if canExtractAudio {
                extractAudioButton
            }
            if canSyncAudio {
                syncAudioButton
            }
            if canMarkBeats {
                beatActionButtons
            }
            Spacer()
            zoomControls
        }
        .animation(.easeInOut(duration: 0.15), value: canSplit)
        .animation(.easeInOut(duration: 0.15), value: canExtractAudio)
        .animation(.easeInOut(duration: 0.15), value: canSyncAudio)
        .animation(.easeInOut(duration: 0.15), value: canMarkBeats)
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

    private var extractAudioButton: some View {
        TimelineToolbarActionButton(
            icon: "waveform.badge.plus",
            title: "Tách âm thanh",
            help: "Tách âm thanh từ video clip thành audio clip riêng biệt (⌘E)",
            action: onExtractAudio
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

    private var beatActionButtons: some View {
        HStack(spacing: DSSpacing.xs) {
            TimelineToolbarActionButton(
                icon: "metronome.fill",
                title: "Beat 1",
                isLoading: isDetectingBeats && activeBeatMode == .majorOnly,
                isDisabled: isDetectingBeats,
                isActive: hasBeats && activeBeatMode == .majorOnly,
                help: "Tự động đánh dấu Nhịp 1 - Phách mạnh (Kick drum)",
                action: { onAutoMarkBeats(.majorOnly) }
            )

            TimelineToolbarActionButton(
                icon: "waveform.path.ecg",
                title: "Beat 2",
                isLoading: isDetectingBeats && activeBeatMode == .allBeats,
                isDisabled: isDetectingBeats,
                isActive: hasBeats && activeBeatMode == .allBeats,
                help: "Tự động đánh dấu Nhịp 2 - Nhịp chi tiết (Kick & Snare)",
                action: { onAutoMarkBeats(.allBeats) }
            )

            TimelineToolbarActionButton(
                icon: "bookmark.fill",
                title: "Mark (M)",
                isDisabled: isDetectingBeats,
                help: "Thêm hoặc xóa điểm nhịp thủ công tại vị trí Playhead (Phím tắt: M)",
                action: onToggleBeatAtPlayhead
            )

            if hasBeats {
                TimelineToolbarActionButton(
                    icon: "xmark.circle",
                    title: "Clear",
                    isDisabled: isDetectingBeats,
                    help: "Xóa toàn bộ điểm nhịp trên clip đang chọn",
                    action: onClearBeats
                )
            }
        }
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
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
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
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Zoom In (⌘+)")

            Button(action: onResetZoom) {
                Text(zoomPercentageText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(minWidth: 44, minHeight: 20, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reset Zoom (⇧Z)")
        }
    }

    private var formattedTimecode: String {
        TimeRational.formatTimecode(time: currentTime)
    }
}

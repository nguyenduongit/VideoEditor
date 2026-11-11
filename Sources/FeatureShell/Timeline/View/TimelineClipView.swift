import SwiftUI
import AppKit
import CoreMedia
import Domain
import DesignSystem

public struct TimelineClipView: View {
    let clip: TimelineClip
    let height: CGFloat
    let pixelsPerSecond: CGFloat
    let isLocked: Bool
    let isMuted: Bool
    let isSelected: Bool
    let previousClipEnd: CMTime?
    let nextClipStart: CMTime?
    let snapCandidates: [CMTime]
    let beatTimes: [CMTime]
    let thumbnailService: (any TimelineThumbnailServiceProtocol)?
    let waveformService: (any AudioWaveformServiceProtocol)?
    let onSelect: (Bool) -> Void
    let onTrim: (CMTime, CMTime, CMTime?) -> Void
    let onMove: (CMTime, CGFloat) -> Void
    let onMoveEnd: () -> Void
    let groupDragOffset: CGFloat
    let groupTrimLeftOffset: CGFloat
    let groupTrimRightOffset: CGFloat
    let isMultiSelected: Bool
    let onTrimChange: ((Bool, CGFloat) -> Void)?
    let onTrimEnd: ((Bool) -> Void)?
    let onExtractAudio: (() -> Void)?
    let onSavePreset: ((TimelineClip) -> Void)?
    let onSeek: ((CMTime) -> Void)?
    let onUpdateProperties: ((UUID, [String: PropertyValue], Bool) -> Void)?

    @State var dragOffset: CGFloat = 0
    @State var dragY: CGFloat = 0
    @State var trimLeftOffset: CGFloat = 0
    @State var trimRightOffset: CGFloat = 0
    @State var isHoveringLeftTrim: Bool = false
    @State var isHoveringRightTrim: Bool = false
    @State var isTrimming: Bool = false

    public init(
        clip: TimelineClip, height: CGFloat, pixelsPerSecond: CGFloat, isLocked: Bool,
        isMuted: Bool = false, isSelected: Bool = false, groupDragOffset: CGFloat = 0,
        groupTrimLeftOffset: CGFloat = 0, groupTrimRightOffset: CGFloat = 0, isMultiSelected: Bool = false,
        previousClipEnd: CMTime? = nil, nextClipStart: CMTime? = nil, snapCandidates: [CMTime] = [],
        beatTimes: [CMTime] = [],
        thumbnailService: (any TimelineThumbnailServiceProtocol)? = nil,
        waveformService: (any AudioWaveformServiceProtocol)? = nil,
        onSelect: @escaping (Bool) -> Void = { _ in },
        onSeek: ((CMTime) -> Void)? = nil,
        onTrim: @escaping (CMTime, CMTime, CMTime?) -> Void,
        onTrimChange: ((Bool, CGFloat) -> Void)? = nil,
        onTrimEnd: ((Bool) -> Void)? = nil,
        onExtractAudio: (() -> Void)? = nil,
        onSavePreset: ((TimelineClip) -> Void)? = nil,
        onMove: @escaping (CMTime, CGFloat) -> Void,
        onMoveEnd: @escaping () -> Void,
        onUpdateProperties: ((UUID, [String: PropertyValue], Bool) -> Void)? = nil
    ) {
        self.clip = clip; self.height = height; self.pixelsPerSecond = pixelsPerSecond
        self.isLocked = isLocked; self.isMuted = isMuted; self.isSelected = isSelected
        self.groupDragOffset = groupDragOffset
        self.groupTrimLeftOffset = groupTrimLeftOffset; self.groupTrimRightOffset = groupTrimRightOffset
        self.isMultiSelected = isMultiSelected
        self.previousClipEnd = previousClipEnd; self.nextClipStart = nextClipStart
        self.snapCandidates = snapCandidates; self.beatTimes = beatTimes
        self.thumbnailService = thumbnailService
        self.waveformService = waveformService; self.onSelect = onSelect; self.onSeek = onSeek
        self.onTrim = onTrim; self.onTrimChange = onTrimChange; self.onTrimEnd = onTrimEnd
        self.onExtractAudio = onExtractAudio; self.onSavePreset = onSavePreset
        self.onMove = onMove; self.onMoveEnd = onMoveEnd
        self.onUpdateProperties = onUpdateProperties
    }

    public var body: some View {
        let clipWidth = max(28, baseWidth + effectiveTrimRight - effectiveTrimLeft)
        let effectiveDragOffset = isSelected && groupDragOffset != 0 ? groupDragOffset : dragOffset
        let clipX = max(0, baseX + effectiveDragOffset + effectiveTrimLeft)

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DSRadius.clip)
                .fill(clipColor.opacity(0.85))

            clipContent(width: clipWidth)

            ClipBorderOverlayView(
                isSelected: isSelected,
                isHoveringLeftTrim: isHoveringLeftTrim,
                isHoveringRightTrim: isHoveringRightTrim
            )
        }
        .frame(width: clipWidth, height: height - 4)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.clip))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                let isCmd = NSEvent.modifierFlags.contains(.command)
                onSelect(isCmd)
            }
        )
        .contextMenu {
            clipContextMenu
        }
        .gesture(isLocked ? nil : moveGesture)
        .position(x: clipX + clipWidth / 2, y: (height / 2) + dragY)
        .zIndex(isDragging ? 100 : 1)
        .opacity(isDragging ? 0.88 : 1.0)
        .shadow(
            color: isDragging ? Color.black.opacity(0.5) : (isSelected ? Color.black.opacity(0.4) : Color.clear),
            radius: isDragging ? 8 : (isSelected ? 4 : 0),
            x: 0,
            y: isDragging ? 4 : 1
        )
    }

    private var isDragging: Bool {
        dragOffset != 0 || dragY != 0 || (isSelected && (groupDragOffset != 0 || groupTrimLeftOffset != 0 || groupTrimRightOffset != 0))
    }
    private var effectiveTrimLeft: CGFloat { isSelected && groupTrimLeftOffset != 0 ? groupTrimLeftOffset : trimLeftOffset }
    private var effectiveTrimRight: CGFloat { isSelected && groupTrimRightOffset != 0 ? groupTrimRightOffset : trimRightOffset }
    private var baseX: CGFloat { CGFloat(CMTimeGetSeconds(clip.timeRange.start)) * pixelsPerSecond }
    private var baseWidth: CGFloat { CGFloat(CMTimeGetSeconds(clip.timeRange.duration)) * pixelsPerSecond }

    private func clipContent(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            centerBody(width: width)

            if let beatConfig = AudioBeatConfiguration.from(clip: clip), beatConfig.isVisible, !beatConfig.markers.isEmpty {
                ClipBeatMarkersOverlayView(
                    markers: beatConfig.markers,
                    activeSourceStartTime: activeSourceStartTime,
                    pixelsPerSecond: pixelsPerSecond,
                    speed: clip.properties["speed"]?.asNumber ?? 1.0
                )
            }

            if let kfMap = ClipKeyframeMap.from(clip: clip), !kfMap.isEmpty {
                ClipKeyframeOverlayView(
                    keyframeMap: kfMap,
                    clipStart: clip.timeRange.start,
                    pixelsPerSecond: pixelsPerSecond,
                    onSeek: onSeek
                )
            }

            if !isLocked && clip.kind.presentation.hasAudioFadeHandles {
                ClipFadeHandleOverlayView(
                    clip: clip,
                    width: width,
                    height: height - 4,
                    pixelsPerSecond: pixelsPerSecond,
                    isLocked: isLocked,
                    onFadeChanged: { updateFade(fadeIn: $0, fadeOut: $1, isCommitted: false) },
                    onFadeEnded: { updateFade(fadeIn: $0, fadeOut: $1, isCommitted: true) }
                )
            }

            if !isLocked && isSelected {
                ClipTrimHandleView(
                    isLeft: true,
                    height: height - 4,
                    isHovering: $isHoveringLeftTrim,
                    onSelect: { onSelect(false) },
                    onTrimChanged: handleLeftTrimChanged,
                    onTrimEnded: handleLeftTrimEnded
                )
                .frame(maxHeight: .infinity, alignment: .leading)

                ClipTrimHandleView(
                    isLeft: false,
                    height: height - 4,
                    isHovering: $isHoveringRightTrim,
                    onSelect: { onSelect(false) },
                    onTrimChanged: handleRightTrimChanged,
                    onTrimEnded: handleRightTrimEnded
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .frame(width: width, height: height - 4)
    }

    var activeSourceStartTime: CMTime {
        let deltaSec = Double(effectiveTrimLeft / pixelsPerSecond)
        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let newSrc = max(0.0, CMTimeGetSeconds(clip.sourceStartTime) + (deltaSec * speed))
        return CMTime(seconds: newSrc, preferredTimescale: 600)
    }

    @ViewBuilder
    private func centerBody(width: CGFloat) -> some View {
        let activeDurSec = max(1.0 / Double(TimeRational.defaultFPS), Double(width / pixelsPerSecond))
        let activeDur = CMTime(seconds: activeDurSec, preferredTimescale: 600)
        if clip.kind.isAuxiliary {
            auxiliaryClipBody(width: width, duration: activeDur)
        } else {
            VStack(spacing: 0) {
                ClipHeaderBarView(
                    name: clip.name,
                    duration: activeDur,
                    kind: clip.kind
                )
                clipMediaBody(width: width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private func auxiliaryClipBody(width: CGFloat, duration: CMTime) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: clip.kind.iconName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white)

            Text(clip.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .truncationMode(.middle)

            if width >= 80 {
                Text(TimeRational.formatTimecode(time: duration))
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.xs + 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [clipColor, clipColor.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            clipAnimationDurationLine(width: width, duration: duration)
        }
    }

    var isAudioMuted: Bool {
        isMuted || (clip.properties["volume"]?.asNumber ?? 1.0) <= 0.001
    }

    private func updateFade(fadeIn: Double, fadeOut: Double, isCommitted: Bool) {
        var updated = clip.properties
        updated["fadeIn"] = .number(fadeIn)
        updated["fadeOut"] = .number(fadeOut)
        onUpdateProperties?(clip.id, updated, isCommitted)
    }

    private var clipColor: Color {
        clip.kind.color
    }
}

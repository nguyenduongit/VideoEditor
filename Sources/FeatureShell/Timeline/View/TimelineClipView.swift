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
    let thumbnailService: (any TimelineThumbnailServiceProtocol)?
    let waveformService: (any AudioWaveformServiceProtocol)?
    let onSelect: (Bool) -> Void
    let onTrim: (CMTime, CMTime, CMTime?) -> Void
    let onMove: (CMTime, CGFloat) -> Void
    let onMoveEnd: () -> Void
    let groupDragOffset: CGFloat
    let onUpdateProperties: ((UUID, [String: PropertyValue], Bool) -> Void)?

    @State var dragOffset: CGFloat = 0
    @State var dragY: CGFloat = 0
    @State var trimLeftOffset: CGFloat = 0
    @State var trimRightOffset: CGFloat = 0
    @State var isHoveringLeftTrim: Bool = false
    @State var isHoveringRightTrim: Bool = false

    public init(
        clip: TimelineClip, height: CGFloat, pixelsPerSecond: CGFloat, isLocked: Bool,
        isMuted: Bool = false, isSelected: Bool = false, groupDragOffset: CGFloat = 0,
        previousClipEnd: CMTime? = nil, nextClipStart: CMTime? = nil, snapCandidates: [CMTime] = [],
        thumbnailService: (any TimelineThumbnailServiceProtocol)? = nil,
        waveformService: (any AudioWaveformServiceProtocol)? = nil,
        onSelect: @escaping (Bool) -> Void = { _ in },
        onTrim: @escaping (CMTime, CMTime, CMTime?) -> Void,
        onMove: @escaping (CMTime, CGFloat) -> Void,
        onMoveEnd: @escaping () -> Void,
        onUpdateProperties: ((UUID, [String: PropertyValue], Bool) -> Void)? = nil
    ) {
        self.clip = clip; self.height = height; self.pixelsPerSecond = pixelsPerSecond
        self.isLocked = isLocked; self.isMuted = isMuted; self.isSelected = isSelected
        self.groupDragOffset = groupDragOffset
        self.previousClipEnd = previousClipEnd; self.nextClipStart = nextClipStart
        self.snapCandidates = snapCandidates; self.thumbnailService = thumbnailService
        self.waveformService = waveformService; self.onSelect = onSelect
        self.onTrim = onTrim; self.onMove = onMove; self.onMoveEnd = onMoveEnd
        self.onUpdateProperties = onUpdateProperties
    }

    public var body: some View {
        let clipWidth = max(28, baseWidth + trimRightOffset - trimLeftOffset)
        let effectiveDragOffset = isSelected && groupDragOffset != 0 ? groupDragOffset : dragOffset
        let clipX = max(0, baseX + effectiveDragOffset + trimLeftOffset)

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DSRadius.small)
                .fill(clipColor.opacity(0.85))

            clipContent(width: clipWidth)

            ClipBorderOverlayView(
                isSelected: isSelected,
                isHoveringLeftTrim: isHoveringLeftTrim,
                isHoveringRightTrim: isHoveringRightTrim
            )
        }
        .frame(width: clipWidth, height: height - 6)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                let isCmd = NSEvent.modifierFlags.contains(.command)
                onSelect(isCmd)
            }
        )
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

    private var isDragging: Bool { dragOffset != 0 || dragY != 0 || (isSelected && groupDragOffset != 0) }
    private var baseX: CGFloat { CGFloat(CMTimeGetSeconds(clip.timeRange.start)) * pixelsPerSecond }
    private var baseWidth: CGFloat { CGFloat(CMTimeGetSeconds(clip.timeRange.duration)) * pixelsPerSecond }

    private func clipContent(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            centerBody(width: width)

            if !isLocked && (clip.kind == .video || clip.kind == .audio) {
                ClipFadeHandleOverlayView(
                    clip: clip,
                    width: width,
                    height: height - 6,
                    pixelsPerSecond: pixelsPerSecond,
                    isLocked: isLocked,
                    onFadeChanged: { updateFade(fadeIn: $0, fadeOut: $1, isCommitted: false) },
                    onFadeEnded: { updateFade(fadeIn: $0, fadeOut: $1, isCommitted: true) }
                )
            }

            if !isLocked {
                ClipTrimHandleView(
                    isLeft: true,
                    height: height - 6,
                    isHovering: $isHoveringLeftTrim,
                    onSelect: { onSelect(false) },
                    onTrimChanged: handleLeftTrimChanged,
                    onTrimEnded: handleLeftTrimEnded
                )
                .frame(maxHeight: .infinity, alignment: .leading)

                ClipTrimHandleView(
                    isLeft: false,
                    height: height - 6,
                    isHovering: $isHoveringRightTrim,
                    onSelect: { onSelect(false) },
                    onTrimChanged: handleRightTrimChanged,
                    onTrimEnded: handleRightTrimEnded
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .frame(width: width, height: height - 6)
    }

    private var activeSourceStartTime: CMTime {
        let deltaSec = Double(trimLeftOffset / pixelsPerSecond)
        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let newSrc = max(0.0, CMTimeGetSeconds(clip.sourceStartTime) + (deltaSec * speed))
        return CMTime(seconds: newSrc, preferredTimescale: 600)
    }

    private func centerBody(width: CGFloat) -> some View {
        let activeDurSec = max(1.0 / Double(TimeRational.defaultFPS), Double(width / pixelsPerSecond))
        let activeDur = CMTime(seconds: activeDurSec, preferredTimescale: 600)
        return VStack(spacing: 0) {
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

    private var isAudioMuted: Bool {
        isMuted || (clip.properties["volume"]?.asNumber ?? 1.0) <= 0.001
    }

    @ViewBuilder
    private func clipMediaBody(width: CGFloat) -> some View {
        let bodyH = max(10, height - 22)
        let activeSrc = activeSourceStartTime
        switch clip.kind {
        case .video:
            VideoThumbnailFilmstripView(
                clip: clip,
                activeSourceStartTime: activeSrc,
                thumbnailService: thumbnailService,
                waveformService: waveformService,
                pixelsPerSecond: pixelsPerSecond,
                width: width,
                height: bodyH,
                isMuted: isMuted
            )
        case .audio:
            let inSec = clip.properties["fadeIn"]?.asNumber ?? 0.0
            let outSec = clip.properties["fadeOut"]?.asNumber ?? 0.0
            let speed = clip.properties["speed"]?.asNumber ?? 1.0
            AudioWaveformView(
                url: clip.mediaURL,
                service: waveformService,
                sourceStartTime: activeSrc,
                sourceDuration: clip.maxDuration,
                pixelsPerSecond: pixelsPerSecond,
                fadeIn: inSec,
                fadeOut: outSec,
                clipDuration: clip.timeRange.duration,
                speed: speed
            )
            .opacity(isAudioMuted ? 0.35 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isAudioMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.waveformAudioBackground)
        case .image, .text, .adjustment:
            Spacer(minLength: 0)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { handleMoveChanged(value: $0) }
            .onEnded { handleMoveEnded(value: $0) }
    }

    private func handleMoveChanged(value: DragGesture.Value) {
        guard !isHoveringLeftTrim && !isHoveringRightTrim else { return }
        guard !isLocked else { return }

        if !isSelected { onSelect(false) }
        let rawDx = value.translation.width
        dragY = value.translation.height
        let deltaSeconds = Double(rawDx / pixelsPerSecond)
        let currentStartSec = CMTimeGetSeconds(clip.timeRange.start)
        var rawStartSec = max(0, currentStartSec + deltaSeconds)

        if abs(dragY) < 15 && groupDragOffset == 0 {
            if let prevEnd = previousClipEnd { rawStartSec = max(rawStartSec, CMTimeGetSeconds(prevEnd)) }
            if let nextStart = nextClipStart {
                let maxStartSec = max(0, CMTimeGetSeconds(nextStart) - CMTimeGetSeconds(clip.timeRange.duration))
                rawStartSec = min(rawStartSec, maxStartSec)
            }
        }

        let rawStart = CMTime(seconds: rawStartSec, preferredTimescale: 600)
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pixelsPerSecond)
        let (snappedStart, didSnap) = TimelineSnapEngine.snapClipMove(
            proposedStart: rawStart, duration: clip.timeRange.duration,
            candidates: snapCandidates, threshold: threshold
        )
        var effectiveStart = didSnap ? snappedStart : TimeRational.snapToFrame(time: rawStart)

        if abs(dragY) < 15 && groupDragOffset == 0 {
            if let prevEnd = previousClipEnd, effectiveStart < prevEnd { effectiveStart = prevEnd }
            if let nextStart = nextClipStart {
                let maxStart = CMTimeSubtract(nextStart, clip.timeRange.duration)
                if maxStart >= .zero && effectiveStart > maxStart { effectiveStart = maxStart }
            }
        }

        let effectiveDx = CGFloat(CMTimeGetSeconds(effectiveStart) - currentStartSec) * pixelsPerSecond
        dragOffset = effectiveDx
        onMove(effectiveStart, dragY)
    }

    private func handleMoveEnded(value: DragGesture.Value) {
        guard !isHoveringLeftTrim && !isHoveringRightTrim else { return }
        guard !isLocked else { return }
        dragOffset = 0
        dragY = 0
        if !isSelected { onSelect(false) }
        onMoveEnd()
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

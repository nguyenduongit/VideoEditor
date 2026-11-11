import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelineTrackContentView: View {
    private let layer: TimelineLayer
    private let height: CGFloat
    private let canvasWidth: CGFloat
    private let pixelsPerSecond: CGFloat
    private let isHovered: Bool
    private let isDropTargetTop: Bool
    private let isDropTargetBottom: Bool
    private let selectedClipIDs: Set<UUID>
    private let groupDragOffset: CGFloat
    private let groupTrimLeftOffset: CGFloat
    private let groupTrimRightOffset: CGFloat
    private let thumbnailService: (any TimelineThumbnailServiceProtocol)?
    private let waveformService: (any AudioWaveformServiceProtocol)?
    private let snapCandidatesProvider: ((UUID?) -> [CMTime])?
    private let beatTimes: [CMTime]
    private let onSelectClip: (UUID?, Bool) -> Void
    private let onSeek: ((CMTime) -> Void)?
    private let onTrimClip: (UUID, CMTime, CMTime, CMTime?) -> Void
    private let onTrimGroupChanged: ((UUID, Bool, CGFloat) -> Void)?
    private let onTrimGroupEnded: ((UUID, Bool) -> Void)?
    private let onMoveClip: (UUID, ClipKind, CMTime, CGFloat) -> Void
    private let onMoveEnd: (UUID) -> Void
    private let onExtractAudio: ((UUID) -> Void)?
    private let onSavePreset: ((TimelineClip) -> Void)?
    private let onUpdateClipProperties: ((UUID, [String: PropertyValue], Bool) -> Void)?
    private let onSelectTransition: ((UUID) -> Void)?
    private let selectedTransitionID: UUID?
    private let activeTransitionDropTarget: TransitionDropJoinTarget?

    public init(
        layer: TimelineLayer,
        height: CGFloat,
        canvasWidth: CGFloat,
        pixelsPerSecond: CGFloat,
        isHovered: Bool,
        isDropTargetTop: Bool = false,
        isDropTargetBottom: Bool = false,
        selectedClipIDs: Set<UUID> = [],
        selectedClipID: UUID? = nil,
        selectedTransitionID: UUID? = nil,
        activeTransitionDropTarget: TransitionDropJoinTarget? = nil,
        groupDragOffset: CGFloat = 0,
        groupTrimLeftOffset: CGFloat = 0,
        groupTrimRightOffset: CGFloat = 0,
        snapCandidatesProvider: ((UUID?) -> [CMTime])? = nil,
        beatTimes: [CMTime] = [],
        thumbnailService: (any TimelineThumbnailServiceProtocol)? = nil,
        waveformService: (any AudioWaveformServiceProtocol)? = nil,
        onSelectClip: @escaping (UUID?, Bool) -> Void = { _, _ in },
        onSeek: ((CMTime) -> Void)? = nil,
        onTrimClip: @escaping (UUID, CMTime, CMTime, CMTime?) -> Void,
        onTrimGroupChanged: ((UUID, Bool, CGFloat) -> Void)? = nil,
        onTrimGroupEnded: ((UUID, Bool) -> Void)? = nil,
        onMoveClip: @escaping (UUID, ClipKind, CMTime, CGFloat) -> Void,
        onMoveClipEnd: @escaping (UUID) -> Void,
        onExtractAudio: ((UUID) -> Void)? = nil,
        onSavePreset: ((TimelineClip) -> Void)? = nil,
        onUpdateClipProperties: ((UUID, [String: PropertyValue], Bool) -> Void)? = nil,
        onSelectTransition: ((UUID) -> Void)? = nil
    ) {
        self.layer = layer
        self.height = height
        self.canvasWidth = canvasWidth
        self.pixelsPerSecond = pixelsPerSecond
        self.isHovered = isHovered
        self.isDropTargetTop = isDropTargetTop
        self.isDropTargetBottom = isDropTargetBottom
        self.groupDragOffset = groupDragOffset
        self.groupTrimLeftOffset = groupTrimLeftOffset
        self.groupTrimRightOffset = groupTrimRightOffset
        self.snapCandidatesProvider = snapCandidatesProvider
        self.beatTimes = beatTimes
        self.onExtractAudio = onExtractAudio
        self.onSavePreset = onSavePreset
        self.selectedTransitionID = selectedTransitionID
        self.activeTransitionDropTarget = activeTransitionDropTarget
        if !selectedClipIDs.isEmpty {
            self.selectedClipIDs = selectedClipIDs
        } else if let selectedClipID {
            self.selectedClipIDs = [selectedClipID]
        } else {
            self.selectedClipIDs = []
        }
        self.thumbnailService = thumbnailService
        self.waveformService = waveformService
        self.onSelectClip = onSelectClip
        self.onSeek = onSeek
        self.onTrimClip = onTrimClip
        self.onTrimGroupChanged = onTrimGroupChanged
        self.onTrimGroupEnded = onTrimGroupEnded
        self.onMoveClip = onMoveClip
        self.onMoveEnd = onMoveClipEnd
        self.onUpdateClipProperties = onUpdateClipProperties
        self.onSelectTransition = onSelectTransition
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            trackBackground
            clipsCanvas
        }
        .opacity(layer.isHidden ? 0.35 : 1.0)
        .allowsHitTesting(!layer.isHidden)
        .frame(width: canvasWidth, height: height)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
        .overlay(
            Group {
                if isDropTargetTop {
                    Rectangle()
                        .fill(DSColors.dropIndicator)
                        .frame(height: 2)
                }
            },
            alignment: .top
        )
        .overlay(
            Group {
                if isDropTargetBottom {
                    Rectangle()
                        .fill(DSColors.dropIndicator)
                        .frame(height: 2)
                }
            },
            alignment: .bottom
        )
    }

    private var trackBackground: some View {
        Rectangle()
            .fill(isHovered ? DSColors.accent.opacity(0.12) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isHovered ? DSColors.dropIndicator : Color.clear, lineWidth: 1.5)
            )
    }

    private var clipsCanvas: some View {
        ZStack(alignment: .leading) {
            ForEach(layer.clips) { clip in
                let (prev, next) = layer.neighbors(of: clip.id)
                TimelineClipView(
                    clip: clip,
                    height: height,
                    pixelsPerSecond: pixelsPerSecond,
                    isLocked: layer.isLocked,
                    isMuted: layer.isMuted,
                    isSelected: selectedClipIDs.contains(clip.id),
                    groupDragOffset: groupDragOffset,
                    groupTrimLeftOffset: groupTrimLeftOffset,
                    groupTrimRightOffset: groupTrimRightOffset,
                    isMultiSelected: selectedClipIDs.count > 1,
                    previousClipEnd: prev?.timeRange.end,
                    nextClipStart: next?.timeRange.start,
                    snapCandidates: snapCandidatesProvider?(clip.id) ?? [],
                    beatTimes: beatTimes,
                    thumbnailService: thumbnailService,
                    waveformService: waveformService,
                    onSelect: { isCmd in
                        onSelectClip(clip.id, isCmd)
                    },
                    onSeek: onSeek,
                    onTrim: { newStart, newDuration, newSourceStart in
                        onTrimClip(clip.id, newStart, newDuration, newSourceStart)
                    },
                    onTrimChange: { isLeft, dx in
                        onTrimGroupChanged?(clip.id, isLeft, dx)
                    },
                    onTrimEnd: { isLeft in
                        onTrimGroupEnded?(clip.id, isLeft)
                    },
                    onExtractAudio: {
                        onExtractAudio?(clip.id)
                    },
                    onSavePreset: onSavePreset,
                    onMove: { newStart, dragY in
                        onMoveClip(clip.id, clip.kind, newStart, dragY)
                    },
                    onMoveEnd: {
                        onMoveEnd(clip.id)
                    },
                    onUpdateProperties: onUpdateClipProperties
                )
            }

            ForEach(layer.transitions) { transition in
                if let lead = layer.clips.first(where: { $0.id == transition.leadingClipID }) {
                    let cutX = lead.timeRange.end.seconds * pixelsPerSecond
                    let durSec = transition.duration.seconds
                    let overlayW = durSec * pixelsPerSecond
                    let isSelected = selectedTransitionID == transition.id

                    TimelineTransitionOverlayView(
                        transition: transition,
                        width: overlayW,
                        height: height,
                        isSelected: isSelected,
                        onSelect: {
                            onSelectTransition?(transition.id)
                        }
                    )
                    .position(x: cutX, y: height / 2)
                    .zIndex(45)
                }
            }

            if let activeTarget = activeTransitionDropTarget, activeTarget.layerID == layer.id {
                let previewTrans = CutTransition(
                    presetID: "preview",
                    name: "Preview",
                    leadingClipID: activeTarget.leadingClipID,
                    trailingClipID: activeTarget.trailingClipID,
                    duration: RationalTime(cmTime: CMTime(seconds: Double(activeTarget.overlayWidth / pixelsPerSecond), preferredTimescale: 600))
                )
                TimelineTransitionOverlayView(
                    transition: previewTrans,
                    width: activeTarget.overlayWidth,
                    height: height,
                    isSelected: true,
                    onSelect: {}
                )
                .position(x: activeTarget.cutCanvasX, y: height / 2)
                .zIndex(46)
                .shadow(color: DSColors.toggleCyan.opacity(0.85), radius: 6, x: 0, y: 0)
            }
        }
        .frame(width: canvasWidth, height: height, alignment: .leading)
    }
}

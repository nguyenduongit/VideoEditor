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
    private let thumbnailService: (any TimelineThumbnailServiceProtocol)?
    private let waveformService: (any AudioWaveformServiceProtocol)?
    private let snapCandidatesProvider: ((UUID?) -> [CMTime])?
    private let onSelectClip: (UUID?, Bool) -> Void
    private let onSeek: ((CMTime) -> Void)?
    private let onTrimClip: (UUID, CMTime, CMTime, CMTime?) -> Void
    private let onMoveClip: (UUID, ClipKind, CMTime, CGFloat) -> Void
    private let onMoveEnd: (UUID) -> Void
    private let onUpdateClipProperties: ((UUID, [String: PropertyValue], Bool) -> Void)?

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
        groupDragOffset: CGFloat = 0,
        snapCandidatesProvider: ((UUID?) -> [CMTime])? = nil,
        thumbnailService: (any TimelineThumbnailServiceProtocol)? = nil,
        waveformService: (any AudioWaveformServiceProtocol)? = nil,
        onSelectClip: @escaping (UUID?, Bool) -> Void = { _, _ in },
        onSeek: ((CMTime) -> Void)? = nil,
        onTrimClip: @escaping (UUID, CMTime, CMTime, CMTime?) -> Void,
        onMoveClip: @escaping (UUID, ClipKind, CMTime, CGFloat) -> Void,
        onMoveClipEnd: @escaping (UUID) -> Void,
        onUpdateClipProperties: ((UUID, [String: PropertyValue], Bool) -> Void)? = nil
    ) {
        self.layer = layer
        self.height = height
        self.canvasWidth = canvasWidth
        self.pixelsPerSecond = pixelsPerSecond
        self.isHovered = isHovered
        self.isDropTargetTop = isDropTargetTop
        self.isDropTargetBottom = isDropTargetBottom
        self.groupDragOffset = groupDragOffset
        self.snapCandidatesProvider = snapCandidatesProvider
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
        self.onMoveClip = onMoveClip
        self.onMoveEnd = onMoveClipEnd
        self.onUpdateClipProperties = onUpdateClipProperties
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
            .fill(isHovered ? DSColors.accent.opacity(0.12) : DSColors.layerTrackBackground)
            .overlay(
                Rectangle()
                    .stroke(isHovered ? DSColors.dropIndicator : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    onSelectClip(nil, false)
                    let seconds = max(0, Double(value.location.x / pixelsPerSecond))
                    let rawTime = CMTime(seconds: seconds, preferredTimescale: 600)
                    let candidates = snapCandidatesProvider?(nil) ?? []
                    let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pixelsPerSecond)
                    let (snapped, didSnap) = TimelineSnapEngine.snapPoint(time: rawTime, candidates: candidates, threshold: threshold)
                    let finalTime = didSnap ? snapped : TimeRational.snapToFrame(time: rawTime)
                    onSeek?(finalTime)
                }
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
                    previousClipEnd: prev?.timeRange.end,
                    nextClipStart: next?.timeRange.start,
                    snapCandidates: snapCandidatesProvider?(clip.id) ?? [],
                    thumbnailService: thumbnailService,
                    waveformService: waveformService,
                    onSelect: { isCmd in
                        onSelectClip(clip.id, isCmd)
                    },
                    onTrim: { newStart, newDuration, newSourceStart in
                        onTrimClip(clip.id, newStart, newDuration, newSourceStart)
                    },
                    onMove: { newStart, dragY in
                        onMoveClip(clip.id, clip.kind, newStart, dragY)
                    },
                    onMoveEnd: {
                        onMoveEnd(clip.id)
                    },
                    onUpdateProperties: onUpdateClipProperties
                )
            }
        }
        .frame(width: canvasWidth, height: height, alignment: .leading)
    }
}

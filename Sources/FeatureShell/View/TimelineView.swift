import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelineView: View {
    var viewModel: TimelineViewModel
    let playheadState: TimelinePlayheadState
    let onTimelineActivated: (() -> Void)?
    @State var movingClipID: UUID?
    @State var movingSourceLayerID: UUID?
    @State var pendingStartTime: CMTime = .zero
    @State var scrollOffset: CGFloat = 0
    @State var verticalScrollOffset: CGFloat = 0
    @State var enclosingScrollView: NSScrollView?
    @State var dragGuideCanvasX: CGFloat?
    @State var marqueeRect: CGRect?
    @FocusState var isTimelineFocused: Bool

    public init(
        viewModel: TimelineViewModel = TimelineViewModel(),
        playheadState: TimelinePlayheadState? = nil,
        onTimelineActivated: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.playheadState = playheadState ?? TimelinePlayheadState(initialTime: viewModel.currentTime, pixelsPerSecond: viewModel.pixelsPerSecond)
        self.onTimelineActivated = onTimelineActivated
    }

    public var body: some View {
        DSBlockContainer {
            VStack(spacing: DSSpacing.none) {
                TimelineTopbarView(
                    currentTime: playheadState.currentTime,
                    pixelsPerSecond: Binding(get: { viewModel.pixelsPerSecond }, set: { viewModel.setZoomPixelsPerSecond($0) }),
                    minPixelsPerSecond: viewModel.minPixelsPerSecond, maxPixelsPerSecond: viewModel.maxPixelsPerSecond,
                    zoomPercentageText: viewModel.zoomPercentageText, canSplit: viewModel.canSplit,
                    canSyncAudio: viewModel.canSyncAudio, isSyncingAudio: viewModel.isSyncingAudio,
                    onZoomIn: { viewModel.zoomIn() }, onZoomOut: { viewModel.zoomOut() },
                    onResetZoom: { viewModel.resetZoom() }, onSplit: { viewModel.splitClips(at: playheadState.currentTime) },
                    onSyncAudio: { viewModel.syncSelectedAudio() }
                )
                timelineBody
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: viewModel.pixelsPerSecond) { _, newPPS in playheadState.pixelsPerSecond = newPPS }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isTimelineFocused)
        .onKeyPress { press in
            if press.key == .delete || press.key == KeyEquivalent("\u{7f}") { viewModel.deleteSelectedClips(); return .handled }
            if press.key == KeyEquivalent("s") || (press.key == KeyEquivalent("b") && press.modifiers.contains(.command)) {
                viewModel.splitClips(at: playheadState.currentTime); return .handled
            }
            if press.key == KeyEquivalent("z") && press.modifiers == .command { _ = viewModel.undo(); return .handled }
            if press.key == KeyEquivalent("z") && press.modifiers == [.command, .shift] { _ = viewModel.redo(); return .handled }
            return .ignored
        }
    }

    private var timelineBody: some View {
        GeometryReader { geometry in
            let totalLayersHeight = viewModel.totalLayersHeight
            let availableHeight = max(1.0, geometry.size.height - DSSize.rulerHeight - DSSize.timelineBottomBuffer)
            let topSpacerHeight = max(DSSize.timelineTopBuffer, availableHeight - totalLayersHeight)
            let totalContentHeight = topSpacerHeight + totalLayersHeight
            let isVScrollable = totalContentHeight > availableHeight
            let vBarWidth = isVScrollable ? DSSize.timelineBottomBuffer : 0
            let viewportWidth = max(1.0, geometry.size.width - DSSize.layerHeaderWidth - vBarWidth)
            let canvasWidth = max(viewportWidth, viewModel.contentWidth)
            let pps = viewModel.pixelsPerSecond

            ZStack(alignment: .topLeading) {
                VStack(spacing: DSSpacing.none) {
                    TimelineRulerRowView(
                        canvasWidth: canvasWidth, viewportWidth: viewportWidth,
                        pixelsPerSecond: pps, scrollOffset: scrollOffset,
                        isVScrollable: isVScrollable, playheadState: playheadState,
                        snapCandidatesProvider: { viewModel.snapCandidateTimes(includePlayhead: false) }
                    )
                    timelineTracksRow(canvasWidth: canvasWidth, availableHeight: availableHeight, topSpacerHeight: topSpacerHeight, totalContentHeight: totalContentHeight, isVScrollable: isVScrollable, pps: pps)
                    timelineBottomScrollBarRow(canvasWidth: canvasWidth, viewportWidth: viewportWidth, isVScrollable: isVScrollable)
                }

                if let guideCanvasX = dragGuideCanvasX {
                    let screenX = DSSize.layerHeaderWidth + (guideCanvasX - scrollOffset)
                    if screenX >= DSSize.layerHeaderWidth && screenX <= DSSize.layerHeaderWidth + viewportWidth {
                        TimelineDragGuideLineView(screenX: screenX, height: DSSize.rulerHeight + availableHeight)
                    }
                }
            }
            .onAppear { viewModel.updateViewportWidth(viewportWidth) }
            .onChange(of: viewportWidth) { _, newWidth in viewModel.updateViewportWidth(newWidth) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(TapGesture().onEnded { isTimelineFocused = true; onTimelineActivated?() })
        .overlay(scrollWheelOverlay)
    }

    private var scrollWheelOverlay: some View {
        TimelineScrollWheelBridge(
            onCmdScrollWheel: { handleCmdZoom(delta: $0, cursorX: $1) },
            onResetZoom: { viewModel.resetZoom() },
            onZoomIn: { viewModel.zoomIn() }, onZoomOut: { viewModel.zoomOut() },
            onTogglePlayPause: { playheadState.togglePlayPause() },
            onUndo: { _ = viewModel.undo() }, onRedo: { _ = viewModel.redo() }
        )
    }


    private func timelineTracksRow(canvasWidth: CGFloat, availableHeight: CGFloat, topSpacerHeight: CGFloat, totalContentHeight: CGFloat, isVScrollable: Bool, pps: CGFloat) -> some View {
        HStack(spacing: DSSpacing.none) {
            TimelineTrackHeaderListView(
                layers: viewModel.layers, availableHeight: availableHeight, topSpacerHeight: topSpacerHeight,
                isVerticalScrollable: isVScrollable, verticalScrollOffset: verticalScrollOffset,
                dropBetweenIndex: viewModel.dropBetweenIndex, layerHeight: { viewModel.layerHeight(for: $0) },
                onToggleLock: { viewModel.toggleLock(for: $0) }, onToggleHide: { viewModel.toggleHide(for: $0) },
                onToggleMute: { viewModel.toggleMute(for: $0) }
            )
            tracks2DScrollView(canvasWidth: canvasWidth, topSpacerHeight: topSpacerHeight, totalContentHeight: totalContentHeight, pps: pps)
            if isVScrollable {
                TimelineVerticalScrollBarView(scrollOffset: $verticalScrollOffset, contentHeight: totalContentHeight, viewportHeight: availableHeight, onScrollTo: { scrollEnclosing(to: $0, maxDimension: totalContentHeight, isVertical: true) })
            }
        }
        .frame(height: availableHeight)
    }

    private func timelineBottomScrollBarRow(canvasWidth: CGFloat, viewportWidth: CGFloat, isVScrollable: Bool) -> some View {
        HStack(spacing: DSSpacing.none) {
            Color.clear.frame(width: DSSize.layerHeaderWidth, height: DSSize.timelineBottomBuffer).background(DSColors.layerHeaderBackground)
            TimelineScrollBarView(scrollOffset: $scrollOffset, contentWidth: canvasWidth, viewportWidth: viewportWidth, onScrollTo: { scrollEnclosing(to: $0, maxDimension: canvasWidth, isVertical: false) })
            if isVScrollable { Color.clear.frame(width: DSSize.timelineBottomBuffer, height: DSSize.timelineBottomBuffer).background(DSColors.layerTrackBackground) }
        }
        .frame(height: DSSize.timelineBottomBuffer)
    }

    private func tracks2DScrollView(canvasWidth: CGFloat, topSpacerHeight: CGFloat, totalContentHeight: CGFloat, pps: CGFloat) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            tracksContentView(canvasWidth: canvasWidth, topSpacerHeight: topSpacerHeight, totalContentHeight: totalContentHeight, pps: pps)
                .background(TimelineScrollViewAnchor(
                    onScrollViewFound: { if enclosingScrollView == nil { enclosingScrollView = $0 } },
                    onScrollChanged: { scrollOffset = $0; verticalScrollOffset = $1 }
                ))
                .overlay(TimelinePlayheadView(pixelsPerSecond: pps, playheadState: playheadState), alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.layerTrackBackground)
        .overlay(TimelineDropTargetBridge(
            pixelsPerSecond: pps, scrollOffset: scrollOffset,
            onDropAsset: { asset, dropTime in
                isTimelineFocused = true; viewModel.addAsset(asset, at: dropTime)
                onTimelineActivated?()
                playheadState.seek(to: playheadState.currentTime, force: true)
            },
            onDragGuideChanged: { dragGuideCanvasX = $0 },
            snapCandidatesProvider: { viewModel.snapCandidateTimes(playheadTime: playheadState.currentTime) }
        ))
    }

    private func tracksContentView(
        canvasWidth: CGFloat,
        topSpacerHeight: CGFloat,
        totalContentHeight: CGFloat,
        pps: CGFloat
    ) -> some View {
        VStack(spacing: DSSpacing.none) {
            Color.black.opacity(0.001)
                .frame(height: topSpacerHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("tracksContentCanvas"))
                        .onChanged { handleMarqueeDrag(value: $0, topSpacerHeight: topSpacerHeight) }
                        .onEnded { handleMarqueeEnd(value: $0, topSpacerHeight: topSpacerHeight, pps: pps) }
                )
            ForEach(Array(viewModel.layers.enumerated()), id: \.element.id) { index, layer in
                trackRowView(layer: layer, index: index, canvasWidth: canvasWidth, pps: pps)
            }
        }
        .frame(width: canvasWidth, height: totalContentHeight)
        .coordinateSpace(name: "tracksContentCanvas")
        .overlay(alignment: .topLeading) {
            if let rect = marqueeRect {
                TimelineMarqueeSelectionView(rect: rect)
            }
        }
    }

    private func trackRowView(layer: TimelineLayer, index: Int, canvasWidth: CGFloat, pps: CGFloat) -> some View {
        TimelineTrackContentView(
            layer: layer, height: viewModel.layerHeight(for: layer.kind), canvasWidth: canvasWidth, pixelsPerSecond: pps,
            isHovered: viewModel.hoverLayerID == layer.id,
            isDropTargetTop: viewModel.dropBetweenIndex == index,
            isDropTargetBottom: viewModel.dropBetweenIndex == viewModel.layers.count && index == viewModel.layers.count - 1,
            selectedClipIDs: viewModel.selectedClipIDs,
            groupDragOffset: viewModel.groupMoveOffset,
            snapCandidatesProvider: { viewModel.snapCandidateTimes(excludingClipID: $0, playheadTime: playheadState.currentTime) },
            thumbnailService: viewModel.thumbnailService, waveformService: viewModel.waveformService,
            onSelectClip: { isTimelineFocused = true; viewModel.selectClip($0, isCmdPressed: $1) },
            onSeek: { isTimelineFocused = true; playheadState.seek(to: $0, force: true) },
            onTrimClip: { clipID, start, dur, src in
                viewModel.trimClip(clipID: clipID, in: layer.id, newStart: start, newDuration: dur, newSourceStart: src)
                playheadState.seek(to: playheadState.currentTime, force: true)
            },
            onMoveClip: { handleClipMoving(clipID: $0, clipKind: $1, from: layer.id, at: index, newStart: $2, dragY: $3) },
            onMoveClipEnd: { handleClipMoveEnd(clipID: $0) },
            onUpdateClipProperties: { id, props, done in
                done ? viewModel.commitClipProperties(clipID: id, properties: props) : viewModel.updateClipLiveProperties(clipID: id, properties: props)
            }
        )
    }
}


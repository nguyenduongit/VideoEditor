import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Interactive overlay on the Preview canvas enabling direct hit-testing, selection,
/// and live continuous dragging of visual objects with real-time Inspector position updates.
/// Complies with R3.1, R3.4, R7.5, and R8.1 of AGENTS.md.
public struct PreviewObjectManipulatorView: View {
    @Bindable var timelineViewModel: TimelineViewModel
    @Bindable var inspectorViewModel: InspectorViewModel
    private let canvasSize: CGSize

    @State private var isDragging: Bool = false
    @State private var dragInitialPosX: Double = 0.0
    @State private var dragInitialPosY: Double = 0.0
    @State private var draggedClipID: UUID?

    public init(
        timelineViewModel: TimelineViewModel,
        inspectorViewModel: InspectorViewModel,
        canvasSize: CGSize
    ) {
        self.timelineViewModel = timelineViewModel
        self.inspectorViewModel = inspectorViewModel
        self.canvasSize = canvasSize
    }

    public var body: some View {
        GeometryReader { geo in
            let viewSize = geo.size
            ZStack {
                // Interactive canvas background capturing clicks and drags
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(dragGesture(viewSize: viewSize))

                // Bounding box outline around currently selected active clip
                if let selectedClip = activeSelectedClip(viewSize: viewSize) {
                    selectionOutline(for: selectedClip, viewSize: viewSize)
                }
            }
        }
    }

    private func activeSelectedClip(viewSize: CGSize) -> TimelineClip? {
        guard let clip = inspectorViewModel.selectedClip else { return nil }
        let currentTime = timelineViewModel.currentTime
        let start = clip.timeRange.start
        let end = clip.timeRange.end
        let isActive = (clip.timeRange.duration > .zero) &&
            ((currentTime == end) || (currentTime >= start && currentTime < end))
        return isActive ? clip : nil
    }

    private func selectionOutline(for clip: TimelineClip, viewSize: CGSize) -> some View {
        let geom = ClipCanvasGeometry.compute(for: clip, canvasSize: canvasSize)
        let scale = MaskOnScreenMath.scale(canvasSize: canvasSize, viewSize: viewSize)
        let center = MaskOnScreenMath.screenCenter(
            positionX: geom.positionX,
            positionY: geom.positionY,
            canvasSize: canvasSize,
            viewSize: viewSize
        )
        let screenW = max(4.0, geom.size.width * scale)
        let screenH = max(4.0, geom.size.height * scale)

        return ZStack {
            RoundedRectangle(cornerRadius: 1.0)
                .stroke(DSColors.accent, lineWidth: 1.5)
                .frame(width: screenW, height: screenH)

            cornerHandles(width: screenW, height: screenH)
        }
        .rotationEffect(.degrees(-geom.rotationDegrees))
        .position(center)
        .allowsHitTesting(false)
    }

    private func cornerHandles(width: CGFloat, height: CGFloat) -> some View {
        let halfW = width / 2.0
        let halfH = height / 2.0
        let corners: [CGPoint] = [
            CGPoint(x: -halfW, y: -halfH),
            CGPoint(x: halfW, y: -halfH),
            CGPoint(x: -halfW, y: halfH),
            CGPoint(x: halfW, y: halfH)
        ]

        return ForEach(0..<corners.count, id: \.self) { idx in
            Rectangle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .overlay(Rectangle().stroke(DSColors.accent, lineWidth: 1))
                .offset(x: corners[idx].x, y: corners[idx].y)
        }
    }

    private func dragGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                handleDragChanged(g, viewSize: viewSize)
            }
            .onEnded { _ in
                handleDragEnded()
            }
    }

    private func handleDragChanged(_ g: DragGesture.Value, viewSize: CGSize) {
        if !isDragging {
            isDragging = true
            let hitClip = PreviewHitTester.findTopMostClip(
                layers: timelineViewModel.layers,
                currentTime: timelineViewModel.currentTime,
                canvasSize: canvasSize,
                screenPoint: g.startLocation,
                viewSize: viewSize
            )

            if let hitClip {
                timelineViewModel.selectedClipIDs = [hitClip.id]
                inspectorViewModel.syncWithSelection()
                draggedClipID = hitClip.id
                dragInitialPosX = hitClip.properties["positionX"]?.asNumber ?? 0.0
                dragInitialPosY = hitClip.properties["positionY"]?.asNumber ?? 0.0
                inspectorViewModel.onSliderEditingChanged(key: "position", isEditing: true)
            } else {
                timelineViewModel.selectedClipIDs.removeAll()
                inspectorViewModel.syncWithSelection()
                draggedClipID = nil
            }
        }

        guard draggedClipID != nil else { return }
        let scale = MaskOnScreenMath.scale(canvasSize: canvasSize, viewSize: viewSize)
        guard scale > 0.0001 else { return }

        let dx = Double(g.translation.width / scale)
        let dy = Double(-g.translation.height / scale)
        let newX = dragInitialPosX + dx
        let newY = dragInitialPosY + dy

        inspectorViewModel.updateLiveValue(key: "positionX", value: (newX * 10.0).rounded() / 10.0)
        inspectorViewModel.updateLiveValue(key: "positionY", value: (newY * 10.0).rounded() / 10.0)
    }

    private func handleDragEnded() {
        if draggedClipID != nil {
            inspectorViewModel.onSliderEditingChanged(key: "position", isEditing: false)
        }
        isDragging = false
        draggedClipID = nil
    }
}

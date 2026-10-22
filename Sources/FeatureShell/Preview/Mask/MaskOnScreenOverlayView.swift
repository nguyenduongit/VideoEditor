import SwiftUI
import Domain
import DesignSystem

/// On-screen interactive manipulator for timeline clip masks.
/// Complies with R3.1, R7.5, R8.1, and R8.5 of AGENTS.md.
public struct MaskOnScreenOverlayView: View {
    @Bindable var inspectorViewModel: InspectorViewModel
    private let canvasSize: CGSize

    @State private var dragInitialPosX: Double?
    @State private var dragInitialPosY: Double?
    @State private var dragInitialVal: Double?
    @State private var isResizing: Bool = false

    public init(inspectorViewModel: InspectorViewModel, canvasSize: CGSize) {
        self.inspectorViewModel = inspectorViewModel
        self.canvasSize = canvasSize
    }

    public var body: some View {
        GeometryReader { geo in
            let viewSize = geo.size
            let params = TimelineMaskParameters.extract(from: inspectorViewModel.liveProperties)

            if inspectorViewModel.selectedClip != nil,
               inspectorViewModel.effectiveTab == "Mask",
               params.isMaskActive {
                let scale = MaskOnScreenMath.scale(canvasSize: canvasSize, viewSize: viewSize)
                let center = params.shape == .filmstrip
                    ? CGPoint(x: viewSize.width / 2.0, y: viewSize.height / 2.0 - CGFloat(params.offsetY) * scale)
                    : MaskOnScreenMath.screenCenter(
                        positionX: params.positionX,
                        positionY: params.positionY,
                        canvasSize: canvasSize,
                        viewSize: viewSize
                    )

                ZStack {
                    shapeContent(params: params, center: center, scale: scale, viewSize: viewSize)
                    if params.shape != .filmstrip {
                        centerPivotHandle(center: center, scale: scale)
                    }
                }
            }
        }
    }


    private func centerPivotHandle(center: CGPoint, scale: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(DSColors.toggleCyan, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.4), radius: 2)
            .position(center)
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if dragInitialPosX == nil {
                            dragInitialPosX = inspectorViewModel.liveNumber(for: "maskPositionX", default: 0)
                            dragInitialPosY = inspectorViewModel.liveNumber(for: "maskPositionY", default: 0)
                            inspectorViewModel.onSliderEditingChanged(key: "maskPosition", isEditing: true)
                        }
                        let dx = Double(g.translation.width / scale)
                        let dy = Double(-g.translation.height / scale)
                        let newX = (dragInitialPosX ?? 0.0) + dx
                        let newY = (dragInitialPosY ?? 0.0) + dy
                        inspectorViewModel.updateLiveValue(key: "maskPositionX", value: newX)
                        inspectorViewModel.updateLiveValue(key: "maskPositionY", value: newY)
                    }
                    .onEnded { _ in
                        dragInitialPosX = nil
                        dragInitialPosY = nil
                        inspectorViewModel.onSliderEditingChanged(key: "maskPosition", isEditing: false)
                    }
            )
    }

    func rotationHandle(center: CGPoint, distance: CGFloat, rotation: Double) -> some View {
        let handlePos = MaskOnScreenMath.rotatePoint(CGPoint(x: center.x, y: center.y - distance), around: center, angleDegrees: rotation)
        return ZStack {
            Path { p in
                p.move(to: center)
                p.addLine(to: handlePos)
            }
            .stroke(DSColors.toggleCyan.opacity(0.6), lineWidth: 1)

            Circle()
                .fill(DSColors.toggleCyan)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .position(handlePos)
                .gesture(
                    DragGesture()
                        .onChanged { g in
                            if dragInitialVal == nil {
                                dragInitialVal = inspectorViewModel.liveNumber(for: "maskRotation", default: 0)
                                inspectorViewModel.onSliderEditingChanged(key: "maskRotation", isEditing: true)
                            }
                            let deg = MaskOnScreenMath.rotationAngleDegrees(from: center, to: g.location)
                            inspectorViewModel.updateLiveValue(key: "maskRotation", value: deg)
                        }
                        .onEnded { _ in
                            dragInitialVal = nil
                            inspectorViewModel.onSliderEditingChanged(key: "maskRotation", isEditing: false)
                        }
                )
        }
    }

    func resizeHandle(
        at point: CGPoint,
        onStart: @escaping () -> Void,
        onChanged: @escaping (CGPoint) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white)
            .frame(width: 9, height: 9)
            .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(DSColors.toggleCyan, lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.3), radius: 1)
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if !isResizing {
                            isResizing = true
                            onStart()
                        }
                        onChanged(g.location)
                    }
                    .onEnded { _ in
                        isResizing = false
                        onEnded()
                    }
            )
    }
}

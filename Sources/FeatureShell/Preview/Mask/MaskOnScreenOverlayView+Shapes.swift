import SwiftUI
import Domain
import DesignSystem

extension MaskOnScreenOverlayView {
    @ViewBuilder
    func shapeContent(
        params: TimelineMaskParameters,
        center: CGPoint,
        scale: CGFloat,
        viewSize: CGSize
    ) -> some View {
        switch params.shape {
        case .circle:
            circleOverlay(params: params, center: center, scale: scale)
        case .rectangle:
            rectangleOverlay(params: params, center: center, scale: scale)
        case .split:
            splitOverlay(params: params, center: center, scale: scale, viewSize: viewSize)
        case .filmstrip:
            filmstripOverlay(params: params, center: center, scale: scale, viewSize: viewSize)
        case .none:
            EmptyView()
        }
    }

    func circleOverlay(params: TimelineMaskParameters, center: CGPoint, scale: CGFloat) -> some View {
        let rx = CGFloat(params.radiusX) * scale
        let ry = CGFloat(params.radiusY) * scale
        let rot = Angle.degrees(params.rotation)

        return ZStack {
            Ellipse()
                .stroke(DSColors.toggleCyan, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: rx * 2.0, height: ry * 2.0)
                .rotationEffect(rot)
                .position(center)

            if params.feather > 0.0 {
                let fOffset = CGFloat(params.feather * 150.0) * scale
                Ellipse()
                    .stroke(DSColors.toggleCyan.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .frame(width: (rx + fOffset) * 2.0, height: (ry + fOffset) * 2.0)
                    .rotationEffect(rot)
                    .position(center)
            }

            rotationHandle(center: center, distance: ry + 24, rotation: params.rotation)
            let pX = MaskOnScreenMath.rotatePoint(CGPoint(x: center.x + rx, y: center.y), around: center, angleDegrees: params.rotation)
            resizeHandle(
                at: pX,
                onStart: { inspectorViewModel.onSliderEditingChanged(key: "maskRadiusX", isEditing: true) },
                onChanged: { loc in
                    let pt = MaskOnScreenMath.unrotatePoint(loc, around: center, angleDegrees: params.rotation)
                    inspectorViewModel.updateLiveValue(key: "maskRadiusX", value: max(10.0, abs(pt.x - center.x) / scale))
                },
                onEnded: { inspectorViewModel.onSliderEditingChanged(key: "maskRadiusX", isEditing: false) }
            )

            let pY = MaskOnScreenMath.rotatePoint(CGPoint(x: center.x, y: center.y + ry), around: center, angleDegrees: params.rotation)
            resizeHandle(
                at: pY,
                onStart: { inspectorViewModel.onSliderEditingChanged(key: "maskRadiusY", isEditing: true) },
                onChanged: { loc in
                    let pt = MaskOnScreenMath.unrotatePoint(loc, around: center, angleDegrees: params.rotation)
                    inspectorViewModel.updateLiveValue(key: "maskRadiusY", value: max(10.0, abs(pt.y - center.y) / scale))
                },
                onEnded: { inspectorViewModel.onSliderEditingChanged(key: "maskRadiusY", isEditing: false) }
            )
        }
    }

    func rectangleOverlay(params: TimelineMaskParameters, center: CGPoint, scale: CGFloat) -> some View {
        let w = CGFloat(params.width) * scale
        let h = CGFloat(params.height) * scale
        let cr = CGFloat(params.cornerRadius) * scale
        let rot = Angle.degrees(params.rotation)

        return ZStack {
            RoundedRectangle(cornerRadius: cr)
                .stroke(DSColors.toggleCyan, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: w, height: h)
                .rotationEffect(rot)
                .position(center)

            if params.feather > 0.0 {
                let fOffset = CGFloat(params.feather * 150.0) * scale
                RoundedRectangle(cornerRadius: cr + fOffset)
                    .stroke(DSColors.toggleCyan.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .frame(width: w + fOffset * 2.0, height: h + fOffset * 2.0)
                    .rotationEffect(rot)
                    .position(center)
            }

            rotationHandle(center: center, distance: h / 2.0 + 24, rotation: params.rotation)
            resizeHandle(
                at: MaskOnScreenMath.rotatePoint(CGPoint(x: center.x + w / 2.0, y: center.y + h / 2.0), around: center, angleDegrees: params.rotation),
                onStart: {
                    inspectorViewModel.onSliderEditingChanged(key: "maskWidth", isEditing: true)
                    inspectorViewModel.onSliderEditingChanged(key: "maskHeight", isEditing: true)
                },
                onChanged: { loc in
                    let localPt = MaskOnScreenMath.unrotatePoint(loc, around: center, angleDegrees: params.rotation)
                    let newW = max(20.0, abs(localPt.x - center.x) * 2.0 / scale)
                    let newH = max(20.0, abs(localPt.y - center.y) * 2.0 / scale)
                    inspectorViewModel.updateLiveValue(key: "maskWidth", value: newW)
                    inspectorViewModel.updateLiveValue(key: "maskHeight", value: newH)
                },
                onEnded: {
                    inspectorViewModel.onSliderEditingChanged(key: "maskWidth", isEditing: false)
                    inspectorViewModel.onSliderEditingChanged(key: "maskHeight", isEditing: false)
                }
            )
        }
    }

    func splitOverlay(params: TimelineMaskParameters, center: CGPoint, scale: CGFloat, viewSize: CGSize) -> some View {
        let length = max(viewSize.width, viewSize.height) * 2.0
        let rot = Angle.degrees(params.rotation)

        return ZStack {
            Rectangle()
                .fill(DSColors.toggleCyan)
                .frame(width: 1.5, height: length)
                .rotationEffect(rot)
                .position(center)

            if params.feather > 0.0 {
                let fw = CGFloat(params.feather * 800.0) * scale
                Rectangle()
                    .stroke(DSColors.toggleCyan.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: fw, height: length)
                    .rotationEffect(rot)
                    .position(center)
            }

            rotationHandle(center: center, distance: 80, rotation: params.rotation)
        }
    }

    func filmstripOverlay(params: TimelineMaskParameters, center: CGPoint, scale: CGFloat, viewSize: CGSize) -> some View {
        let filmH = CGFloat(params.filmHeight) * scale
        let topY = center.y - filmH / 2.0
        let botY = center.y + filmH / 2.0

        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: topY))
                p.addLine(to: CGPoint(x: viewSize.width, y: topY))
                p.move(to: CGPoint(x: 0, y: botY))
                p.addLine(to: CGPoint(x: viewSize.width, y: botY))
            }
            .stroke(DSColors.toggleCyan, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

            resizeHandle(
                at: CGPoint(x: viewSize.width / 2.0, y: topY),
                onStart: { inspectorViewModel.onSliderEditingChanged(key: "maskFilmHeight", isEditing: true) },
                onChanged: { loc in
                    let newH = max(50.0, abs(loc.y - center.y) * 2.0 / scale)
                    inspectorViewModel.updateLiveValue(key: "maskFilmHeight", value: newH)
                },
                onEnded: { inspectorViewModel.onSliderEditingChanged(key: "maskFilmHeight", isEditing: false) }
            )
        }
    }
}

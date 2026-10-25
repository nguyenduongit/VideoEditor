import SwiftUI
import Domain
import DesignSystem

/// Linh kiện vẽ và tương tác đường cong màu (RGB / Luma Curves) 2D.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) và R8.1 của AGENTS.md.
public struct ColorCurvesControlView: View {
    @Binding private var curves: ColorCurvesAdjustments
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var selectedChannelIndex: Int = 0 // 0: Master, 1: Red, 2: Green, 3: Blue
    @State private var draggedPointIndex: Int?

    private let canvasWidth: CGFloat = 260.0
    private let canvasHeight: CGFloat = 180.0

    private struct ChannelMeta {
        let name: String
        let color: Color
    }

    private let channels: [ChannelMeta] = [
        ChannelMeta(name: "RGB", color: .white),
        ChannelMeta(name: "Red", color: Color(red: 1.0, green: 0.3, blue: 0.3)),
        ChannelMeta(name: "Green", color: Color(red: 0.3, green: 0.9, blue: 0.4)),
        ChannelMeta(name: "Blue", color: Color(red: 0.3, green: 0.6, blue: 1.0))
    ]

    public init(
        curves: Binding<ColorCurvesAdjustments>,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._curves = curves
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        VStack(spacing: DSSpacing.sm) {
            channelPickerRow
            curveCanvasArea
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var channelPickerRow: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(0..<channels.count, id: \.self) { idx in
                let ch = channels[idx]
                let isSelected = selectedChannelIndex == idx

                Button(action: { selectedChannelIndex = idx }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ch.color)
                            .frame(width: 8, height: 8)
                        Text(ch.name)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: resetCurrentChannel) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Đặt lại đường cong hiện tại")
        }
    }

    private var curveCanvasArea: some View {
        let activePoints = currentPoints
        let activeColor = channels[selectedChannelIndex].color

        return ZStack {
            gridBackground

            // Vẽ đường cong đồ thị
            buildCurvePath(activePoints: activePoints)
                .stroke(activeColor, lineWidth: 2)

            // Vẽ các điểm neo
            ForEach(0..<activePoints.count, id: \.self) { idx in
                let pt = activePoints[idx]
                let coord = toCanvasCoord(pt)

                Circle()
                    .fill(activeColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5))
                    .position(coord)
                    .onTapGesture(count: 2) {
                        removePoint(at: idx)
                    }
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    handleDrag(gesture.location)
                }
                .onEnded { _ in
                    draggedPointIndex = nil
                    onEditingChanged?(false)
                }
        )
    }

    private var gridBackground: some View {
        GeometryReader { _ in
            Path { path in
                for i in 1..<4 {
                    let x = (canvasWidth / 4.0) * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasHeight))

                    let y = (canvasHeight / 4.0) * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasWidth, y: y))
                }
                // Đường chéo 45 độ tham chiếu mặc định
                path.move(to: CGPoint(x: 0, y: canvasHeight))
                path.addLine(to: CGPoint(x: canvasWidth, y: 0))
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - Quản lý Điểm Tọa độ

    private var currentPoints: [CurvePoint] {
        switch selectedChannelIndex {
        case 0: return curves.master
        case 1: return curves.red
        case 2: return curves.green
        case 3: return curves.blue
        default: return curves.master
        }
    }

    private func setPoints(_ newPoints: [CurvePoint]) {
        switch selectedChannelIndex {
        case 0: curves.master = newPoints
        case 1: curves.red = newPoints
        case 2: curves.green = newPoints
        case 3: curves.blue = newPoints
        default: curves.master = newPoints
        }
    }

    private func toCanvasCoord(_ pt: CurvePoint) -> CGPoint {
        CGPoint(x: CGFloat(pt.x) * canvasWidth, y: (1.0 - CGFloat(pt.y)) * canvasHeight)
    }

    private func buildCurvePath(activePoints: [CurvePoint]) -> Path {
        var path = Path()
        guard !activePoints.isEmpty else { return path }
        let sorted = activePoints.sorted { $0.x < $1.x }
        let coords = sorted.map { toCanvasCoord($0) }
        path.move(to: coords[0])

        if coords.count == 2 {
            path.addLine(to: coords[1])
            return path
        }

        for i in 0..<(coords.count - 1) {
            let p0 = i > 0 ? coords[i - 1] : coords[i]
            let p1 = coords[i]
            let p2 = coords[i + 1]
            let p3 = (i + 2 < coords.count) ? coords[i + 2] : p2

            let d1x = (p2.x - p0.x) / 6.0
            let d1y = (p2.y - p0.y) / 6.0
            let d2x = (p3.x - p1.x) / 6.0
            let d2y = (p3.y - p1.y) / 6.0

            let c1 = CGPoint(x: p1.x + d1x, y: p1.y + d1y)
            let c2 = CGPoint(x: p2.x - d2x, y: p2.y - d2y)

            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    private func handleDrag(_ location: CGPoint) {
        onEditingChanged?(true)
        let normX = Float(max(0.0, min(1.0, location.x / canvasWidth)))
        let normY = Float(max(0.0, min(1.0, 1.0 - (location.y / canvasHeight))))

        var pts = currentPoints
        if let idx = draggedPointIndex, idx < pts.count {
            if idx == 0 {
                pts[0] = CurvePoint(x: 0.0, y: normY)
            } else if idx == pts.count - 1 {
                pts[pts.count - 1] = CurvePoint(x: 1.0, y: normY)
            } else {
                let minX = pts[idx - 1].x + 0.01
                let maxX = pts[idx + 1].x - 0.01
                let clampedX = min(maxX, max(minX, normX))
                pts[idx] = CurvePoint(x: clampedX, y: normY)
            }
            setPoints(pts)
            return
        }

        // Tìm điểm neo gần nhất
        var closestIdx: Int?
        var minDist: CGFloat = 20.0
        for i in 0..<pts.count {
            let c = toCanvasCoord(pts[i])
            let dist = hypot(c.x - location.x, c.y - location.y)
            if dist < minDist {
                minDist = dist
                closestIdx = i
            }
        }

        if let found = closestIdx {
            draggedPointIndex = found
            pts[found].y = normY
            setPoints(pts)
        } else if pts.count < 8 {
            // Thêm điểm neo mới nếu chưa chạm điểm nào
            let newPt = CurvePoint(x: normX, y: normY)
            pts.append(newPt)
            pts.sort { $0.x < $1.x }
            draggedPointIndex = pts.firstIndex(of: newPt)
            setPoints(pts)
        }
    }

    private func removePoint(at index: Int) {
        var pts = currentPoints
        guard index > 0 && index < pts.count - 1 else { return }
        onEditingChanged?(true)
        pts.remove(at: index)
        setPoints(pts)
        onEditingChanged?(false)
    }

    private func resetCurrentChannel() {
        onEditingChanged?(true)
        let linear = [CurvePoint(x: 0.0, y: 0.0), CurvePoint(x: 1.0, y: 1.0)]
        setPoints(linear)
        onEditingChanged?(false)
    }
}

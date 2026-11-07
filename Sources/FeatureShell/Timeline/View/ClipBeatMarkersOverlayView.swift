import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Lớp phủ vẽ các ghim đánh dấu nhịp (Beat Marker Pins) hình ngũ giác màu xanh ngọc ở mép trên của Clip.
public struct ClipBeatMarkersOverlayView: View {
    private let markers: [AudioBeatMarker]
    private let activeSourceStartTime: CMTime
    private let pixelsPerSecond: CGFloat
    private let speed: Double

    public init(
        markers: [AudioBeatMarker],
        activeSourceStartTime: CMTime,
        pixelsPerSecond: CGFloat,
        speed: Double = 1.0
    ) {
        self.markers = markers
        self.activeSourceStartTime = activeSourceStartTime
        self.pixelsPerSecond = max(1.0, pixelsPerSecond)
        self.speed = max(0.01, speed)
    }

    public var body: some View {
        Canvas { context, size in
            guard !markers.isEmpty, size.width > 4 else { return }
            let sourceStartSec = max(0.0, CMTimeGetSeconds(activeSourceStartTime))
            var lastDrawnX: CGFloat = -100.0

            for marker in markers {
                let rawRelSec = (marker.sourceSeconds - sourceStartSec) / speed
                let snappedRelTime = TimeRational.snapToFrame(
                    time: CMTime(seconds: rawRelSec, preferredTimescale: 600)
                )
                let x = CGFloat(CMTimeGetSeconds(snappedRelTime)) * pixelsPerSecond
                guard x >= 3.0 && x <= size.width - 3.0 else { continue }

                // Tránh vẽ chồng chéo quá dày khi thu nhỏ (zoom out) timeline
                let minSpacing: CGFloat = marker.kind == .major ? 4.5 : 6.0
                if x - lastDrawnX < minSpacing {
                    continue
                }
                lastDrawnX = x

                drawBeatPin(
                    context: context,
                    x: x,
                    kind: marker.kind,
                    clipHeight: size.height
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBeatPin(
        context: GraphicsContext,
        x: CGFloat,
        kind: AudioBeatKind,
        clipHeight: CGFloat
    ) {
        let halfW: CGFloat = kind == .major ? 3.4 : 2.7
        let shoulderY: CGFloat = kind == .major ? 5.6 : 4.5
        let tipY: CGFloat = kind == .major ? 9.2 : 7.5
        let topY: CGFloat = 0.5

        var pinPath = Path()
        pinPath.move(to: CGPoint(x: x - halfW, y: topY))
        pinPath.addLine(to: CGPoint(x: x + halfW, y: topY))
        pinPath.addLine(to: CGPoint(x: x + halfW, y: shoulderY))
        pinPath.addLine(to: CGPoint(x: x, y: tipY))
        pinPath.addLine(to: CGPoint(x: x - halfW, y: shoulderY))
        pinPath.closeSubpath()

        let fillColor = kind == .major
            ? Color(red: 0.0, green: 0.85, blue: 0.95)
            : Color(red: 0.25, green: 0.92, blue: 1.0).opacity(0.88)

        context.fill(pinPath, with: .color(fillColor))
        context.stroke(pinPath, with: .color(Color.black.opacity(0.45)), lineWidth: 0.6)
    }
}


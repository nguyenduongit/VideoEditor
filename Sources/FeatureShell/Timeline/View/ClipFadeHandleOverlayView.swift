import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct ClipFadeHandleOverlayView: View {
    private let clip: TimelineClip
    private let width: CGFloat
    private let height: CGFloat
    private let pixelsPerSecond: CGFloat
    private let isLocked: Bool
    private let onFadeChanged: (Double, Double) -> Void
    private let onFadeEnded: (Double, Double) -> Void

    @State private var isDraggingIn: Bool = false
    @State private var isDraggingOut: Bool = false
    @State private var dragFadeIn: Double? = nil
    @State private var dragFadeOut: Double? = nil
    @State private var isHovering: Bool = false

    public init(
        clip: TimelineClip,
        width: CGFloat,
        height: CGFloat,
        pixelsPerSecond: CGFloat,
        isLocked: Bool,
        onFadeChanged: @escaping (Double, Double) -> Void,
        onFadeEnded: @escaping (Double, Double) -> Void
    ) {
        self.clip = clip
        self.width = width
        self.height = height
        self.pixelsPerSecond = pixelsPerSecond
        self.isLocked = isLocked
        self.onFadeChanged = onFadeChanged
        self.onFadeEnded = onFadeEnded
    }

    private var activeFadeIn: Double {
        dragFadeIn ?? (clip.properties["fadeIn"]?.asNumber ?? 0.0)
    }

    private var activeFadeOut: Double {
        dragFadeOut ?? (clip.properties["fadeOut"]?.asNumber ?? 0.0)
    }

    private var clipDurSec: Double {
        max(0.1, CMTimeGetSeconds(clip.timeRange.duration))
    }

    public var body: some View {
        guard clip.kind == .video || clip.kind == .audio, !isLocked else {
            return AnyView(EmptyView())
        }
        let baselineY = (clip.kind == .video) ? (height - 30.0) : 0.0
        let inX = min(width - 8, max(0, CGFloat(activeFadeIn) * pixelsPerSecond))
        let outX = max(8, min(width, width - CGFloat(activeFadeOut) * pixelsPerSecond))

        return AnyView(
            ZStack(alignment: .topLeading) {
                leftHandle(x: inX, y: baselineY)
                rightHandle(x: outX, y: baselineY)
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .onHover { isHovering = $0 }
        )
    }

    private func leftHandle(x: CGFloat, y: CGFloat) -> some View {
        handleCircle(tooltip: isDraggingIn ? String(format: "Fade in: %.1fs", activeFadeIn) : nil)
            .position(x: x, y: y + 5)
            .highPriorityGesture(leftDragGesture)
    }

    private func rightHandle(x: CGFloat, y: CGFloat) -> some View {
        handleCircle(tooltip: isDraggingOut ? String(format: "Fade out: %.1fs", activeFadeOut) : nil)
            .position(x: x, y: y + 5)
            .highPriorityGesture(rightDragGesture)
    }

    private func handleCircle(tooltip: String?) -> some View {
        VStack(spacing: 2) {
            if let tooltip {
                Text(tooltip)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(y: -14)
            }
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }

    private var leftDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                isDraggingIn = true
                let pps = max(1.0, pixelsPerSecond)
                let baseIn = clip.properties["fadeIn"]?.asNumber ?? 0.0
                let deltaSec = Double(value.translation.width / pps)
                let proposedSec = max(0.0, min(10.0, baseIn + deltaSec))
                let maxAllowed = max(0.0, clipDurSec - activeFadeOut)
                let clamped = min(proposedSec, maxAllowed)
                dragFadeIn = clamped
                onFadeChanged(clamped, activeFadeOut)
            }
            .onEnded { _ in
                isDraggingIn = false
                let finalVal = dragFadeIn ?? activeFadeIn
                dragFadeIn = nil
                onFadeEnded(finalVal, activeFadeOut)
            }
    }

    private var rightDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                isDraggingOut = true
                let pps = max(1.0, pixelsPerSecond)
                let baseOut = clip.properties["fadeOut"]?.asNumber ?? 0.0
                let deltaSec = Double(-value.translation.width / pps)
                let proposedSec = max(0.0, min(10.0, baseOut + deltaSec))
                let maxAllowed = max(0.0, clipDurSec - activeFadeIn)
                let clamped = min(proposedSec, maxAllowed)
                dragFadeOut = clamped
                onFadeChanged(activeFadeIn, clamped)
            }
            .onEnded { _ in
                isDraggingOut = false
                let finalVal = dragFadeOut ?? activeFadeOut
                dragFadeOut = nil
                onFadeEnded(activeFadeIn, finalVal)
            }
    }
}

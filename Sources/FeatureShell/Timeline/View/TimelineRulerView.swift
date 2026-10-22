import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelineRulerView: View {
    private let canvasWidth: CGFloat
    private let pixelsPerSecond: CGFloat
    private let playheadState: TimelinePlayheadState
    private let scrollOffset: CGFloat
    private let viewportWidth: CGFloat?
    private let snapCandidatesProvider: (() -> [CMTime])?

    public init(
        canvasWidth: CGFloat,
        pixelsPerSecond: CGFloat = TimelineZoom.defaultPPS,
        playheadState: TimelinePlayheadState,
        scrollOffset: CGFloat = 0,
        viewportWidth: CGFloat? = nil,
        snapCandidatesProvider: (() -> [CMTime])? = nil
    ) {
        self.canvasWidth = canvasWidth
        self.pixelsPerSecond = pixelsPerSecond
        self.playheadState = playheadState
        self.scrollOffset = scrollOffset
        self.viewportWidth = viewportWidth
        self.snapCandidatesProvider = snapCandidatesProvider
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            rulerBackground
            rulerTicksCanvas
            Rectangle()
                .fill(DSColors.blockBorder)
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
            playheadHandle
        }
        .frame(width: canvasWidth, height: DSSize.rulerHeight)
        .contentShape(Rectangle())
        .gesture(rulerDragGesture)
    }

    private var rulerBackground: some View {
        Rectangle()
            .fill(DSColors.layerHeaderBackground)
    }

    private var rulerTicksCanvas: some View {
        Canvas { context, size in
            let pps = pixelsPerSecond
            let fps = playheadState.fps
            let isFrameLevel = TimeRational.isFrameLevelZoom(pixelsPerSecond: pps, fps: fps)

            if isFrameLevel {
                drawFrameLevelTicks(context: context, size: size, pps: pps, fps: fps)
            } else {
                drawSecondLevelTicks(context: context, size: size, pps: pps)
            }
        }
    }

    private func drawFrameLevelTicks(
        context: GraphicsContext,
        size: CGSize,
        pps: CGFloat,
        fps: Int32
    ) {
        let pixelsPerFrame = pps / CGFloat(fps)
        let totalFrames = Int(ceil(size.width / pixelsPerFrame))
        let visibleMinX = max(0, scrollOffset - 50)
        let visibleMaxX = min(size.width, scrollOffset + (viewportWidth ?? size.width) + 50)
        let startFrame = max(0, Int(floor(visibleMinX / pixelsPerFrame)))
        let endFrame = min(totalFrames, Int(ceil(visibleMaxX / pixelsPerFrame)))

        guard startFrame <= endFrame else { return }

        for frame in startFrame...endFrame {
            let x = CGFloat(frame) * pixelsPerFrame
            let isSecond = (frame % Int(fps) == 0)
            let isFiveFrame = (frame % 5 == 0)

            let tickHeight: CGFloat = isSecond ? 12 : (isFiveFrame ? 7 : 4)
            let yStart = size.height - tickHeight

            var path = Path()
            path.move(to: CGPoint(x: x, y: yStart))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
                path,
                with: .color(isSecond ? DSColors.textPrimary.opacity(0.8) : DSColors.textSecondary.opacity(0.4)),
                lineWidth: 1
            )

            if isSecond {
                let sec = frame / Int(fps)
                let text = Text(String(format: "%02d:%02d", sec / 60, sec % 60))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                context.draw(context.resolve(text), at: CGPoint(x: x + 16, y: 7))
            } else if isFiveFrame && pixelsPerFrame >= 12 {
                let frameInSec = frame % Int(fps)
                let text = Text(String(format: "%02df", frameInSec))
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                context.draw(context.resolve(text), at: CGPoint(x: x + 8, y: 7))
            }
        }
    }

    private func drawSecondLevelTicks(
        context: GraphicsContext,
        size: CGSize,
        pps: CGFloat
    ) {
        let config = TimelineRulerConfig.bestInterval(for: pps)
        let stepSec = config.majorSeconds
        let subTicks = config.subTicks
        let majorStepPx = CGFloat(stepSec) * pps
        let minorStepPx = majorStepPx / CGFloat(subTicks)
        let totalSteps = Int(ceil(size.width / majorStepPx))
        let visibleMinX = max(0, scrollOffset - 50)
        let visibleMaxX = min(size.width, scrollOffset + (viewportWidth ?? size.width) + 50)
        let startStep = max(0, Int(floor(visibleMinX / majorStepPx)))
        let endStep = min(totalSteps, Int(ceil(visibleMaxX / majorStepPx)))

        guard startStep <= endStep else { return }

        for step in startStep...endStep {
            let majorX = CGFloat(step) * majorStepPx

            var majorPath = Path()
            majorPath.move(to: CGPoint(x: majorX, y: size.height - 10))
            majorPath.addLine(to: CGPoint(x: majorX, y: size.height))
            context.stroke(majorPath, with: .color(DSColors.textPrimary.opacity(0.7)), lineWidth: 1)

            let totalSec = Double(step) * stepSec
            let label = TimelineRulerConfig.formatRulerTime(seconds: totalSec)
            let text = Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            context.draw(context.resolve(text), at: CGPoint(x: majorX + 4, y: 7), anchor: .leading)

            for sub in 1..<subTicks {
                let minorX = majorX + CGFloat(sub) * minorStepPx
                if minorX <= size.width {
                    let isMid = (subTicks % 2 == 0 && sub == subTicks / 2)
                    let tickHeight: CGFloat = isMid ? 6.5 : 4.0
                    var minorPath = Path()
                    minorPath.move(to: CGPoint(x: minorX, y: size.height - tickHeight))
                    minorPath.addLine(to: CGPoint(x: minorX, y: size.height))
                    let minorOpacity = isMid ? 0.5 : 0.3
                    context.stroke(
                        minorPath,
                        with: .color(DSColors.textSecondary.opacity(minorOpacity)),
                        lineWidth: 1
                    )
                }
            }
        }
    }

    private var playheadHandle: some View {
        let seconds = CMTimeGetSeconds(playheadState.currentTime)
        let safeSeconds = (seconds.isFinite && !seconds.isNaN) ? max(0, seconds) : 0
        let x = CGFloat(safeSeconds) * pixelsPerSecond
        return PlayheadHandleShape()
            .fill(DSColors.accent)
            .frame(width: 12, height: 18)
            .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
            .offset(x: x - 6, y: DSSize.rulerHeight - 18)
    }

    private var rulerDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let targetX = max(0, value.location.x)
                let rawSec = Double(targetX / pixelsPerSecond)
                let rawTime = CMTime(seconds: rawSec, preferredTimescale: 600)
                let candidates = snapCandidatesProvider?() ?? [.zero]
                let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pixelsPerSecond)
                let (snapped, didSnap) = TimelineSnapEngine.snapPoint(
                    time: rawTime,
                    candidates: candidates,
                    threshold: threshold
                )
                let finalTime = didSnap ? snapped : TimeRational.snapToFrame(time: rawTime, fps: playheadState.fps)
                playheadState.seek(to: finalTime)
            }
    }
}

public struct PlayheadHandleShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipHeight = rect.height * 0.4
        let bodyHeight = rect.height - tipHeight

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bodyHeight))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bodyHeight))
        path.closeSubpath()

        return path
    }
}

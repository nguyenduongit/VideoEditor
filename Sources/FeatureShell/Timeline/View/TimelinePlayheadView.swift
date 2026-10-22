import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelinePlayheadView: View {
    private let pixelsPerSecond: CGFloat
    private let playheadState: TimelinePlayheadState

    public init(
        pixelsPerSecond: CGFloat = TimelineZoom.defaultPPS,
        playheadState: TimelinePlayheadState
    ) {
        self.pixelsPerSecond = pixelsPerSecond
        self.playheadState = playheadState
    }

    public init(playheadState: TimelinePlayheadState) {
        self.pixelsPerSecond = TimelineZoom.defaultPPS
        self.playheadState = playheadState
    }

    public var body: some View {
        let seconds = CMTimeGetSeconds(playheadState.currentTime)
        let safeSeconds = (seconds.isFinite && !seconds.isNaN) ? max(0, seconds) : 0
        let x = CGFloat(safeSeconds) * pixelsPerSecond

        Rectangle()
            .fill(DSColors.accent)
            .frame(width: 1.5)
            .frame(maxHeight: .infinity)
            .offset(x: x - 0.75)
            .allowsHitTesting(false)
    }
}

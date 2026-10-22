import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics

/// Video composition instruction holding layer rendering information and mask parameters.
/// Complies with R3.1 and R4.1 of AGENTS.md.
public final class TimelineCustomVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    public struct LayerRenderInfo: Sendable {
        public let trackID: CMPersistentTrackID
        public let transform: CGAffineTransform
        public let opacity: Float
        public let maskParameters: TimelineMaskParameters?

        public init(
            trackID: CMPersistentTrackID,
            transform: CGAffineTransform,
            opacity: Float,
            maskParameters: TimelineMaskParameters?
        ) {
            self.trackID = trackID
            self.transform = transform
            self.opacity = opacity
            self.maskParameters = maskParameters
        }
    }

    public var timeRange: CMTimeRange
    public var enablePostProcessing: Bool
    public var containsTweening: Bool
    public var requiredSourceTrackIDs: [NSValue]?
    public var passthroughTrackID: CMPersistentTrackID

    public let layerInfos: [LayerRenderInfo]
    public let canvasSize: CGSize

    public init(
        timeRange: CMTimeRange,
        layerInfos: [LayerRenderInfo],
        canvasSize: CGSize
    ) {
        self.timeRange = timeRange
        self.enablePostProcessing = false
        self.containsTweening = false
        self.layerInfos = layerInfos
        self.canvasSize = canvasSize
        self.passthroughTrackID = kCMPersistentTrackID_Invalid
        self.requiredSourceTrackIDs = layerInfos.map { NSNumber(value: $0.trackID) }
        super.init()
    }
}

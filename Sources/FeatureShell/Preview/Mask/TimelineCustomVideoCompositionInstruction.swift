import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics

import Domain

/// Video composition instruction holding layer rendering information, grid configuration, and mask parameters.
/// Complies with R3.1 and R4.1 of AGENTS.md.
public final class TimelineCustomVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    public struct LayerRenderInfo: Sendable {
        public let trackID: CMPersistentTrackID
        public let transform: CGAffineTransform
        public let opacity: Float
        public let maskParameters: TimelineMaskParameters?
        public let gridConfig: GridConfiguration?
        public let autoPanConfig: AutoPanConfiguration?
        public let clipTimeRange: CMTimeRange?
        public let naturalSize: CGSize
        public let finalScale: Double
        public let isAdjustment: Bool
        public let adjustmentConfig: AdjustmentConfiguration?
        public let isText: Bool
        public let textConfig: TextConfiguration?

        public init(
            trackID: CMPersistentTrackID,
            transform: CGAffineTransform,
            opacity: Float,
            maskParameters: TimelineMaskParameters?,
            gridConfig: GridConfiguration? = nil,
            autoPanConfig: AutoPanConfiguration? = nil,
            clipTimeRange: CMTimeRange? = nil,
            naturalSize: CGSize = .zero,
            finalScale: Double = 1.0,
            isAdjustment: Bool = false,
            adjustmentConfig: AdjustmentConfiguration? = nil,
            isText: Bool = false,
            textConfig: TextConfiguration? = nil
        ) {
            self.trackID = trackID
            self.transform = transform
            self.opacity = opacity
            self.maskParameters = maskParameters
            self.gridConfig = gridConfig
            self.autoPanConfig = autoPanConfig
            self.clipTimeRange = clipTimeRange
            self.naturalSize = naturalSize
            self.finalScale = finalScale
            self.isAdjustment = isAdjustment
            self.adjustmentConfig = adjustmentConfig
            self.isText = isText
            self.textConfig = textConfig
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
        self.requiredSourceTrackIDs = layerInfos
            .filter { !$0.isAdjustment && !$0.isText && $0.trackID != kCMPersistentTrackID_Invalid }
            .map { NSNumber(value: $0.trackID) }
        super.init()
    }
}

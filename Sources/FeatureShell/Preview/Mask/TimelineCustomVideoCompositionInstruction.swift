import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics

import Domain

/// Video composition instruction holding layer rendering information, grid configuration, and mask parameters.
/// Complies with R3.1 and R4.1 of AGENTS.md.
/// Bắt buộc kế thừa NSObject và conform AVVideoCompositionInstructionProtocol theo Apple AVFoundation; dữ liệu chỉ đọc trong quá trình render (R8.3).
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
        public let rawNaturalSize: CGSize
        public let finalScale: Double
        public let userScaleY: Double
        public let normalizedOffsetY: Double
        public let isAdjustment: Bool
        public let adjustmentConfig: AdjustmentConfiguration?
        public let isEffect: Bool
        public let effectConfig: EffectConfiguration?
        public let isText: Bool
        public let textConfig: TextConfiguration?
        public let isSolidColor: Bool
        public let solidColorHex: String?

        public init(
            trackID: CMPersistentTrackID,
            transform: CGAffineTransform,
            opacity: Float,
            maskParameters: TimelineMaskParameters?,
            gridConfig: GridConfiguration? = nil,
            autoPanConfig: AutoPanConfiguration? = nil,
            clipTimeRange: CMTimeRange? = nil,
            naturalSize: CGSize = .zero,
            rawNaturalSize: CGSize = .zero,
            finalScale: Double = 1.0,
            userScaleY: Double = 1.0,
            normalizedOffsetY: Double = 0.0,
            isAdjustment: Bool = false,
            adjustmentConfig: AdjustmentConfiguration? = nil,
            isEffect: Bool = false,
            effectConfig: EffectConfiguration? = nil,
            isText: Bool = false,
            textConfig: TextConfiguration? = nil,
            isSolidColor: Bool = false,
            solidColorHex: String? = nil
        ) {
            self.trackID = trackID
            self.transform = transform
            self.opacity = opacity
            self.maskParameters = maskParameters
            self.gridConfig = gridConfig
            self.autoPanConfig = autoPanConfig
            self.clipTimeRange = clipTimeRange
            self.naturalSize = naturalSize
            self.rawNaturalSize = rawNaturalSize
            self.finalScale = finalScale
            self.userScaleY = userScaleY
            self.normalizedOffsetY = normalizedOffsetY
            self.isAdjustment = isAdjustment
            self.adjustmentConfig = adjustmentConfig
            self.isEffect = isEffect
            self.effectConfig = effectConfig
            self.isText = isText
            self.textConfig = textConfig
            self.isSolidColor = isSolidColor
            self.solidColorHex = solidColorHex
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
            .filter { !$0.isAdjustment && !$0.isText && !$0.isEffect && $0.trackID != kCMPersistentTrackID_Invalid }
            .map { NSNumber(value: $0.trackID) }
        super.init()
    }
}

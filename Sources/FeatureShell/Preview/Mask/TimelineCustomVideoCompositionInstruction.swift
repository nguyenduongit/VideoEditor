import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import Domain

/// Video composition instruction holding layer rendering information, active dual-texture transitions, grid, and mask parameters.
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
        public let isSticker: Bool
        public let stickerConfig: StickerConfiguration?
        public let isStillImage: Bool
        public let stillImageURL: URL?
        public let isSolidColor: Bool
        public let solidColorHex: String?
        public let isProcedural: Bool
        public let proceduralConfig: ProceduralConfiguration?
        public let clip: TimelineClip?
        public let videoTrackTransform: CGAffineTransform
        public let activeTransition: ActiveTransitionRenderInfo?

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
            isSticker: Bool = false,
            stickerConfig: StickerConfiguration? = nil,
            isStillImage: Bool = false,
            stillImageURL: URL? = nil,
            isSolidColor: Bool = false,
            solidColorHex: String? = nil,
            isProcedural: Bool = false,
            proceduralConfig: ProceduralConfiguration? = nil,
            clip: TimelineClip? = nil,
            videoTrackTransform: CGAffineTransform = .identity,
            activeTransition: ActiveTransitionRenderInfo? = nil
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
            self.isSticker = isSticker
            self.stickerConfig = stickerConfig
            self.isStillImage = isStillImage
            self.stillImageURL = stillImageURL
            self.isSolidColor = isSolidColor
            self.solidColorHex = solidColorHex
            self.isProcedural = isProcedural
            self.proceduralConfig = proceduralConfig
            self.clip = clip
            self.videoTrackTransform = videoTrackTransform
            self.activeTransition = activeTransition
        }
    }

    /// Thông tin chuyển cảnh 2-texture (Outgoing Clip A -> Incoming Clip B) ngay trên một Video Layer.
    public final class ActiveTransitionRenderInfo: Sendable {
        public let transition: CutTransition
        public let windowRange: CMTimeRange
        public let fromLayerInfo: LayerRenderInfo
        public let toLayerInfo: LayerRenderInfo

        public init(
            transition: CutTransition,
            windowRange: CMTimeRange,
            fromLayerInfo: LayerRenderInfo,
            toLayerInfo: LayerRenderInfo
        ) {
            self.transition = transition
            self.windowRange = windowRange
            self.fromLayerInfo = fromLayerInfo
            self.toLayerInfo = toLayerInfo
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
        self.containsTweening = layerInfos.contains {
            $0.activeTransition != nil
                || $0.isEffect
                || $0.isText
                || $0.isSticker
                || $0.isProcedural
                || ($0.autoPanConfig?.isEnabled == true)
                || ($0.clip.flatMap { ClipKeyframeMap.from(clip: $0) }?.isEmpty == false)
        }
        self.layerInfos = layerInfos
        self.canvasSize = canvasSize
        self.passthroughTrackID = kCMPersistentTrackID_Invalid

        var trackIDSet: [CMPersistentTrackID] = []
        for info in layerInfos {
            if let trans = info.activeTransition {
                if trans.fromLayerInfo.trackID != kCMPersistentTrackID_Invalid && !trackIDSet.contains(trans.fromLayerInfo.trackID) {
                    trackIDSet.append(trans.fromLayerInfo.trackID)
                }
                if trans.toLayerInfo.trackID != kCMPersistentTrackID_Invalid && !trackIDSet.contains(trans.toLayerInfo.trackID) {
                    trackIDSet.append(trans.toLayerInfo.trackID)
                }
            } else if !info.isAdjustment && !info.isText && !info.isEffect && !info.isSticker && !info.isStillImage
                        && info.trackID != kCMPersistentTrackID_Invalid && !trackIDSet.contains(info.trackID) {
                trackIDSet.append(info.trackID)
            }
        }
        self.requiredSourceTrackIDs = trackIDSet.map { NSNumber(value: $0) }
        super.init()
    }
}

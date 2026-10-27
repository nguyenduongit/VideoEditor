import Foundation
import CoreMedia
import CoreGraphics
import Domain

/// Parameters for AI-driven Apple Vision subject framing, Auto Pan, and 3-zone Leg/Body Stretch.
public struct AIVisionFramingRequest: Sendable {
    public var enableAutoPan: Bool
    public var autoPanSmoothness: Double
    public var enableLegStretch: Bool
    public var legStretchRatio: Double
    public var targetSubjectHeightRatio: Double?
    public var explicitScale: Double?
    public var centerSubject: Bool

    public init(
        enableAutoPan: Bool = true,
        autoPanSmoothness: Double = 0.6,
        enableLegStretch: Bool = true,
        legStretchRatio: Double = 1.12,
        targetSubjectHeightRatio: Double? = nil,
        explicitScale: Double? = nil,
        centerSubject: Bool = true
    ) {
        self.enableAutoPan = enableAutoPan
        self.autoPanSmoothness = max(0.0, min(1.0, autoPanSmoothness))
        self.enableLegStretch = enableLegStretch
        self.legStretchRatio = max(GridSliceEngine.minLegStretchRatio, min(GridSliceEngine.maxLegStretchRatio, legStretchRatio))
        self.targetSubjectHeightRatio = targetSubjectHeightRatio
        self.explicitScale = explicitScale
        self.centerSubject = centerSubject
    }

    public static func fromJSON(_ argumentsJSON: String) -> AIVisionFramingRequest {
        let data = argumentsJSON.data(using: .utf8) ?? Data("{}".utf8)
        let dict = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        return AIVisionFramingRequest(
            enableAutoPan: (dict["enableAutoPan"] as? Bool) ?? true,
            autoPanSmoothness: (dict["autoPanSmoothness"] as? Double) ?? 0.6,
            enableLegStretch: (dict["enableLegStretch"] as? Bool) ?? true,
            legStretchRatio: (dict["legStretchRatio"] as? Double) ?? 1.12,
            targetSubjectHeightRatio: dict["targetSubjectHeightRatio"] as? Double,
            explicitScale: dict["scale"] as? Double,
            centerSubject: (dict["centerSubject"] as? Bool) ?? true
        )
    }
}

extension TimelineViewModel {
    /// Runs Apple Vision human pose & subject tracking on the primary video clip and automatically configures:
    /// 1. Auto Pan (horizontal subject centering)
    /// 2. 3-Zone Leg Stretch / Body Proportion (`0.9x ... 1.3x` with dynamic forward/backward waist & ankle lines)
    /// 3. Smart Scale & Vertical Centering based on detected subject height vs frame height.
    public func performAIVisionFraming(
        request: AIVisionFramingRequest,
        availableAssets: [MediaAsset]
    ) async -> (isSuccess: Bool, message: String) {
        let preservedSelection = selectedClipIDs
        var allClips = layers.flatMap(\.clips)

        if !allClips.contains(where: { $0.kind == .video }),
           let videoAsset = availableAssets.first(where: { $0.type == .video }) {
            addAsset(videoAsset, at: .zero)
            allClips = layers.flatMap(\.clips)
        }
        selectedClipIDs = preservedSelection

        guard let videoClip = allClips.first(where: { $0.kind == .video }),
              let mediaURL = videoClip.mediaURL else {
            return (false, "Không tìm thấy clip Video trên Timeline hoặc trong Media Library để phân tích nhân vật.")
        }

        let speed = max(0.01, videoClip.properties["speed"]?.asNumber ?? 1.0)
        let sourceDuration = CMTimeMultiplyByFloat64(videoClip.timeRange.duration, multiplier: speed)
        let mediaRange = CMTimeRange(start: videoClip.sourceStartTime, duration: sourceDuration)

        // Reuse existing keyframes if already tracked with valid body lines, otherwise run Vision tracking now
        var keyframes: [AutoPanKeyframe] = []
        if let existingStr = videoClip.properties["autoPanConfig"]?.asString,
           let existingCfg = AutoPanConfiguration.decode(from: existingStr),
           existingCfg.keyframes.contains(where: { $0.waistY != nil && $0.ankleY != nil }) {
            keyframes = existingCfg.keyframes
        } else if let trackingService = subjectTrackingService {
            analyzingClipIDs.insert(videoClip.id)
            clipAnalysisProgress[videoClip.id] = 0.0
            do {
                let raw = try await trackingService.trackSubject(
                    in: mediaURL,
                    timeRange: mediaRange,
                    samplesPerSecond: 1.0,
                    smoothness: request.autoPanSmoothness,
                    onProgress: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.updateTrackingProgress(clipID: videoClip.id, progress: progress)
                        }
                    }
                )
                keyframes = raw.map { kf in
                    AutoPanKeyframe(
                        timeSeconds: speed == 1.0 ? kf.timeSeconds : (kf.timeSeconds / speed),
                        normalizedX: kf.normalizedX,
                        confidence: kf.confidence,
                        waistY: kf.waistY,
                        ankleY: kf.ankleY
                    )
                }
            } catch {
                failSubjectTracking(clipID: videoClip.id)
            }
            analyzingClipIDs.remove(videoClip.id)
            clipAnalysisProgress.removeValue(forKey: videoClip.id)
        }

        if keyframes.isEmpty {
            keyframes = [
                AutoPanKeyframe(timeSeconds: 0.0, normalizedX: 0.5, confidence: 0.5, waistY: 0.48, ankleY: 0.82)
            ]
        }

        guard let latestClip = clip(by: videoClip.id) else {
            return (false, "Clip Video không còn tồn tại trên Timeline.")
        }

        let lines = AutoPanEngine.representativeBodyLines(from: keyframes) ?? (waistY: 0.48, ankleY: 0.82)
        let estimatedLegH = max(0.10, lines.ankleY - lines.waistY)
        // Lower body (waist to ankle) is ~52% of full standing human height
        let estimatedFullBodyRatio = min(0.95, estimatedLegH / 0.52)

        // Compute optimal scale (>= 1.0 so black borders never appear)
        var finalUserScale = latestClip.properties["scale"]?.asNumber ?? 1.0
        if let explicit = request.explicitScale {
            finalUserScale = max(1.0, min(3.0, explicit))
        } else if let targetRatio = request.targetSubjectHeightRatio, targetRatio > 0.05 {
            let neededScale = targetRatio / max(0.12, estimatedFullBodyRatio)
            // Never scale below 1.0 to avoid exposing black canvas borders
            finalUserScale = max(1.0, min(2.5, (neededScale * 100.0).rounded() / 100.0))
        }

        // Compute safe vertical centering offset (positionY) when zoomed in (finalUserScale > 1.0)
        var finalPosY = latestClip.properties["positionY"]?.asNumber ?? 0.0
        let canvasH = Double(aspectRatio.renderSize.height)
        if request.centerSubject {
            let maxVertOffset = max(0.0, (canvasH * (finalUserScale - 1.0)) / 2.0)
            // Person's visual center is roughly around waistY
            var rawShiftY = (0.50 - lines.waistY) * canvasH * finalUserScale
            // Keep at least 16% bottom margin below the character's feet even after leg stretch
            let legDelta = request.enableLegStretch ? (estimatedLegH * finalUserScale * max(0.0, request.legStretchRatio - 1.0) / 2.0) : 0.0
            let projectedAnkleY = 0.50 + (lines.ankleY - 0.50) * finalUserScale + (rawShiftY / max(1.0, canvasH)) + legDelta
            if projectedAnkleY > 0.84 {
                rawShiftY -= (projectedAnkleY - 0.84) * canvasH
            }
            finalPosY = max(-maxVertOffset, min(maxVertOffset, rawShiftY.rounded()))
        }

        var updatedProps = latestClip.properties
        updatedProps["scale"] = .number(finalUserScale)
        updatedProps["positionY"] = .number(finalPosY)
        if request.enableAutoPan {
            updatedProps["positionX"] = .number(0.0)
        }

        // Save AutoPanConfiguration (with full horizontal + vertical Vision keyframes)
        let autoPanCfg = AutoPanConfiguration(
            isEnabled: request.enableAutoPan,
            zoom: 1.0,
            smoothness: request.autoPanSmoothness,
            keyframes: keyframes
        )
        if let encodedAutoPan = autoPanCfg.encodeToString() {
            updatedProps["autoPanConfig"] = .string(encodedAutoPan)
        }

        // Save 3-Zone Leg Stretch GridConfiguration (0.9x ... 1.3x)
        var gridCfg = latestClip.properties["gridConfig"]?.asString.flatMap {
            GridConfiguration.decode(from: $0)
        } ?? GridConfiguration(
            rows: 3,
            columns: 1,
            isEnabled: request.enableLegStretch,
            legStretchRatio: request.legStretchRatio,
            isDynamicLines: true
        )
        gridCfg.isEnabled = request.enableLegStretch
        gridCfg.isDynamicLines = true
        let normOffsetY = finalPosY / max(1.0, canvasH)
        let mappedWaistY = 0.50 + (lines.waistY - 0.50) * finalUserScale + normOffsetY
        let mappedAnkleY = 0.50 + (lines.ankleY - 0.50) * finalUserScale + normOffsetY
        GridSliceEngine.setBodyLines(config: &gridCfg, waistY: mappedWaistY, ankleY: mappedAnkleY)
        GridSliceEngine.applyLegStretch(config: &gridCfg, ratio: request.legStretchRatio)

        if let encodedGrid = gridCfg.encodeToString() {
            updatedProps["gridConfig"] = .string(encodedGrid)
        }

        commitClipProperties(clipID: latestClip.id, properties: updatedProps)
        selectedClipIDs = preservedSelection

        let bodyPct = Int((estimatedFullBodyRatio * finalUserScale * 100.0).rounded())
        let waistPct = Int((lines.waistY * 100.0).rounded())
        let anklePct = Int((lines.ankleY * 100.0).rounded())
        let summary = String(
            format: "Đã phân tích Vision (%d mẫu): Căn tâm AutoPan=%@, Chiều cao nhân vật ~%d%% khung hình (Scale %.2fx, Line Thắt lưng %d%%, Line Mắt cá %d%%), Hệ số kéo dài chân cân đối %.2fx (bám mượt tiến/lùi).",
            keyframes.count,
            request.enableAutoPan ? "Bật" : "Tắt",
            bodyPct,
            finalUserScale,
            waistPct,
            anklePct,
            gridCfg.legStretchRatio
        )
        return (true, summary)
    }
}

import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func completeSubjectTracking(clipID: UUID, speed: Double, rawKeyframes: [AutoPanKeyframe]) {
        guard analyzingClipIDs.contains(clipID) else { return }
        analyzingClipIDs.remove(clipID)
        clipAnalysisProgress.removeValue(forKey: clipID)
        trackingTasks.removeValue(forKey: clipID)

        let keyframes = rawKeyframes.map { kf in
            AutoPanKeyframe(
                timeSeconds: speed == 1.0 ? kf.timeSeconds : (kf.timeSeconds / speed),
                normalizedX: kf.normalizedX,
                confidence: kf.confidence,
                waistY: kf.waistY,
                ankleY: kf.ankleY
            )
        }

        if let currentClip = clip(by: clipID) {
            var config = currentClip.properties["autoPanConfig"]?.asString.flatMap {
                AutoPanConfiguration.decode(from: $0)
            } ?? .default
            config.isEnabled = true
            config.keyframes = keyframes
            var props = currentClip.properties
            if let encoded = config.encodeToString() {
                props["autoPanConfig"] = .string(encoded)
            }
            if let gridStr = props["gridConfig"]?.asString,
               var gridCfg = GridConfiguration.decode(from: gridStr),
               let lines = AutoPanEngine.representativeBodyLines(from: keyframes) {
                gridCfg.isDynamicLines = true
                GridSliceEngine.setBodyLines(config: &gridCfg, waistY: lines.waistY, ankleY: lines.ankleY)
                if let gridEncoded = gridCfg.encodeToString() {
                    props["gridConfig"] = .string(gridEncoded)
                }
            }
            commitClipProperties(clipID: clipID, properties: props)
        }
    }

    public func failSubjectTracking(clipID: UUID) {
        analyzingClipIDs.remove(clipID)
        clipAnalysisProgress.removeValue(forKey: clipID)
        trackingTasks.removeValue(forKey: clipID)
    }

    public func startSubjectTracking(for clipID: UUID, smoothness: Double) {
        guard let clip = clip(by: clipID), let url = clip.mediaURL else { return }
        guard let trackingService = subjectTrackingService else { return }
        guard !analyzingClipIDs.contains(clipID) else { return }

        analyzingClipIDs.insert(clipID)
        clipAnalysisProgress[clipID] = 0.0

        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let sourceDuration = CMTimeMultiplyByFloat64(clip.timeRange.duration, multiplier: speed)
        let mediaRange = CMTimeRange(start: clip.sourceStartTime, duration: sourceDuration)

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let rawKeyframes = try await trackingService.trackSubject(
                    in: url,
                    timeRange: mediaRange,
                    samplesPerSecond: 1.0,
                    smoothness: smoothness,
                    onProgress: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.updateTrackingProgress(clipID: clipID, progress: progress)
                        }
                    }
                )
                try Task.checkCancellation()
                self.completeSubjectTracking(clipID: clipID, speed: speed, rawKeyframes: rawKeyframes)
            } catch {
                self.failSubjectTracking(clipID: clipID)
            }
        }
        trackingTasks[clipID] = task
    }

    public func cancelSubjectTracking(for clipID: UUID) {
        trackingTasks[clipID]?.cancel()
        trackingTasks.removeValue(forKey: clipID)
        analyzingClipIDs.remove(clipID)
        clipAnalysisProgress.removeValue(forKey: clipID)
    }
}

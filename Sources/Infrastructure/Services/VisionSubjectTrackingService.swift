import Foundation
@preconcurrency import AVFoundation
import Vision
import CoreGraphics
import CoreMedia
import Domain
import os

/// Infrastructure service that uses Apple Vision framework to detect and track human subjects across video frames.
/// Complies with R2.6, R3.1, and R7.5 of AGENTS.md.
public final class VisionSubjectTrackingService: SubjectTrackingServiceProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "VisionSubjectTrackingService")

    public init() {}

    public func trackSubject(
        in mediaURL: URL,
        timeRange: CMTimeRange,
        samplesPerSecond: Double = 2.0,
        smoothness: Double = 0.5,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [AutoPanKeyframe] {
        let asset = AVURLAsset(url: mediaURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            Self.logger.warning("No video track found for asset at \(mediaURL.path)")
            return []
        }

        let durationSeconds = timeRange.duration.seconds
        guard durationSeconds > 0.05 else { return [] }

        let sampleRate = max(0.5, min(10.0, samplesPerSecond))
        let totalSamples = max(1, Int((durationSeconds * sampleRate).rounded()))
        let stepSeconds = durationSeconds / Double(totalSamples)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var rawKeyframes: [AutoPanKeyframe] = []
        var lastValidX: Double = 0.5

        for i in 0..<totalSamples {
            try Task.checkCancellation()
            let timeSec = timeRange.start.seconds + Double(i) * stepSeconds
            let cmTime = CMTime(seconds: timeSec, preferredTimescale: 600)

            let (detectedX, confidence) = await detectSubjectPosition(generator: generator, at: cmTime)
            let chosenX = detectedX ?? lastValidX
            if detectedX != nil { lastValidX = chosenX }

            rawKeyframes.append(AutoPanKeyframe(timeSeconds: timeSec, normalizedX: chosenX, confidence: confidence))
            onProgress?(Double(i + 1) / Double(totalSamples))
        }

        return applySmoothing(keyframes: rawKeyframes, smoothness: smoothness)
    }

    private func detectSubjectPosition(
        generator: AVAssetImageGenerator,
        at time: CMTime
    ) async -> (normalizedX: Double?, confidence: Float) {
        do {
            let (cgImage, _) = try await generator.image(at: time)
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Try human body detection first
            let humanRequest = VNDetectHumanRectanglesRequest()
            humanRequest.upperBodyOnly = false
            try handler.perform([humanRequest])

            if let observations = humanRequest.results, !observations.isEmpty {
                if let best = observations.max(by: { ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height) }) {
                    return (Double(best.boundingBox.midX), best.confidence)
                }
            }

            // Fallback to face detection
            let faceRequest = VNDetectFaceRectanglesRequest()
            try handler.perform([faceRequest])
            if let faces = faceRequest.results, !faces.isEmpty {
                if let bestFace = faces.max(by: { ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height) }) {
                    return (Double(bestFace.boundingBox.midX), bestFace.confidence)
                }
            }
        } catch {
            Self.logger.debug("Subject detection error at time \(time.seconds): \(error.localizedDescription)")
        }
        return (nil, 0.0)
    }

    private func applySmoothing(
        keyframes: [AutoPanKeyframe],
        smoothness: Double
    ) -> [AutoPanKeyframe] {
        guard keyframes.count > 1, smoothness > 0.01 else { return keyframes }
        let alpha = max(0.05, 1.0 - (smoothness * 0.85)) // Lower alpha = heavier smoothing

        var smoothed: [AutoPanKeyframe] = []
        var runningAverage = keyframes[0].normalizedX

        for kf in keyframes {
            runningAverage = (alpha * kf.normalizedX) + ((1.0 - alpha) * runningAverage)
            smoothed.append(AutoPanKeyframe(timeSeconds: kf.timeSeconds, normalizedX: runningAverage, confidence: kf.confidence))
        }

        return smoothed
    }
}

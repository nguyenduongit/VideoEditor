import Foundation
@preconcurrency import AVFoundation
import Vision
import CoreGraphics
import CoreMedia
import Domain
import os

/// Infrastructure service using Apple Vision framework to track human subjects across video frames.
/// Adopts body pose detection, foreground candidate grouping, and Gaussian smoothing from reference.
/// Complies with R2.6, R3.1, and R7.5 of AGENTS.md.
public final class VisionSubjectTrackingService: SubjectTrackingServiceProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "VisionSubjectTrackingService")

    public init() {}

    public func trackSubject(
        in mediaURL: URL,
        timeRange: CMTimeRange,
        samplesPerSecond: Double = 4.0,
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
            let localSec = Double(i) * stepSeconds
            let sampleTime = CMTimeAdd(timeRange.start, CMTime(seconds: localSec, preferredTimescale: 600))

            let (detectedX, confidence) = await detectSubjectPosition(generator: generator, at: sampleTime)
            let chosenX = detectedX ?? lastValidX
            if detectedX != nil { lastValidX = chosenX }

            rawKeyframes.append(AutoPanKeyframe(timeSeconds: localSec, normalizedX: chosenX, confidence: confidence))
            onProgress?(Double(i + 1) / Double(totalSamples))
        }

        let passes = smoothness <= 0.01 ? 0 : max(1, Int((smoothness * 4.0).rounded()))
        return AutoPanEngine.smoothKeyframesGaussian(rawKeyframes, passes: passes)
    }

    private func detectSubjectPosition(
        generator: AVAssetImageGenerator,
        at time: CMTime
    ) async -> (normalizedX: Double?, confidence: Float) {
        do {
            let (cgImage, _) = try await generator.image(at: time)
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // 1. Primary: Human Body Pose Detection (groups multi-dancer performers to avoid alternating jitter)
            let poseRequest = VNDetectHumanBodyPoseRequest()
            try handler.perform([poseRequest])
            if let observations = poseRequest.results, !observations.isEmpty {
                if let groupCenter = extractMainDancerGroupCenter(from: observations) {
                    return (groupCenter, 1.0)
                }
            }

            // 2. Secondary: Human Rectangle Detection
            let humanRequest = VNDetectHumanRectanglesRequest()
            humanRequest.upperBodyOnly = false
            try handler.perform([humanRequest])
            if let observations = humanRequest.results, !observations.isEmpty {
                if let groupCenter = extractRectanglesGroupCenter(from: observations) {
                    return (groupCenter, 0.8)
                }
            }

            // 3. Fallback: Face Rectangles Detection
            let faceRequest = VNDetectFaceRectanglesRequest()
            try handler.perform([faceRequest])
            if let faces = faceRequest.results, !faces.isEmpty {
                if let groupCenter = extractFacesGroupCenter(from: faces) {
                    return (groupCenter, 0.6)
                }
            }
        } catch {
            Self.logger.debug("Subject detection error at time \(time.seconds): \(error.localizedDescription)")
        }
        return (nil, 0.0)
    }

    // MARK: - Multi-Dancer Grouping Algorithms from Reference

    private struct PersonCandidate {
        let minX: CGFloat
        let maxX: CGFloat
        let minY: CGFloat
        let maxY: CGFloat
        var height: Double { Double(maxY - minY) }
        var centerX: Double { Double((minX + maxX) / 2.0) }
    }

    private func extractMainDancerGroupCenter(from observations: [VNHumanBodyPoseObservation]) -> Double? {
        var candidates: [PersonCandidate] = []
        for obs in observations {
            guard let recognizedPoints = try? obs.recognizedPoints(.all) else { continue }
            var pMinX: CGFloat = 1.0, pMaxX: CGFloat = 0.0
            var pMinY: CGFloat = 1.0, pMaxY: CGFloat = 0.0
            var pHasValidPoints = false

            for point in recognizedPoints.values where point.confidence > 0.20 {
                let loc = point.location
                if loc.x < pMinX { pMinX = loc.x }
                if loc.x > pMaxX { pMaxX = loc.x }
                if loc.y < pMinY { pMinY = loc.y }
                if loc.y > pMaxY { pMaxY = loc.y }
                pHasValidPoints = true
            }

            if pHasValidPoints {
                let pHeight = Double(pMaxY - pMinY)
                if pHeight > 0.08 { // Ignore noise smaller than 8% frame height
                    candidates.append(PersonCandidate(minX: pMinX, maxX: pMaxX, minY: pMinY, maxY: pMaxY))
                }
            }
        }

        guard !candidates.isEmpty else { return nil }
        let maxHeightInFrame = candidates.map(\.height).max() ?? 0.0
        let mainDancers = candidates.filter { $0.height >= maxHeightInFrame * 0.60 }
        guard !mainDancers.isEmpty else { return nil }

        let dancerMinX = mainDancers.map(\.minX).min() ?? 0.0
        let dancerMaxX = mainDancers.map(\.maxX).max() ?? 1.0
        return Double((dancerMinX + dancerMaxX) / 2.0)
    }

    private func extractRectanglesGroupCenter(from observations: [VNHumanObservation]) -> Double? {
        let valid = observations.filter { $0.boundingBox.height > 0.08 }
        guard !valid.isEmpty else { return nil }
        let maxHeight = valid.map { Double($0.boundingBox.height) }.max() ?? 0.0
        let mainSubjects = valid.filter { Double($0.boundingBox.height) >= maxHeight * 0.60 }
        guard !mainSubjects.isEmpty else { return nil }

        let minX = mainSubjects.map { $0.boundingBox.minX }.min() ?? 0.0
        let maxX = mainSubjects.map { $0.boundingBox.maxX }.max() ?? 1.0
        return Double((minX + maxX) / 2.0)
    }

    private func extractFacesGroupCenter(from faces: [VNFaceObservation]) -> Double? {
        let valid = faces.filter { $0.boundingBox.height > 0.05 }
        guard !valid.isEmpty else { return nil }
        let maxHeight = valid.map { Double($0.boundingBox.height) }.max() ?? 0.0
        let mainFaces = valid.filter { Double($0.boundingBox.height) >= maxHeight * 0.60 }
        guard !mainFaces.isEmpty else { return nil }

        let minX = mainFaces.map { $0.boundingBox.minX }.min() ?? 0.0
        let maxX = mainFaces.map { $0.boundingBox.maxX }.max() ?? 1.0
        return Double((minX + maxX) / 2.0)
    }
}

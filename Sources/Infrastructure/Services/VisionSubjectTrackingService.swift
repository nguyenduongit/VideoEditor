import Foundation
@preconcurrency import AVFoundation
import Vision
import CoreGraphics
import CoreMedia
import Domain
import os

/// Infrastructure service using Apple Vision framework to track human subjects across video frames.
/// Adopts 512px proxy hardware decoding, stream pipeline, candidate grouping, and Gaussian smoothing.
/// Complies with R2.6, R3.1, and R7.5 of AGENTS.md.
public final class VisionSubjectTrackingService: SubjectTrackingServiceProtocol, Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "VisionSubjectTrackingService")

    public init() {}

    public func trackSubject(
        in mediaURL: URL,
        timeRange: CMTimeRange,
        samplesPerSecond: Double = 1.0,
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
        // High performance 320px hardware thumbnail decoding for fast Apple Neural Engine pose detection
        generator.maximumSize = CGSize(width: 320, height: 320)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var sampleTimes: [CMTime] = []
        sampleTimes.reserveCapacity(totalSamples)
        for i in 0..<totalSamples {
            let localSec = Double(i) * stepSeconds
            let sampleTime = CMTimeAdd(timeRange.start, CMTime(seconds: localSec, preferredTimescale: 600))
            sampleTimes.append(sampleTime)
        }

        var rawKeyframes: [AutoPanKeyframe] = []
        rawKeyframes.reserveCapacity(totalSamples)
        var lastValidX: Double = 0.5
        var lastValidWaistY: Double?
        var lastValidAnkleY: Double?
        var processedCount = 0

        // Continuous streaming via AVAssetImageGenerator.images without individual GOP seeks
        for try await result in generator.images(for: sampleTimes) {
            try Task.checkCancellation()

            let timeSec: Double
            if let actual = try? result.actualTime {
                let diff = CMTimeSubtract(actual, timeRange.start).seconds
                timeSec = max(0.0, min(durationSeconds, diff))
            } else {
                timeSec = Double(processedCount) * stepSeconds
            }

            let detectedX: Double?
            let detectedWaistY: Double?
            let detectedAnkleY: Double?
            let confidence: Float
            if let cgImage = try? result.image {
                let detected = detectSubjectPosition(in: cgImage)
                detectedX = detected.normalizedX
                detectedWaistY = detected.waistY
                detectedAnkleY = detected.ankleY
                confidence = detected.confidence
            } else {
                detectedX = nil
                detectedWaistY = nil
                detectedAnkleY = nil
                confidence = 0.0
            }

            let chosenX = detectedX ?? lastValidX
            if detectedX != nil { lastValidX = chosenX }
            if let w = detectedWaistY { lastValidWaistY = w }
            if let a = detectedAnkleY { lastValidAnkleY = a }

            rawKeyframes.append(
                AutoPanKeyframe(
                    timeSeconds: timeSec,
                    normalizedX: chosenX,
                    confidence: confidence,
                    waistY: detectedWaistY ?? lastValidWaistY,
                    ankleY: detectedAnkleY ?? lastValidAnkleY
                )
            )
            processedCount += 1
            onProgress?(Double(processedCount) / Double(totalSamples))
        }

        if rawKeyframes.isEmpty {
            rawKeyframes.append(AutoPanKeyframe(timeSeconds: 0.0, normalizedX: 0.5, confidence: 0.0))
        }
        rawKeyframes.sort { $0.timeSeconds < $1.timeSeconds }

        let passes = smoothness <= 0.01 ? 0 : max(1, Int((smoothness * 4.0).rounded()))
        return AutoPanEngine.smoothKeyframesGaussian(rawKeyframes, passes: passes)
    }

    private struct SubjectPoseSample {
        let normalizedX: Double?
        let waistY: Double?
        let ankleY: Double?
        let confidence: Float
    }

    private func detectSubjectPosition(in cgImage: CGImage) -> SubjectPoseSample {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // 1. Primary: Human Body Pose Detection (extracts both horizontal group center and vertical waist/ankle lines)
        let poseRequest = VNDetectHumanBodyPoseRequest()
        if (try? handler.perform([poseRequest])) != nil,
           let observations = poseRequest.results, !observations.isEmpty {
            if let pose = extractMainDancerPose(from: observations) {
                return SubjectPoseSample(
                    normalizedX: pose.centerX,
                    waistY: pose.waistY,
                    ankleY: pose.ankleY,
                    confidence: 1.0
                )
            }
        }

        // 2. Secondary: Human Rectangle Detection
        let humanRequest = VNDetectHumanRectanglesRequest()
        humanRequest.upperBodyOnly = false
        if (try? handler.perform([humanRequest])) != nil,
           let observations = humanRequest.results, !observations.isEmpty {
            if let rectMetrics = extractRectanglesMetrics(from: observations) {
                return SubjectPoseSample(
                    normalizedX: rectMetrics.centerX,
                    waistY: rectMetrics.waistY,
                    ankleY: rectMetrics.ankleY,
                    confidence: 0.8
                )
            }
        }

        // 3. Fallback: Face Rectangles Detection
        let faceRequest = VNDetectFaceRectanglesRequest()
        if (try? handler.perform([faceRequest])) != nil,
           let faces = faceRequest.results, !faces.isEmpty {
            if let groupCenter = extractFacesGroupCenter(from: faces) {
                return SubjectPoseSample(normalizedX: groupCenter, waistY: nil, ankleY: nil, confidence: 0.6)
            }
        }

        return SubjectPoseSample(normalizedX: nil, waistY: nil, ankleY: nil, confidence: 0.0)
    }

    // MARK: - Multi-Dancer Grouping & Body Pose Landmarks

    private struct PersonCandidate {
        let minX: CGFloat
        let maxX: CGFloat
        let minY: CGFloat
        let maxY: CGFloat
        let waistTopDownY: Double
        let ankleTopDownY: Double
        var height: Double { Double(maxY - minY) }
        var centerX: Double { Double((minX + maxX) / 2.0) }
    }

    private func extractMainDancerPose(
        from observations: [VNHumanBodyPoseObservation]
    ) -> (centerX: Double, waistY: Double, ankleY: Double)? {
        var candidates: [PersonCandidate] = []
        for obs in observations {
            if let candidate = makeCandidate(from: obs) {
                candidates.append(candidate)
            }
        }
        guard !candidates.isEmpty else { return nil }
        let maxHeightInFrame = candidates.map(\.height).max() ?? 0.0
        let mainDancers = candidates.filter { $0.height >= maxHeightInFrame * 0.60 }
        guard !mainDancers.isEmpty else { return nil }

        let dancerMinX = mainDancers.map(\.minX).min() ?? 0.0
        let dancerMaxX = mainDancers.map(\.maxX).max() ?? 1.0
        let centerX = Double((dancerMinX + dancerMaxX) / 2.0)

        let avgWaistY = mainDancers.map(\.waistTopDownY).reduce(0.0, +) / Double(mainDancers.count)
        let maxAnkleY = mainDancers.map(\.ankleTopDownY).max() ?? 0.80
        let safeWaist = max(0.12, min(0.80, avgWaistY))
        let safeAnkle = max(safeWaist + 0.12, min(0.95, maxAnkleY))
        return (centerX, safeWaist, safeAnkle)
    }

    private func makeCandidate(from obs: VNHumanBodyPoseObservation) -> PersonCandidate? {
        guard let recognizedPoints = try? obs.recognizedPoints(.all) else { return nil }
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
        guard pHasValidPoints, Double(pMaxY - pMinY) > 0.08 else { return nil }

        // Hip/Waist joints in Vision (convert bottom-up Y to top-down 0..1)
        let hipKeys: [VNHumanBodyPoseObservation.JointName] = [.root, .leftHip, .rightHip]
        let hipYs = hipKeys.compactMap { key -> Double? in
            guard let pt = recognizedPoints[key], pt.confidence > 0.20 else { return nil }
            return 1.0 - Double(pt.location.y)
        }
        let fallbackWaist = 1.0 - Double(pMinY + 0.50 * (pMaxY - pMinY))
        let waistTopDownY = hipYs.isEmpty ? fallbackWaist : (hipYs.reduce(0.0, +) / Double(hipYs.count))

        // Ankle joints in Vision (convert bottom-up Y to top-down 0..1)
        let ankleKeys: [VNHumanBodyPoseObservation.JointName] = [.leftAnkle, .rightAnkle]
        let ankleYs = ankleKeys.compactMap { key -> Double? in
            guard let pt = recognizedPoints[key], pt.confidence > 0.20 else { return nil }
            return 1.0 - Double(pt.location.y)
        }
        let fallbackAnkle = 1.0 - Double(pMinY)
        let ankleTopDownY = ankleYs.isEmpty ? fallbackAnkle : (ankleYs.max() ?? fallbackAnkle)

        return PersonCandidate(
            minX: pMinX,
            maxX: pMaxX,
            minY: pMinY,
            maxY: pMaxY,
            waistTopDownY: waistTopDownY,
            ankleTopDownY: ankleTopDownY
        )
    }

    private func extractRectanglesMetrics(
        from observations: [VNHumanObservation]
    ) -> (centerX: Double, waistY: Double, ankleY: Double)? {
        let valid = observations.filter { $0.boundingBox.height > 0.08 }
        guard !valid.isEmpty else { return nil }
        let maxHeight = valid.map { Double($0.boundingBox.height) }.max() ?? 0.0
        let mainSubjects = valid.filter { Double($0.boundingBox.height) >= maxHeight * 0.60 }
        guard !mainSubjects.isEmpty else { return nil }

        let minX = mainSubjects.map { $0.boundingBox.minX }.min() ?? 0.0
        let maxX = mainSubjects.map { $0.boundingBox.maxX }.max() ?? 1.0
        let centerX = Double((minX + maxX) / 2.0)

        let minY = mainSubjects.map { $0.boundingBox.minY }.min() ?? 0.1
        let maxY = mainSubjects.map { $0.boundingBox.maxY }.max() ?? 0.9
        let waistY = 1.0 - Double(minY + 0.48 * (maxY - minY))
        let ankleY = 1.0 - Double(minY + 0.04 * (maxY - minY))
        return (centerX, max(0.12, min(0.80, waistY)), max(0.25, min(0.95, ankleY)))
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

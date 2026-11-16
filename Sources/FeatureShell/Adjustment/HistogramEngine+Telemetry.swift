import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@preconcurrency import AVFoundation
import Domain

extension HistogramEngine {
    /// Trích xuất và tổng hợp quang phổ từ nhiều khung hình (20%, 50%, 80% thời lượng clip) để đại diện toàn cảnh.
    public func extractMultiFrameTelemetry(from assetURL: URL, start: CMTime, duration: CMTime) async -> ColorTelemetryProfile? {
        let durSec = max(0.0, CMTimeGetSeconds(duration))
        let ratios: [Double] = durSec > 0.4 ? [0.2, 0.5, 0.8] : [0.5]
        var profiles: [ColorTelemetryProfile] = []

        for r in ratios {
            let sampleTime = CMTimeAdd(start, CMTime(seconds: durSec * r, preferredTimescale: 600))
            if let image = await extractFrame(from: assetURL, at: sampleTime) {
                profiles.append(analyzeTelemetry(from: image))
            }
        }
        guard !profiles.isEmpty else { return nil }
        let n = Float(profiles.count)
        let avgR = profiles.map(\.meanRed).reduce(0, +) / n
        let avgG = profiles.map(\.meanGreen).reduce(0, +) / n
        let avgB = profiles.map(\.meanBlue).reduce(0, +) / n
        let avgP5 = profiles.map(\.blackPoint).reduce(0, +) / n
        let avgP95 = profiles.map(\.whitePoint).reduce(0, +) / n
        let avgTemp = profiles.map(\.suggestedTempOffset).reduce(0, +) / n
        let avgTint = profiles.map(\.suggestedTintOffset).reduce(0, +) / n
        let (cast, _, _) = detectColorCast(meanR: avgR, meanG: avgG, meanBlue: avgB)

        return ColorTelemetryProfile(
            averageLuma: profiles.map(\.averageLuma).reduce(0, +) / n,
            blackPoint: avgP5,
            whitePoint: avgP95,
            dynamicRange: max(0.0, avgP95 - avgP5),
            shadowClippingRatio: profiles.map(\.shadowClippingRatio).reduce(0, +) / n,
            highlightClippingRatio: profiles.map(\.highlightClippingRatio).reduce(0, +) / n,
            meanRed: avgR, meanGreen: avgG, meanBlue: avgB,
            dominantCast: cast,
            suggestedTempOffset: avgTemp,
            suggestedTintOffset: avgTint,
            averageSaturation: profiles.map(\.averageSaturation).reduce(0, +) / n
        )
    }

    /// Trích xuất nhanh khung hình ngầm (headless) từ tệp media video tại thời điểm time
    public func extractFrame(from assetURL: URL, at time: CMTime) async -> CIImage? {
        let asset = AVURLAsset(url: assetURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        let tolerance = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return CIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

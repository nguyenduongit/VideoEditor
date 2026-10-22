import Foundation
import CoreMedia

public protocol TimelineThumbnailServiceProtocol: Sendable {
    func generateThumbnail(for url: URL, at time: CMTime, targetHeight: CGFloat) async -> Data?
}

public protocol AudioWaveformServiceProtocol: Sendable {
    func generateWaveformSamples(for url: URL, sampleCount: Int) async -> [Float]
    func generateWaveformPeaks(for url: URL, samplesPerSecond: Int) async -> [Float]
    func generateWaveformPeaks(
        for url: URL,
        samplesPerSecond: Int,
        onProgress: (@Sendable ([Float]) -> Void)?
    ) async -> [Float]
}

extension AudioWaveformServiceProtocol {
    public func generateWaveformPeaks(for url: URL, samplesPerSecond: Int) async -> [Float] {
        await generateWaveformPeaks(for: url, samplesPerSecond: samplesPerSecond, onProgress: nil)
    }

    public func generateWaveformPeaks(
        for url: URL,
        samplesPerSecond: Int,
        onProgress: (@Sendable ([Float]) -> Void)?
    ) async -> [Float] {
        let fallback = await generateWaveformSamples(for: url, sampleCount: max(1, samplesPerSecond * 10))
        onProgress?(fallback)
        return fallback
    }
}


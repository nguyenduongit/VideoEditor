import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain

public actor AudioWaveformService: AudioWaveformServiceProtocol {
    private let peaksCache = LRUCache<String, [Float]>(capacity: 64)
    private let samplesCache = LRUCache<String, [Float]>(capacity: 128)

    public init() {}

    public func generateWaveformPeaks(
        for url: URL,
        samplesPerSecond: Int = 100,
        onProgress: (@Sendable ([Float]) -> Void)? = nil
    ) async -> [Float] {
        let key = "\(url.path)_rate_\(samplesPerSecond)"
        if let cached = peaksCache[key] {
            onProgress?(cached)
            return cached
        }
        if Task.isCancelled { return [] }

        let extracted = await extractPCM(
            from: url,
            targetRate: max(10, samplesPerSecond),
            onProgress: onProgress
        )
        if !Task.isCancelled && !extracted.isEmpty {
            peaksCache[key] = extracted
        }
        return extracted
    }

    public func generateWaveformPeaks(for url: URL, samplesPerSecond: Int = 100) async -> [Float] {
        await generateWaveformPeaks(for: url, samplesPerSecond: samplesPerSecond, onProgress: nil)
    }

    public func generateWaveformSamples(for url: URL, sampleCount: Int) async -> [Float] {
        guard sampleCount > 0 else { return [] }
        let key = "\(url.path)_count_\(sampleCount)"
        if let cached = samplesCache[key] { return cached }
        if Task.isCancelled { return Array(repeating: 0.05, count: sampleCount) }

        let basePeaks = await generateWaveformPeaks(for: url, samplesPerSecond: 100)
        guard !basePeaks.isEmpty else {
            return Array(repeating: Float(0.05), count: sampleCount)
        }

        let result = reduce(peaks: basePeaks, targetCount: sampleCount)
        samplesCache[key] = result
        return result
    }

    private func extractPCM(
        from url: URL,
        targetRate: Int,
        onProgress: (@Sendable ([Float]) -> Void)?
    ) async -> [Float] {
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { return [] }

            let reader = try AVAssetReader(asset: asset)
            let sampleRate: Double = 8000.0
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            trackOutput.alwaysCopiesSampleData = false
            reader.add(trackOutput)
            guard reader.startReading() else { return [] }

            let samplesPerBin = max(1, Int(sampleRate) / max(10, targetRate))
            return readSamples(from: trackOutput, reader: reader, samplesPerBin: samplesPerBin, onProgress: onProgress)
        } catch {
            return []
        }
    }

    private func readSamples(
        from output: AVAssetReaderTrackOutput,
        reader: AVAssetReader,
        samplesPerBin: Int,
        onProgress: (@Sendable ([Float]) -> Void)?
    ) -> [Float] {
        var peaks: [Float] = []
        peaks.reserveCapacity(4000)
        var currentBinMax: Int32 = 0
        var samplesInBin = 0
        let invMax: Float = 1.0 / 32768.0
        var buffer = [Int16](repeating: 0, count: 16384)
        var bufferCount = 0

        while reader.status == .reading {
            if Task.isCancelled { reader.cancelReading(); return [] }
            guard let sBuf = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sBuf) else { break }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            let sampleCount = length / MemoryLayout<Int16>.size
            guard sampleCount > 0 else { continue }

            if buffer.count < sampleCount { buffer = [Int16](repeating: 0, count: sampleCount) }
            buffer.withUnsafeMutableBytes { ptr in
                if let base = ptr.baseAddress {
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
                }
            }

            for i in 0..<sampleCount {
                let s = abs(Int32(buffer[i]))
                if s > currentBinMax { currentBinMax = s }
                samplesInBin += 1
                if samplesInBin >= samplesPerBin {
                    peaks.append(Float(currentBinMax) * invMax)
                    currentBinMax = 0
                    samplesInBin = 0
                }
            }

            bufferCount += 1
            if bufferCount >= 40 {
                bufferCount = 0
                if !peaks.isEmpty, let onProgress { onProgress(peaks) }
            }
        }
        if samplesInBin > 0 { peaks.append(Float(currentBinMax) * invMax) }
        return peaks
    }

    private func reduce(peaks: [Float], targetCount: Int) -> [Float] {
        guard !peaks.isEmpty, targetCount > 0 else { return [] }
        var result = [Float](repeating: 0.05, count: targetCount)
        let binSize = Double(peaks.count) / Double(targetCount)

        for i in 0..<targetCount {
            let start = Int(Double(i) * binSize)
            let end = min(peaks.count, Int(Double(i + 1) * binSize))
            if start < end {
                var maxVal: Float = 0.0
                for j in start..<end where peaks[j] > maxVal {
                    maxVal = peaks[j]
                }
                result[i] = max(0.05, min(1.0, maxVal))
            } else if start < peaks.count {
                result[i] = max(0.05, min(1.0, peaks[start]))
            }
        }
        return result
    }
}

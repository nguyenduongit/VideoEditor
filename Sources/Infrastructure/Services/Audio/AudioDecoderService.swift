import Foundation
import AVFoundation
import AudioToolbox
import os

/// Decodes audio tracks from video or audio files into Mono Float32 PCM at 22,050 Hz.
public final class AudioDecoderService: Sendable {
    public static let targetSampleRate: Double = 22050.0

    private let logger = Logger(subsystem: "com.videoeditor", category: "AudioDecoderService")

    public init() {}

    /// Decodes the first audio track to mono Float32 at 22.050 kHz.
    public func decodeToMonoFloat32(url: URL, targetSampleRate: Double = 22050.0) async -> [Float]? {
        await decodeAudioTracksToMonoFloat32(url: url, targetSampleRate: targetSampleRate).first
    }

    /// Decodes all available audio tracks individually to mono Float32.
    public func decodeAudioTracksToMonoFloat32(url: URL, targetSampleRate: Double = 22050.0) async -> [[Float]] {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        let decoded = audioTracks.compactMap {
            decodeUsingAVAssetReader(asset: asset, track: $0, targetSampleRate: targetSampleRate)
        }
        if !decoded.isEmpty {
            return decoded
        }

        if let fallback = decodeUsingExtAudioFile(url: url, targetSampleRate: targetSampleRate) {
            return [fallback]
        }
        return []
    }

    // MARK: - AVAssetReader Decoding

    private func decodeUsingAVAssetReader(asset: AVAsset, track audioTrack: AVAssetTrack, targetSampleRate: Double) -> [Float]? {
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            logger.error("Failed to create AVAssetReader: \(error.localizedDescription)")
            return nil
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(trackOutput) else { return nil }
        reader.add(trackOutput)

        guard reader.startReading() else { return nil }

        var samples: [Float] = []
        samples.reserveCapacity(Int(targetSampleRate * 30))

        while reader.status == .reading {
            guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else { break }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let totalLength = CMBlockBufferGetDataLength(blockBuffer)
            guard totalLength > 0 else { continue }

            let floatCount = totalLength / MemoryLayout<Float>.size
            var floatBuffer = [Float](repeating: 0, count: floatCount)
            let status = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: totalLength, destination: &floatBuffer)
            if status == noErr {
                samples.append(contentsOf: floatBuffer)
            }
        }

        guard reader.status == .completed else { return nil }
        return samples.isEmpty ? nil : samples
    }

    // MARK: - ExtAudioFile Decoding (Fallback)

    private func decodeUsingExtAudioFile(url: URL, targetSampleRate: Double) -> [Float]? {
        var extAudioFile: ExtAudioFileRef?
        let openStatus = ExtAudioFileOpenURL(url as CFURL, &extAudioFile)
        guard openStatus == noErr, let audioFile = extAudioFile else { return nil }
        defer { ExtAudioFileDispose(audioFile) }

        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: targetSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        let setPropStatus = ExtAudioFileSetProperty(
            audioFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientFormat
        )
        guard setPropStatus == noErr else { return nil }

        let bufferFrameSize: UInt32 = 4096
        var samples: [Float] = []
        var floatBuffer = [Float](repeating: 0, count: Int(bufferFrameSize))

        while true {
            var frameCount: UInt32 = bufferFrameSize
            let readStatus = floatBuffer.withUnsafeMutableBufferPointer { ptr -> OSStatus in
                var bufferList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: frameCount * 4,
                        mData: ptr.baseAddress
                    )
                )
                return ExtAudioFileRead(audioFile, &frameCount, &bufferList)
            }

            guard readStatus == noErr else { break }
            if frameCount == 0 { break }
            samples.append(contentsOf: floatBuffer.prefix(Int(frameCount)))
        }

        return samples.isEmpty ? nil : samples
    }
}

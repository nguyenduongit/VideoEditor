import Foundation
import AVFoundation
import AudioToolbox

/// Protocol định nghĩa giao diện giải mã âm thanh
public protocol AudioDecoderServiceProtocol: Sendable {
    func decodeToMonoFloat32(url: URL, targetSampleRate: Double) -> [Float]?
    func decodeAudioTracksToMonoFloat32(url: URL, targetSampleRate: Double) -> [[Float]]
}

public extension AudioDecoderServiceProtocol {
    func decodeToMonoFloat32(url: URL) -> [Float]? {
        decodeToMonoFloat32(url: url, targetSampleRate: AudioDecoderService.targetSampleRate)
    }

    func decodeAudioTracksToMonoFloat32(url: URL) -> [[Float]] {
        decodeAudioTracksToMonoFloat32(url: url, targetSampleRate: AudioDecoderService.targetSampleRate)
    }
}

public final class AudioDecoderService: AudioDecoderServiceProtocol, @unchecked Sendable {
    
    public static let shared = AudioDecoderService()
    public static let targetSampleRate: Double = 22050.0
    
    public init() {}
    
    /// Giải mã âm thanh từ Video hoặc File Nhạc về dạng mảng số thực Float32 Mono 22.050 Hz (Zero FFmpeg)
    public func decodeToMonoFloat32(url: URL, targetSampleRate: Double = 22050.0) -> [Float]? {
        decodeAudioTracksToMonoFloat32(url: url, targetSampleRate: targetSampleRate).first
    }

    /// Giải mã riêng từng audio track. Video iPhone có thể chứa AAC stereo và
    /// Spatial Audio; bộ đồng bộ cần thử cả hai thay vì mặc định lấy track đầu.
    public func decodeAudioTracksToMonoFloat32(url: URL, targetSampleRate: Double = 22050.0) -> [[Float]] {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let decoded = asset.tracks(withMediaType: .audio).compactMap {
            decodeUsingAVAssetReader(asset: asset, track: $0, targetSampleRate: targetSampleRate)
        }
        if !decoded.isEmpty { return decoded }
        
        // Fallback tối ưu cho một số tệp âm thanh thuần.
        if let samples = decodeUsingExtAudioFile(url: url, targetSampleRate: targetSampleRate) {
            return [samples]
        }
        return []
    }
    
    // MARK: - AVAssetReader Decoding
    private func decodeUsingAVAssetReader(asset: AVAsset, track audioTrack: AVAssetTrack, targetSampleRate: Double) -> [Float]? {
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            print("❌ [AudioDecoderService] Không thể tạo AVAssetReader: \(error.localizedDescription)")
            return nil
        }
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1, // Downmix về Mono 1 kênh
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false
        
        guard reader.canAdd(trackOutput) else {
            return nil
        }
        reader.add(trackOutput)
        
        guard reader.startReading() else {
            return nil
        }
        
        var samples: [Float] = []
        samples.reserveCapacity(Int(targetSampleRate * 60)) // Dự trữ sẵn ~60s
        
        while reader.status == .reading {
            guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
                break
            }
            
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }
            
            var lengthAtOffset: Int = 0
            var totalLength: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )
            
            if status == noErr {
                let floatCount = totalLength / MemoryLayout<Float>.size
                // CMBlockBufferCopyDataBytes xử lý buffer không liên tục an toàn;
                // không đưa con trỏ ra ngoài closure như withMemoryRebound.
                var floatBuffer = [Float](repeating: 0, count: floatCount)
                let copyStatus = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: totalLength, destination: &floatBuffer)
                if copyStatus == noErr {
                    samples.append(contentsOf: floatBuffer)
                }
            }
        }

        // Phân biệt EOF thật với lỗi giữa chừng: chỉ trả kết quả khi reader hoàn tất đúng.
        guard reader.status == .completed else {
            return nil
        }
        return samples.isEmpty ? nil : samples
    }
    
    // MARK: - ExtAudioFile Decoding (Fallback)
    private func decodeUsingExtAudioFile(url: URL, targetSampleRate: Double) -> [Float]? {
        var extAudioFile: ExtAudioFileRef?
        let openStatus = ExtAudioFileOpenURL(url as CFURL, &extAudioFile)
        guard openStatus == noErr, let audioFile = extAudioFile else {
            return nil
        }
        defer { ExtAudioFileDispose(audioFile) }
        
        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: targetSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1, // Mono
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
            var readStatus: OSStatus = noErr
            
            floatBuffer.withUnsafeMutableBytes { rawBuffer in
                var bufferList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: bufferFrameSize * UInt32(MemoryLayout<Float>.size),
                        mData: rawBuffer.baseAddress
                    )
                )
                
                readStatus = ExtAudioFileRead(audioFile, &frameCount, &bufferList)
            }
            
            // Nếu có lỗi khác noErr, từ chối toàn bộ (không trả dữ liệu bị cắt dở dang).
            if readStatus != noErr {
                return nil
            }
            // EOF chuẩn xác: frameCount == 0 và status == noErr
            if frameCount == 0 {
                break
            }
            
            samples.append(contentsOf: floatBuffer[0..<Int(frameCount)])
        }
        
        return samples.isEmpty ? nil : samples
    }
}

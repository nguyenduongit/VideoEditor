import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

extension ProjectExportEngine {
    private static let audioLogger = Logger(subsystem: "com.videoeditor", category: "ProjectExportEngine.Audio")

    /// Xuất toàn bộ Timeline ra tệp âm thanh độc lập (M4A hoặc WAV).
    func exportAudio(
        composition: AVComposition,
        audioMix: AVAudioMix?,
        totalDuration: CMTime,
        format: ExportAudioFormat,
        outputURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        switch format {
        case .m4a:
            try await exportM4A(
                composition: composition,
                audioMix: audioMix,
                totalDuration: totalDuration,
                outputURL: outputURL,
                onProgress: onProgress
            )
        case .wav:
            try await exportWAV(
                composition: composition,
                audioMix: audioMix,
                totalDuration: totalDuration,
                outputURL: outputURL,
                onProgress: onProgress
            )
        }
    }

    private func exportM4A(
        composition: AVComposition,
        audioMix: AVAudioMix?,
        totalDuration: CMTime,
        outputURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(
                domain: "ProjectExportEngine",
                code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Không thể khởi tạo phiên xuất âm thanh M4A."]
            )
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioExport_staging_\(UUID().uuidString).m4a")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        session.outputURL = tempURL
        session.outputFileType = .m4a
        session.audioMix = audioMix
        session.timeRange = CMTimeRange(start: .zero, duration: totalDuration)
        session.shouldOptimizeForNetworkUse = false
        self.currentSession = session

        let progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let s = self.currentSession else { break }
                let p = Double(s.progress)
                onProgress(max(0.0, min(0.99, p)))
                if s.status == .completed || s.status == .failed || s.status == .cancelled {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        defer {
            progressTask.cancel()
            self.currentSession = nil
            try? FileManager.default.removeItem(at: tempURL)
        }

        Self.audioLogger.notice("Bắt đầu xuất âm thanh M4A tới: \(outputURL.path, privacy: .public)")
        await withCheckedContinuation { continuation in
            session.exportAsynchronously { continuation.resume() }
        }

        if isCancelled || session.status == .cancelled {
            throw CancellationError()
        }
        if let error = session.error {
            Self.audioLogger.error("Lỗi xuất M4A: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        if session.status == .completed {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: outputURL)
            onProgress(1.0)
            Self.audioLogger.notice("Xuất M4A thành công: \(outputURL.path, privacy: .public)")
        } else {
            throw NSError(
                domain: "ProjectExportEngine",
                code: -11,
                userInfo: [NSLocalizedDescriptionKey: "Xuất M4A không hoàn tất (Status: \(session.status.rawValue))."]
            )
        }
    }

    private func exportWAV(
        composition: AVComposition,
        audioMix: AVAudioMix?,
        totalDuration: CMTime,
        outputURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioExport_staging_\(UUID().uuidString).wav")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let reader = try AVAssetReader(asset: composition)
        let audioTracks = composition.tracks(withMediaType: .audio)
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        readerOutput.audioMix = audioMix
        guard reader.canAdd(readerOutput) else {
            throw NSError(domain: "ProjectExportEngine", code: -20, userInfo: [NSLocalizedDescriptionKey: "Không thể thêm AudioMixOutput vào AVAssetReader."])
        }
        reader.add(readerOutput)

        let writer = try AVAssetWriter(url: tempURL, fileType: .wav)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        writerInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(writerInput) else {
            throw NSError(domain: "ProjectExportEngine", code: -21, userInfo: [NSLocalizedDescriptionKey: "Không thể thêm AudioInput vào AVAssetWriter."])
        }
        writer.add(writerInput)

        self.currentAudioReader = reader
        self.currentAudioWriter = writer
        defer {
            self.currentAudioReader = nil
            self.currentAudioWriter = nil
            try? FileManager.default.removeItem(at: tempURL)
        }

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalSec = max(0.1, CMTimeGetSeconds(totalDuration))
        while reader.status == .reading {
            if isCancelled {
                reader.cancelReading()
                writer.cancelWriting()
                throw CancellationError()
            }
            if writerInput.isReadyForMoreMediaData {
                if let buffer = readerOutput.copyNextSampleBuffer() {
                    let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                    let currentSec = CMTimeGetSeconds(pts)
                    onProgress(max(0.0, min(0.99, currentSec / totalSec)))
                    writerInput.append(buffer)
                } else {
                    break
                }
            } else {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "ProjectExportEngine", code: -22, userInfo: [NSLocalizedDescriptionKey: "Lỗi đọc audio khi xuất WAV."])
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        if isCancelled { throw CancellationError() }
        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "ProjectExportEngine", code: -23, userInfo: [NSLocalizedDescriptionKey: "Lỗi ghi file WAV."])
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
        onProgress(1.0)
        Self.audioLogger.notice("Xuất WAV thành công: \(outputURL.path, privacy: .public)")
    }
}


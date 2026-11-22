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
                userInfo: [NSLocalizedDescriptionKey: "Failed to create M4A audio export session."]
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

        Self.audioLogger.notice("Starting M4A audio export to: \(outputURL.path, privacy: .public)")
        await withCheckedContinuation { continuation in
            session.exportAsynchronously { continuation.resume() }
        }

        if isCancelled || session.status == .cancelled {
            throw CancellationError()
        }
        if let error = session.error {
            Self.audioLogger.error("M4A export error: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        if session.status == .completed {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: outputURL)
            onProgress(1.0)
            Self.audioLogger.notice("M4A export succeeded: \(outputURL.path, privacy: .public)")
        } else {
            throw NSError(
                domain: "ProjectExportEngine",
                code: -11,
                userInfo: [NSLocalizedDescriptionKey: "M4A export did not complete (Status: \(session.status.rawValue))."]
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
            throw NSError(domain: "ProjectExportEngine", code: -20, userInfo: [NSLocalizedDescriptionKey: "Failed to add AudioMixOutput to AVAssetReader."])
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
            throw NSError(domain: "ProjectExportEngine", code: -21, userInfo: [NSLocalizedDescriptionKey: "Failed to add AudioInput to AVAssetWriter."])
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

        final class ProgressBox: @unchecked Sendable {
            var value: Double = 0.0
        }
        let progressBox = ProgressBox()
        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                onProgress(max(0.0, min(0.99, progressBox.value)))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer { progressTask.cancel() }

        let totalSec = max(0.1, CMTimeGetSeconds(totalDuration))
        let queue = DispatchQueue(label: "com.videoeditor.audioexport.queue", qos: .userInitiated)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                        let currentSec = CMTimeGetSeconds(pts)
                        progressBox.value = currentSec / totalSec
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        if isCancelled || reader.status == .cancelled || writer.status == .cancelled {
            throw CancellationError()
        }
        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "ProjectExportEngine", code: -22, userInfo: [NSLocalizedDescriptionKey: "Failed to read audio samples during WAV export."])
        }

        await writer.finishWriting()

        if isCancelled { throw CancellationError() }
        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "ProjectExportEngine", code: -23, userInfo: [NSLocalizedDescriptionKey: "Failed to write WAV file."])
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
        onProgress(1.0)
        Self.audioLogger.notice("WAV export succeeded: \(outputURL.path, privacy: .public)")
    }
}


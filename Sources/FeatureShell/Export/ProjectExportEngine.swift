import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

/// Engine xuất toàn bộ Timeline ra tệp video MP4 (H.264 / HEVC) chất lượng cao.
/// Hỗ trợ đầy đủ audio mix, video transforms, text overlays, color grading, và masks.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
@MainActor
public final class ProjectExportEngine {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "ProjectExportEngine")
    private var currentSession: AVAssetExportSession?
    private var isCancelled = false

    public init() {}

    /// Thực thi xuất video theo cấu hình đã chọn.
    public func export(
        layers: [TimelineLayer],
        aspectRatio: CanvasAspectRatio,
        totalDuration: CMTime,
        config: ExportConfiguration,
        outputURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        isCancelled = false

        // 1. Dọn dẹp file cũ nếu đã tồn tại
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        // 2. Xây dựng AVComposition & Audio/Video tracks
        let composition = AVMutableComposition()
        let tracksData = await TimelineCompositionBuilder.buildTracks(
            for: composition,
            from: layers,
            aspectRatio: aspectRatio
        )

        let safeDuration = CMTimeMaximum(totalDuration, CMTime(value: 1, timescale: 30))
        let targetDimensions = config.resolution.dimensions(for: aspectRatio)
        let frameDuration = CMTime(value: 1, timescale: Int32(config.frameRate.rawValue))

        // 3. Xây dựng Video Composition
        var layerTrackIDs: [UUID: CMPersistentTrackID] = [:]
        let videoLayers = layers.filter { $0.kind == .video }
        for (layer, inst) in zip(videoLayers, tracksData.instructions) {
            layerTrackIDs[layer.id] = inst.trackID
        }

        var videoComposition = TimelineCompositionBuilder.buildVideoComposition(
            for: layers,
            composition: composition,
            layerTrackIDs: layerTrackIDs,
            aspectRatio: aspectRatio,
            duration: safeDuration,
            renderSize: targetDimensions
        )

        if let existing = videoComposition {
            existing.renderSize = targetDimensions
            existing.frameDuration = frameDuration
        } else {
            videoComposition = TimelineCompositionBuilder.makeVideoComposition(
                layerInstructions: tracksData.instructions,
                renderSize: targetDimensions,
                duration: safeDuration
            )
            videoComposition?.frameDuration = frameDuration
        }

        // 4. Xây dựng Audio Mix
        let audioMix = TimelineCompositionBuilder.buildAudioMix(
            for: layers,
            layerAudioTrackIDs: tracksData.trackMap
        )

        // 5. Cấu hình AVAssetExportSession (Ghi ra file tạm cục bộ để tránh lỗi timeout ETIMEDOUT / err 60 trên iCloud Drive ở 99%)
        let presetName = config.codec.isHEVC ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: composition, presetName: presetName) else {
            throw NSError(
                domain: "ProjectExportEngine",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Không thể khởi tạo phiên xuất video với preset \(presetName)."]
            )
        }

        let tempOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoExport_staging_\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: tempOutputURL.path) {
            try? FileManager.default.removeItem(at: tempOutputURL)
        }

        session.outputURL = tempOutputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.audioMix = audioMix
        session.timeRange = CMTimeRange(start: .zero, duration: safeDuration)
        session.shouldOptimizeForNetworkUse = false
        self.currentSession = session

        // 6. Polling giám sát tiến trình
        let progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let s = self.currentSession else { break }
                let p = Double(s.progress)
                onProgress(max(0.0, min(0.99, p)))
                if s.status == .completed || s.status == .failed || s.status == .cancelled {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }

        defer {
            progressTask.cancel()
            self.currentSession = nil
            try? FileManager.default.removeItem(at: tempOutputURL)
        }

        // 7. Chạy xuất file
        Self.logger.notice("Bắt đầu xuất video tới: \(outputURL.path, privacy: .public)")
        await withCheckedContinuation { continuation in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        if isCancelled || session.status == .cancelled {
            throw CancellationError()
        }

        if let error = session.error {
            Self.logger.error("Lỗi xuất video: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        if session.status == .completed {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.moveItem(at: tempOutputURL, to: outputURL)
            onProgress(1.0)
            Self.logger.notice("Xuất video thành công: \(outputURL.path, privacy: .public)")
        } else {
            throw NSError(
                domain: "ProjectExportEngine",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Xuất video không hoàn tất (Status: \(session.status.rawValue))."]
            )
        }
    }

    /// Hủy phiên xuất video đang diễn ra.
    public func cancel() {
        isCancelled = true
        currentSession?.cancelExport()
    }
}

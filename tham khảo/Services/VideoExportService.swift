import Foundation
import AVFoundation

/// Cấu hình chất lượng xuất video tương thích với ExportHUDView
enum VideoExportPreset: Int, CaseIterable {
    case highestQuality = 0
    case fullHD1080p = 1
    case hd720p = 2

    var avPresetName: String {
        switch self {
        case .highestQuality:
            return AVAssetExportPresetHighestQuality
        case .fullHD1080p:
            return AVAssetExportPreset1920x1080
        case .hd720p:
            return AVAssetExportPreset1280x720
        }
    }

    var displayName: String {
        switch self {
        case .highestQuality:
            return "Cao nhất (Gốc)"
        case .fullHD1080p:
            return "1080p Full HD"
        case .hd720p:
            return "720p HD"
        }
    }
}

/// Lỗi xảy ra trong quá trình xuất video
enum VideoExportError: LocalizedError, Equatable {
    case sessionCreationFailed
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed:
            return "Không khởi tạo được bộ xuất."
        case .cancelled:
            return "Quá trình xuất video đã bị hủy."
        case .failed(let message):
            return message
        }
    }
}

/// Dịch vụ xuất video tập trung cho toàn bộ ứng dụng
@MainActor
final class VideoExportService {
    
    static let shared = VideoExportService()
    
    private var activeSession: AVAssetExportSession?
    private var progressTimer: Timer?
    private var currentExportID: UUID?
    private var activeOutputURL: URL?
    private var activeProgressHandler: ((Double) -> Void)?
    private var activeCompletion: ((Result<URL, Error>) -> Void)?

    private init() {}

    var isExporting: Bool {
        activeSession != nil
    }

    /// Xuất video từ EditorRender sang tệp MP4 đích
    func export(
        render: EditorRender,
        outputURL: URL,
        preset: VideoExportPreset,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Hủy bất kỳ phiên xuất nào đang chạy trước đó
        cancelExport()

        guard let exportSession = AVAssetExportSession(
            asset: render.composition,
            presetName: preset.avPresetName
        ) else {
            completion(.failure(VideoExportError.sessionCreationFailed))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = render.videoComposition
        exportSession.audioMix = render.audioMix
        exportSession.shouldOptimizeForNetworkUse = true

        let exportID = UUID()
        self.currentExportID = exportID
        self.activeSession = exportSession
        self.activeOutputURL = outputURL
        self.activeProgressHandler = progressHandler
        self.activeCompletion = completion

        // Timer cập nhật tiến trình
        let timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reportProgress(for: exportID)
            }
        }
        self.progressTimer = timer

        exportSession.exportAsynchronously { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishExport(for: exportID)
            }
        }
    }

    private func reportProgress(for exportID: UUID) {
        guard currentExportID == exportID, let session = activeSession else { return }
        activeProgressHandler?(Double(session.progress))
    }

    private func finishExport(for exportID: UUID) {
        guard currentExportID == exportID,
              let session = activeSession,
              let outputURL = activeOutputURL,
              let completion = activeCompletion else { return }
        let progressHandler = activeProgressHandler
        let status = session.status
        let error = session.error
        cleanup()

        switch status {
        case .completed:
            progressHandler?(1.0)
            completion(.success(outputURL))
        case .cancelled:
            completion(.failure(VideoExportError.cancelled))
        case .failed:
            completion(.failure(VideoExportError.failed(error?.localizedDescription ?? "Xuất không thành công.")))
        default:
            completion(.failure(VideoExportError.failed("Xuất không thành công.")))
        }
    }

    /// Hủy phiên xuất video đang diễn ra
    func cancelExport() {
        guard let session = activeSession else { return }
        session.cancelExport()
        cleanup()
    }

    private func cleanup() {
        progressTimer?.invalidate()
        progressTimer = nil
        activeSession = nil
        currentExportID = nil
        activeOutputURL = nil
        activeProgressHandler = nil
        activeCompletion = nil
    }
}

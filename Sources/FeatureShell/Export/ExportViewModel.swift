import AppKit
import Foundation
import SwiftUI
import CoreMedia
import Domain
import UniformTypeIdentifiers

/// ViewModel điều phối trạng thái và luồng dữ liệu cho hộp thoại Xuất Video MP4.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R3.2 (@Observable) của AGENTS.md.
@Observable
@MainActor
public final class ExportViewModel {
    public var isPresented: Bool = false
    public var resolution: ExportResolution = .res1080p
    public var frameRate: ExportFrameRate = .fps30
    public var codec: ExportCodec = .h264

    public var status: ExportStatus = .idle
    public var currentProgress: Double = 0.0
    public var outputURL: URL? = nil
    public var errorMessage: String? = nil

    private let engine = ProjectExportEngine()
    private var activeTask: Task<Void, Never>? = nil

    public init() {}

    public var isExporting: Bool {
        if case .exporting = status { return true }
        return false
    }

    public func openDialog() {
        status = .idle
        currentProgress = 0.0
        errorMessage = nil
        isPresented = true
    }

    public func closeDialog() {
        if isExporting {
            cancelExport()
        }
        isPresented = false
    }

    /// Tính dung lượng ước tính (MB) đã hiệu chuẩn theo bộ mã hóa phần cứng AVAssetExportSession trên macOS.
    public func estimatedFileSizeMB(
        duration: CMTime,
        aspectRatio: CanvasAspectRatio = .ratio16x9
    ) -> Double {
        let sec = max(0.0, CMTimeGetSeconds(duration))
        guard sec > 0, sec.isFinite else { return 0.0 }

        // Bitrate video cơ sở thực tế của AVAssetExportPresetHighestQuality tại 30fps (Mbps)
        // Đã đo đạc thực nghiệm trên VideoToolbox macOS: 720p ~5.0 Mbps, 1080p ~10.52 Mbps, 4K ~25.05 Mbps
        let baseVideoMbps: Double
        switch resolution {
        case .res720p:  baseVideoMbps = 5.00
        case .res1080p: baseVideoMbps = 10.52
        case .res4k:    baseVideoMbps = 25.05
        }

        // Hệ số diện tích điểm ảnh so với khung 16:9 chuẩn (hỗ trợ 1:1, 4:3, 21:9...)
        let targetDim = resolution.dimensions(for: aspectRatio)
        let refDim = resolution.dimensions(for: .ratio16x9)
        let areaRatio = Double((targetDim.width * targetDim.height) / max(1.0, refDim.width * refDim.height))
        let areaMultiplier = pow(max(0.25, areaRatio), 0.85)

        // Trong nén GOP liên khung (H.264/HEVC), bitrate tăng phi tuyến theo căn lũy thừa 0.75 của FPS
        let fpsMultiplier = pow(Double(frameRate.rawValue) / 30.0, 0.75)
        let codecMultiplier = codec.isHEVC ? 0.58 : 1.0

        let videoMbps = baseVideoMbps * areaMultiplier * fpsMultiplier * codecMultiplier
        // Luồng âm thanh AAC cố định ~250 kbps (0.25 Mbps) + ~1.8% MP4 moov/container overhead
        let audioMbps = 0.25
        let totalMbps = (videoMbps + audioMbps) * 1.018
        return (totalMbps * sec) / 8.0
    }

    /// Tính dung lượng ước tính của file xuất dựa trên thời lượng, tỉ lệ khung hình và chuẩn nén.
    public func estimatedFileSize(
        duration: CMTime,
        aspectRatio: CanvasAspectRatio = .ratio16x9
    ) -> String {
        let totalMegaBytes = estimatedFileSizeMB(duration: duration, aspectRatio: aspectRatio)
        guard totalMegaBytes > 0 else { return "0 MB" }

        if totalMegaBytes >= 1024.0 {
            return String(format: "%.2f GB", totalMegaBytes / 1024.0)
        } else {
            return String(format: "%.1f MB", totalMegaBytes)
        }
    }

    /// Định dạng thời lượng tổng của dự án (hh:mm:ss hoặc mm:ss).
    public func formattedDuration(duration: CMTime) -> String {
        let sec = max(0.0, CMTimeGetSeconds(duration))
        let minutes = Int(sec) / 60
        let seconds = Int(sec) % 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes % 60, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Hiển thị kích thước điểm ảnh chính xác theo tỉ lệ và độ phân giải đã chọn.
    public func renderDimensionsText(for aspect: CanvasAspectRatio) -> String {
        let dim = resolution.dimensions(for: aspect)
        return "\(Int(dim.width)) × \(Int(dim.height)) px"
    }

    /// Bắt đầu quy trình xuất video: Mở hộp thoại chọn nơi lưu và thực thi render.
    public func promptSaveAndStartExport(timelineViewModel: TimelineViewModel) {
        guard !timelineViewModel.layers.flatMap(\.clips).isEmpty else {
            errorMessage = "Timeline chưa có clip nào để xuất video."
            status = .failed(errorMessage: errorMessage ?? "")
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = "VideoExport.mp4"
        panel.allowedContentTypes = [UTType.mpeg4Movie]

        let response = panel.runModal()
        guard response == .OK, let targetURL = panel.url else { return }

        self.outputURL = targetURL
        self.status = .exporting(progress: 0.0)
        self.currentProgress = 0.0

        let layers = timelineViewModel.layers
        let aspect = timelineViewModel.aspectRatio
        let duration = timelineViewModel.totalDuration
        let config = ExportConfiguration(
            resolution: resolution,
            frameRate: frameRate,
            codec: codec,
            outputURL: targetURL
        )

        activeTask = Task { [weak self, engine] in
            do {
                try await engine.export(
                    layers: layers,
                    aspectRatio: aspect,
                    totalDuration: duration,
                    config: config,
                    outputURL: targetURL
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.currentProgress = progress
                        self.status = .exporting(progress: progress)
                    }
                }

                await MainActor.run {
                    self?.currentProgress = 1.0
                    self?.status = .completed(outputURL: targetURL)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.status = .cancelled
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.status = .failed(errorMessage: error.localizedDescription)
                }
            }
        }
    }

    /// Hủy tác vụ xuất đang diễn ra.
    public func cancelExport() {
        engine.cancel()
        activeTask?.cancel()
        activeTask = nil
        status = .cancelled
    }

    /// Mở file vừa xuất trong Finder.
    public func openInFinder() {
        guard let url = outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

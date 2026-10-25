import Foundation
import CoreGraphics

/// Lựa chọn độ phân giải khi xuất video MP4.
public enum ExportResolution: String, CaseIterable, Sendable, Codable {
    case res720p = "720p (HD)"
    case res1080p = "1080p (Full HD)"
    case res4k = "4K (UHD)"

    public var title: String {
        rawValue
    }

    /// Tính kích thước điểm ảnh chẵn chuẩn hóa theo CanvasAspectRatio hiện tại.
    public func dimensions(for aspect: CanvasAspectRatio) -> CGSize {
        let scale: CGFloat
        switch self {
        case .res720p:  scale = 720.0 / 1080.0
        case .res1080p: scale = 1.0
        case .res4k:    scale = 2160.0 / 1080.0
        }

        let rawWidth = aspect.renderSize.width * scale
        let rawHeight = aspect.renderSize.height * scale
        // Bộ mã hóa H.264 và HEVC yêu cầu kích thước bắt buộc phải là số chẵn
        let evenWidth = floor(rawWidth / 2.0) * 2.0
        let evenHeight = floor(rawHeight / 2.0) * 2.0
        return CGSize(width: max(2.0, evenWidth), height: max(2.0, evenHeight))
    }
}

/// Lựa chọn tốc độ khung hình (FPS) khi xuất video.
public enum ExportFrameRate: Int, CaseIterable, Sendable, Codable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    public var title: String {
        "\(rawValue) fps"
    }
}

/// Lựa chọn chuẩn mã hóa (Codec).
public enum ExportCodec: String, CaseIterable, Sendable, Codable {
    case h264 = "H.264 (Tương thích cao)"
    case hevc = "HEVC / H.265 (Tiết kiệm dung lượng)"

    public var isHEVC: Bool {
        self == .hevc
    }
}

/// Trạng thái của quá trình xuất video.
public enum ExportStatus: Equatable, Sendable {
    case idle
    case exporting(progress: Double)
    case completed(outputURL: URL)
    case failed(errorMessage: String)
    case cancelled
}

/// Cấu hình tổng hợp khi xuất video MP4.
public struct ExportConfiguration: Sendable, Equatable {
    public var resolution: ExportResolution
    public var frameRate: ExportFrameRate
    public var codec: ExportCodec
    public var customTitle: String
    public var outputURL: URL?

    public init(
        resolution: ExportResolution = .res1080p,
        frameRate: ExportFrameRate = .fps30,
        codec: ExportCodec = .h264,
        customTitle: String = "Untitled",
        outputURL: URL? = nil
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.customTitle = customTitle
        self.outputURL = outputURL
    }
}

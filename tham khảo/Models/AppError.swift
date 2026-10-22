import Foundation
import CoreMedia
import AVFoundation

/// Hệ thống lỗi tập trung toàn ứng dụng (Centralized Domain Errors)
public enum AppError: LocalizedError, Equatable, Sendable {
    
    // 1. Nhóm lỗi tập tin & phương tiện
    public enum Media: Equatable, Sendable {
        case fileNotFound(URL)
        case unsupportedFormat(String)
        case missingTrack(AVFoundation.AVMediaType)
        case trackAllocationFailed(AVFoundation.AVMediaType)
        case decodingFailed(reason: String)
        case invalidDuration
    }

    // 2. Nhóm lỗi phân tích (AI/Signal Processing)
    public enum Analysis: Equatable, Sendable {
        case emptyAudioSamples
        case beatDetectionFailed(reason: String)
        case poseRecognitionFailed(reason: String)
        case colorAnalysisFailed(reason: String)
    }

    // 3. Nhóm lỗi biên tập & Render (AVComposition)
    public enum Composition: Equatable, Sendable {
        case invalidTimeRange(requested: CMTimeRange, assetDuration: CMTime)
        case trackInsertionFailed(reason: String)
        case compositionBuildFailed(reason: String)
        case sourceChangedOrMissing
        case missingLinkedAudio
    }

    // 4. Nhóm lỗi xuất video (Export)
    public enum Export: Equatable, Sendable {
        case invalidComposition
        case exportSessionCreationFailed
        case cancelled
        case destinationUnwritable(URL)
        case failed(reason: String)
    }

    // 5. Nhóm lỗi lưu trữ dự án (Persistence)
    public enum Project: Equatable, Sendable {
        case readFailed(URL, reason: String)
        case schemaMismatch(expectedVersion: Int, foundVersion: Int)
        case writeFailed(URL, reason: String)
        case invalidSession(reason: String)
    }

    // Generic case để hỗ trợ thông báo chung hoặc di chuyển dần từ string error
    case message(String)
    case media(Media)
    case analysis(Analysis)
    case composition(Composition)
    case export(Export)
    case project(Project)

    public var errorDescription: String? {
        switch self {
        case .message(let msg):
            return msg
        case .media(let err):
            switch err {
            case .fileNotFound(let url):
                return "Không tìm thấy tệp: \(url.lastPathComponent)"
            case .unsupportedFormat(let fmt):
                return "Định dạng không được hỗ trợ: \(fmt)"
            case .missingTrack(let type):
                return "Không tìm thấy luồng \(type.rawValue) trong tệp."
            case .trackAllocationFailed(let type):
                return "Không thể khởi tạo luồng \(type.rawValue) mới."
            case .decodingFailed(let reason):
                return "Lỗi giải mã âm thanh: \(reason)"
            case .invalidDuration:
                return "Thời lượng tệp phương tiện không hợp lệ hoặc quá ngắn."
            }
        case .analysis(let err):
            switch err {
            case .emptyAudioSamples:
                return "Dữ liệu âm thanh trống hoặc không hợp lệ."
            case .beatDetectionFailed(let reason):
                return "Không thể nhận diện nhịp: \(reason)"
            case .poseRecognitionFailed(let reason):
                return "Không thể nhận diện dáng người: \(reason)"
            case .colorAnalysisFailed(let reason):
                return "Không thể phân tích màu sắc: \(reason)"
            }
        case .composition(let err):
            switch err {
            case .invalidTimeRange:
                return "Khoảng thời gian yêu cầu không hợp lệ."
            case .trackInsertionFailed(let reason):
                return "Không thể chèn track vào bản dựng: \(reason)"
            case .compositionBuildFailed(let reason):
                return "Không thể tạo bản dựng: \(reason)"
            case .sourceChangedOrMissing:
                return "Nguồn đã thay đổi hoặc không còn trên máy. Thêm lại nguồn hoặc mở lại phiên để liên kết lại."
            case .missingLinkedAudio:
                return "Không tìm thấy tệp âm thanh liên kết với video."
            }
        case .export(let err):
            switch err {
            case .invalidComposition:
                return "Bản dựng không hợp lệ hoặc rỗng."
            case .exportSessionCreationFailed:
                return "Không khởi tạo được bộ xuất video."
            case .cancelled:
                return "Quá trình xuất video đã bị hủy."
            case .destinationUnwritable(let url):
                return "Không thể ghi tệp vào đường dẫn đích: \(url.path)"
            case .failed(let reason):
                return "Xuất video thất bại: \(reason)"
            }
        case .project(let err):
            switch err {
            case .readFailed(let url, let reason):
                return "Không thể đọc dự án tại \(url.lastPathComponent): \(reason)"
            case .schemaMismatch(let expected, let found):
                return "Phiên bản tệp dự án (\(found)) không khớp với phiên bản hỗ trợ (\(expected))."
            case .writeFailed(let url, let reason):
                return "Không thể lưu dự án tại \(url.lastPathComponent): \(reason)"
            case .invalidSession(let reason):
                return "Phiên không hợp lệ: \(reason)"
            }
        }
    }
}

/// Giữ typealias để tương thích ngược 100% với các vị trí gọi EditorError hiện tại
public typealias EditorError = AppError

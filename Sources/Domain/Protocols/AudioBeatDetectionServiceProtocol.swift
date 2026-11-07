import Foundation

/// Hợp đồng dịch vụ phân tích phổ âm thanh để tự động nhận diện điểm nhịp (Beat / Onset Detection).
public protocol AudioBeatDetectionServiceProtocol: Sendable {
    /// Phân tích file âm thanh/video tại `url` và trả về danh sách các điểm beat theo `mode`.
    func detectBeats(
        url: URL,
        mode: AudioBeatDetectionMode
    ) async -> [AudioBeatMarker]

    /// Phân tích mảng mẫu PCM Mono (dùng cho cả file thực tế và kiểm thử trực tiếp).
    func detectBeats(
        samples: [Float],
        sampleRate: Double,
        mode: AudioBeatDetectionMode
    ) -> [AudioBeatMarker]
}


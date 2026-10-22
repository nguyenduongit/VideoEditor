import Foundation

public struct AudioMatchResult: Sendable {
    public let videoName: String
    public let audioName: String
    public let audioURL: URL
    public let offsetSeconds: Double
    public let score: Double        // Điểm SNR so với nền nhiễu
    public let correlation: Double  // Hệ số tương quan cực đại r_max (0.0 -> 1.0)
    public let isMatch: Bool        // Đạt chuẩn khớp (r_max >= 0.05 && score >= 3.0)
    
    public init(
        videoName: String,
        audioName: String,
        audioURL: URL,
        offsetSeconds: Double,
        score: Double,
        correlation: Double = 0.0,
        isMatch: Bool
    ) {
        self.videoName = videoName
        self.audioName = audioName
        self.audioURL = audioURL
        self.offsetSeconds = offsetSeconds
        self.score = score
        self.correlation = correlation
        self.isMatch = isMatch
    }
    
    public var formattedOffset: String {
        let sign = offsetSeconds >= 0 ? "+" : ""
        return String(format: "%@%.2fs", sign, offsetSeconds)
    }
    
    public var formattedScore: String {
        return String(format: "SNR %.1fx (r=%.1f%%)", score, correlation * 100.0)
    }
    
    public var description: String {
        if isMatch {
            return "\(audioName) (\(formattedScore) • Offset \(formattedOffset))"
        } else {
            return "Không khớp (Max \(formattedScore))"
        }
    }
}

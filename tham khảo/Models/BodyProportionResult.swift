import Foundation
import CoreMedia

public struct FrameBoundingBox: Sendable {
    public let time: CMTime
    public let rect: CGRect
    
    public init(time: CMTime, rect: CGRect) {
        self.time = time
        self.rect = rect
    }
}

public struct FrameLegGuide: Sendable {
    public let time: CMTime
    public let hipYNorm: Double
    public let ankleYNorm: Double

    public init(time: CMTime, hipYNorm: Double, ankleYNorm: Double) {
        self.time = time
        self.hipYNorm = hipYNorm
        self.ankleYNorm = ankleYNorm
    }
}

public struct BodyProportionResult: Sendable {
    public let videoName: String
    public let initialRatio: Double     // Tỉ lệ gốc = L_leg / L_torso (ví dụ: 1.22)
    public let targetRatio: Double      // Tỉ lệ chuẩn mục tiêu (ví dụ: 1.55)
    public let scaleFactor: Double      // Hệ số kéo dài chân s_y (ví dụ: 1.16 = +16%)
    public let hipYNorm: Double         // Tọa độ Y hông/mông (chuẩn hóa 0.0 -> 1.0 từ đáy)
    public let ankleYNorm: Double       // Tọa độ Y mắt cá chân (chuẩn hóa 0.0 -> 1.0 từ đáy)
    public let isApplied: Bool
    
    // Auto Crop Tracking & Filtering
    public let videoSize: CGSize
    public let trackingData: [FrameBoundingBox]
    public let legGuideFrames: [FrameLegGuide]
    public let personCount: Int
    public let maxPersonHeightRatio: Double
    
    public init(
        videoName: String,
        initialRatio: Double,
        targetRatio: Double = 1.55,
        scaleFactor: Double,
        hipYNorm: Double,
        ankleYNorm: Double,
        isApplied: Bool = true,
        videoSize: CGSize = .zero,
        trackingData: [FrameBoundingBox] = [],
        legGuideFrames: [FrameLegGuide] = [],
        personCount: Int = 1,
        maxPersonHeightRatio: Double = 0.35
    ) {
        self.videoName = videoName
        self.initialRatio = initialRatio
        self.targetRatio = targetRatio
        self.scaleFactor = scaleFactor
        self.hipYNorm = hipYNorm
        self.ankleYNorm = ankleYNorm
        self.isApplied = isApplied
        self.videoSize = videoSize
        self.trackingData = trackingData
        self.legGuideFrames = legGuideFrames.sorted { CMTimeCompare($0.time, $1.time) < 0 }
        self.personCount = personCount
        self.maxPersonHeightRatio = maxPersonHeightRatio
    }

    /// Nội suy hai đường AI theo source time. Khi Vision mất một vài frame,
    /// giá trị gần nhất vẫn được dùng thay vì làm đường kẻ nhảy về mặc định.
    public func legGuides(at time: CMTime) -> (hipYNorm: Double, ankleYNorm: Double) {
        guard !legGuideFrames.isEmpty else { return (hipYNorm, ankleYNorm) }
        if CMTimeCompare(time, legGuideFrames[0].time) <= 0 {
            return (legGuideFrames[0].hipYNorm, legGuideFrames[0].ankleYNorm)
        }
        let last = legGuideFrames.count - 1
        if CMTimeCompare(time, legGuideFrames[last].time) >= 0 {
            return (legGuideFrames[last].hipYNorm, legGuideFrames[last].ankleYNorm)
        }

        var low = 0
        var high = last
        while low + 1 < high {
            let middle = (low + high) / 2
            if CMTimeCompare(legGuideFrames[middle].time, time) <= 0 {
                low = middle
            } else {
                high = middle
            }
        }
        let a = legGuideFrames[low]
        let b = legGuideFrames[high]
        let span = max(0.000001, b.time.seconds - a.time.seconds)
        let progress = max(0.0, min(1.0, (time.seconds - a.time.seconds) / span))
        return (
            a.hipYNorm + (b.hipYNorm - a.hipYNorm) * progress,
            a.ankleYNorm + (b.ankleYNorm - a.ankleYNorm) * progress
        )
    }
    
    /// Ngưỡng chiều cao tối đa cho phép xuất bản dọc theo số lượng người:
    /// - 1 người: <= 50% (0.50)
    /// - 2 người: <= 35% (0.35)
    /// - 3 người: <= 30% (0.30)
    /// - Từ 4 người trở lên: Không hỗ trợ bản dọc
    public var maxAllowedHeightRatio: Double? {
        switch personCount {
        case 1: return 0.50
        case 2: return 0.35
        case 3: return 0.30
        default: return nil
        }
    }
    
    /// Điều kiện xuất video phụ 9:16: Video ngang 16:9, thỏa mãn bảng ngưỡng số người & chiều cao
    public var canExportVerticalCrop: Bool {
        guard videoSize.width > videoSize.height else { return false }
        guard let allowedMax = maxAllowedHeightRatio else { return false }
        return round(maxPersonHeightRatio * 100.0) <= (allowedMax * 100.0) || maxPersonHeightRatio <= (allowedMax + 0.005)
    }
    
    public var formattedRatio: String {
        let percent = (scaleFactor - 1.0) * 100.0
        if scaleFactor <= 1.005 {
            return String(format: "1:%.2f (Đã chuẩn ≥ 1:%.2f, giữ nguyên)", initialRatio, targetRatio)
        } else {
            return String(format: "1:%.2f ➔ 1:%.2f (+%.1f%%)", initialRatio, targetRatio, percent)
        }
    }
    
    public var description: String {
        return "Tỉ lệ: \(formattedRatio) [Hông: \(Int(hipYNorm * 100))%, Mắt cá: \(Int(ankleYNorm * 100))%]"
    }
}

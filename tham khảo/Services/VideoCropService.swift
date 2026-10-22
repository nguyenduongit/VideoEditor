import Foundation
import CoreGraphics
import CoreMedia

public enum ExportType: Sendable {
    case verticalTikTok
    case horizontalYouTube
    case verticalOriginal
    case horizontalOriginal
}

public final class VideoCropService: @unchecked Sendable {
    
    public static let shared = VideoCropService()
    
    private init() {}
    
    /// Tính toán khung Crop Rect:
    /// - Zoom tính trực tiếp từ khung lớn nhất của tỷ lệ đã chọn; không tự thu
    ///   khung theo kích thước người.
    /// - Chiều dọc (Y) chỉ do offsetY quyết định.
    /// - Chiều ngang (X): Tự động lia máy mượt mà (Catmull-Rom Spline) bám theo tâm người để nhân vật luôn ở chính giữa khung hình.
    public func calculateDynamicCropRect(
        for time: CMTime,
        proportion: BodyProportionResult,
        cropMode: Int = 0,
        zoom: Double = 1.0,
        offsetY: Double = 0.5,
        autoPan: Bool = true,
        panX: Double = 0.5
    ) -> CGRect {
        let videoSize = proportion.videoSize
        guard videoSize.width > 0, videoSize.height > 0 else { return .zero }
        
        let trackingData = proportion.trackingData
        let originalRatio = videoSize.width / videoSize.height
        let targetRatio: CGFloat
        
        switch cropMode {
        case 1:
            targetRatio = 9.0 / 16.0
        case 2:
            targetRatio = 16.0 / 9.0
        case 3:
            targetRatio = 1.0
        case 4:
            targetRatio = 4.0 / 5.0
        default:
            targetRatio = originalRatio
        }
        
        var maxCropWidth: CGFloat
        var maxCropHeight: CGFloat
        if targetRatio > originalRatio {
            maxCropWidth = videoSize.width
            maxCropHeight = maxCropWidth / targetRatio
        } else {
            maxCropHeight = videoSize.height
            maxCropWidth = maxCropHeight * targetRatio
        }
        
        let clampedZoom = CGFloat(max(1.0, min(3.0, zoom)))
        let cropHeight = max(32.0, maxCropHeight / clampedZoom)
        let cropWidth = max(32.0, maxCropWidth / clampedZoom)
        
        let maxY = max(0.0, videoSize.height - cropHeight)
        let maxX = max(0.0, videoSize.width - cropWidth)
        
        let cropY = maxY * CGFloat(max(0.0, min(1.0, offsetY)))
        
        var cropX: CGFloat
        if autoPan && !trackingData.isEmpty {
            let subjectCenterXNorm = interpolateCenterX(at: time, from: trackingData)
            let subjectCenterX = subjectCenterXNorm * videoSize.width
            cropX = subjectCenterX - cropWidth / 2.0
        } else {
            cropX = maxX * CGFloat(max(0.0, min(1.0, panX)))
        }
        cropX = max(0.0, min(maxX, cropX))
        
        return CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }
    
    public func calculateDynamicCropRect(
        for time: CMTime,
        proportion: BodyProportionResult,
        exportType: ExportType
    ) -> CGRect {
        let mode: Int
        switch exportType {
        case .verticalTikTok: mode = 1
        case .horizontalYouTube: mode = 2
        default: mode = 0
        }
        return calculateDynamicCropRect(for: time, proportion: proportion, cropMode: mode, zoom: 1.0, offsetY: 0.5, autoPan: true, panX: 0.5)
    }
    
    // MARK: - Nội suy mượt mà trục ngang qua Catmull-Rom Spline
    private func interpolateCenterX(at time: CMTime, from data: [FrameBoundingBox]) -> CGFloat {
        guard !data.isEmpty else { return 0.5 }
        if data.count == 1 { return data[0].rect.midX }
        
        let seconds = time.seconds
        let count = data.count
        
        // Giới hạn đầu và cuối video
        if seconds <= data[0].time.seconds { return data[0].rect.midX }
        if seconds >= data[count - 1].time.seconds { return data[count - 1].rect.midX }
        
        // Tìm phân đoạn thời gian
        var idx = 0
        for i in 0..<(count - 1) {
            if data[i].time.seconds <= seconds && seconds <= data[i + 1].time.seconds {
                idx = i
                break
            }
        }
        
        let t1 = data[idx].time.seconds
        let t2 = data[idx + 1].time.seconds
        let timeRange = t2 - t1
        guard timeRange > 0 else { return data[idx].rect.midX }
        
        let t = CGFloat((seconds - t1) / timeRange)
        
        let f0 = data[max(0, idx - 1)].rect.midX
        let f1 = data[idx].rect.midX
        let f2 = data[idx + 1].rect.midX
        let f3 = data[min(count - 1, idx + 2)].rect.midX
        
        let interpX = catmullRom(p0: f0, p1: f1, p2: f2, p3: f3, t: t)
        return max(0.0, min(1.0, interpX))
    }
    
    private func catmullRom(p0: CGFloat, p1: CGFloat, p2: CGFloat, p3: CGFloat, t: CGFloat) -> CGFloat {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (
            (2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
        )
    }
    
    private func calculateMedian(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }
    
    // MARK: - Khung hình mặc định (Nếu không nhận diện được người)
    private func defaultCropRect(for size: CGSize, exportType: ExportType) -> CGRect {
        let originalRatio = size.width / size.height
        let targetRatio: CGFloat
        
        switch exportType {
        case .verticalTikTok:
            targetRatio = 9.0 / 16.0
        case .horizontalYouTube:
            targetRatio = originalRatio > 1.0 ? originalRatio : 16.0 / 9.0
        case .verticalOriginal, .horizontalOriginal:
            targetRatio = originalRatio
        }
        
        var cropWidth = size.width
        var cropHeight = size.height
        
        if targetRatio > originalRatio {
            // Mục tiêu ngang hơn -> Cắt bớt chiều cao
            cropHeight = cropWidth / targetRatio
        } else {
            // Mục tiêu dọc hơn -> Cắt bớt chiều rộng
            cropWidth = cropHeight * targetRatio
        }
        
        let x = (size.width - cropWidth) / 2.0
        let y = (size.height - cropHeight) / 2.0
        
        return CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
    }
}

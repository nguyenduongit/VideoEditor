import Foundation
import AVFoundation
import Vision
import CoreGraphics
import CoreImage

public final class BodyPoseService: @unchecked Sendable {
    
    public static let shared = BodyPoseService()
    public var defaultTargetRatio: Double = 1.48 // Chuẩn Tỉ Lệ Vàng Vũ Công: 1 : 1.48
    
    private init() {}
    
    /// Phân tích video để xác định tư thế nhân vật chính và tự động tính toán hệ số co dãn để đưa chân về đúng Tỉ Lệ Vàng 1 : 1.48
    public func analyzeBodyProportion(
        videoURL: URL,
        targetRatio: Double = 1.48,
        sampleCount: Int = 0,
        sampleInterval: Double = 2.0,
        shouldCancel: (() -> Bool)? = nil,
        logHandler: ((String) -> Void)? = nil
    ) -> BodyProportionResult? {
        let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let durationSec = asset.duration.seconds
        guard durationSec > 1.0 else { return nil }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        guard asset.tracks(withMediaType: .video).first != nil else { return nil }
        // Mặc định lấy đúng một frame đại diện mỗi 2 giây (2s/frame). Các frame nằm giữa hai
        // mốc sẽ dùng tọa độ nội suy khi preview/xuất, không cần chạy Vision lại.
        // sampleCount > 0 vẫn cho phép tác vụ kiểm thử yêu cầu số mẫu cụ thể.
        let interval = sampleInterval > 0 ? sampleInterval : 2.0
        let totalSamples = sampleCount > 0
            ? sampleCount
            : max(1, Int(ceil(durationSec / interval)))
        var sampleTimes: [NSValue] = []
        
        for i in 0..<totalSamples {
            let t = sampleCount > 0
                ? Double(i) * durationSec / Double(totalSamples)
                : Double(i) * interval
            let cmTime = CMTime(seconds: min(max(0, durationSec - 0.05), t), preferredTimescale: 60000)
            sampleTimes.append(NSValue(time: cmTime))
        }
        
        var detectedMetrics: [BodyMetricsSample] = []
        var detectedLegGuides: [FrameLegGuide] = []
        var trackingData: [FrameBoundingBox] = []
        var detectedPersonCounts: [Int] = []
        var detectedPersonHeights: [Double] = []
        var videoSize: CGSize = .zero
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let progressStep = max(1, totalSamples / 10)
        
        logHandler?("🤖 Đang xác định hai đường kéo chân bằng Vision AI: \(totalSamples) frame đại diện (2s/frame)...")
        
        for (sampleIndex, timeValue) in sampleTimes.enumerated() {
            if shouldCancel?() == true {
                generator.cancelAllCGImageGeneration()
                return nil
            }
            if sampleIndex > 0, sampleIndex % progressStep == 0 {
                logHandler?("AI xác định hai đường: \(Int(Double(sampleIndex) / Double(totalSamples) * 100.0))%")
            }
            let time = timeValue.timeValue
            var actualTime = CMTime.invalid
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: &actualTime) else {
                continue
            }
            let frameTime = actualTime.isValid ? actualTime : time
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            if videoSize == .zero {
                videoSize = CGSize(width: cgImage.width, height: cgImage.height)
            }
            
            
            do {
                try handler.perform([poseRequest])
                if shouldCancel?() == true {
                    generator.cancelAllCGImageGeneration()
                    return nil
                }
                guard let observations = poseRequest.results, !observations.isEmpty else {
                    continue
                }
                
                // Thu thập thông tin chi tiết từng nhân vật trong khung hình
                struct PersonCandidate {
                    let obs: VNHumanBodyPoseObservation
                    let minX: CGFloat
                    let maxX: CGFloat
                    let minY: CGFloat
                    let maxY: CGFloat
                    var height: Double { Double(maxY - minY) }
                    var centerX: Double { Double((minX + maxX) / 2.0) }
                }
                
                var candidates: [PersonCandidate] = []
                
                for obs in observations {
                    var pMinX: CGFloat = 1.0, pMaxX: CGFloat = 0.0
                    var pMinY: CGFloat = 1.0, pMaxY: CGFloat = 0.0
                    var pHasValidPoints = false
                    
                    if let recognizedPoints = try? obs.recognizedPoints(.all) {
                        for point in recognizedPoints.values where point.confidence > 0.20 {
                            let loc = point.location
                            if loc.x < pMinX { pMinX = loc.x }
                            if loc.x > pMaxX { pMaxX = loc.x }
                            if loc.y < pMinY { pMinY = loc.y }
                            if loc.y > pMaxY { pMaxY = loc.y }
                            pHasValidPoints = true
                        }
                    }
                    
                    if pHasValidPoints {
                        let pHeight = Double(pMaxY - pMinY)
                        // Bỏ qua các điểm nhiễu quá nhỏ (< 8% khung hình)
                        if pHeight > 0.08 {
                            candidates.append(PersonCandidate(
                                obs: obs,
                                minX: pMinX,
                                maxX: pMaxX,
                                minY: pMinY,
                                maxY: pMaxY
                            ))
                        }
                    }
                }
                
                guard !candidates.isEmpty else { continue }
                
                // Tìm chiều cao lớn nhất trong khung hình (nhân vật chính/vũ công gần camera)
                let maxHeightInFrame = candidates.map { $0.height }.max() ?? 0.0
                
                // Lọc BỎ người đi đường ở hậu cảnh (những người có chiều cao < 60% so với vũ công chính)
                let mainDancers = candidates.filter { $0.height >= maxHeightInFrame * 0.60 }
                
                guard !mainDancers.isEmpty else { continue }
                
                // Đếm số người và chiều cao của các vũ công chính
                detectedPersonCounts.append(mainDancers.count)
                detectedPersonHeights.append(contentsOf: mainDancers.map { $0.height })
                
                // Tính Bounding Box bao quanh DUY NHẤT các vũ công chính để căn giữa tuyệt đối
                let dancerMinX = mainDancers.map { $0.minX }.min() ?? 0.0
                let dancerMaxX = mainDancers.map { $0.maxX }.max() ?? 1.0
                let dancerMinY = mainDancers.map { $0.minY }.min() ?? 0.0
                let dancerMaxY = mainDancers.map { $0.maxY }.max() ?? 1.0
                
                let rect = CGRect(x: dancerMinX, y: dancerMinY, width: dancerMaxX - dancerMinX, height: dancerMaxY - dancerMinY)
                trackingData.append(FrameBoundingBox(time: frameTime, rect: rect))
                
                // Chọn vũ công trung tâm nhất để tính tỉ lệ kéo chân
                let primaryPerson = mainDancers.min(by: { p1, p2 in
                    return abs(p1.centerX - 0.5) < abs(p2.centerX - 0.5)
                })?.obs ?? mainDancers[0].obs
                
                if let metrics = extractBodyMetrics(from: primaryPerson) {
                    detectedMetrics.append(metrics)
                    detectedLegGuides.append(FrameLegGuide(
                        time: frameTime,
                        hipYNorm: metrics.guideHipY,
                        ankleYNorm: metrics.ankleY
                    ))
                }
            } catch {
                continue
            }
        }
        
        guard !detectedMetrics.isEmpty else {
            logHandler?("⚠️ Không thể nhận diện rõ tư thế toàn thân của nhân vật trong video.")
            return nil
        }
        
        // LỌC KHUNG HÌNH DÁNG ĐỨNG THẲNG (Upright Standing Posture):
        // Khi nhảy múa, các động tác cúi/khụy/co chân làm thân ngắn lại và đẩy tỉ lệ ảo lên cao.
        // Chỉ đo đạc trên các khung hình có độ duỗi người cao nhất (>= 88% chiều cao tối đa) để tìm tỉ lệ cơ thể thật.
        let maxBodyHeight = detectedMetrics.map { $0.totalHeight }.max() ?? 0.0
        let uprightSamples = detectedMetrics.filter { $0.totalHeight >= maxBodyHeight * 0.88 }
        let validSamples = uprightSamples.isEmpty ? detectedMetrics : uprightSamples
        
        // Tính giá trị trung vị (Median) trên các khung hình đứng chuẩn
        let medianRatio = calculateMedian(validSamples.map { $0.ratio })
        let medianHipY = calculateMedian(validSamples.map { $0.guideHipY })
        let medianAnkleY = calculateMedian(validSamples.map { $0.ankleY })
        
        // Đo đạc số người tối đa và chiều cao đại diện
        let personCount = detectedPersonCounts.isEmpty ? 1 : (detectedPersonCounts.max() ?? 1)
        let representativePersonHeight = detectedPersonHeights.isEmpty ? 0.35 : calculateMedian(detectedPersonHeights)
        
        // Làm mượt trackingData để camera panning theo từng frame mượt mà
        let smoothedTrackingData = smoothTrackingData(trackingData)
        let smoothedLegGuides = smoothLegGuides(detectedLegGuides)
        
        // THUẬT TOÁN TỈ LỆ THÍCH ỨNG (Adaptive Golden Ratio):
        // Tính đúng lượng co dãn cần thiết để đưa tỉ lệ của nhân vật về chuẩn 1 : 1.48
        var adaptiveScale: Double
        if medianRatio >= targetRatio {
            // Đã đạt hoặc vượt chuẩn (chân đã dài sẵn) -> Giữ nguyên tỉ lệ thật (1.0), không kéo dãn thêm
            adaptiveScale = 1.0
        } else {
            adaptiveScale = targetRatio / medianRatio
            // Giới hạn an toàn tự nhiên: tối đa +10% (1.10) để vóc dáng luôn tự nhiên, không bị dị dạng quá khổ
            adaptiveScale = min(1.10, max(1.0, adaptiveScale))
        }
        
        let result = BodyProportionResult(
            videoName: videoURL.lastPathComponent,
            initialRatio: medianRatio,
            targetRatio: targetRatio,
            scaleFactor: adaptiveScale,
            hipYNorm: medianHipY,
            ankleYNorm: medianAnkleY,
            isApplied: true,
            videoSize: videoSize,
            trackingData: smoothedTrackingData,
            legGuideFrames: smoothedLegGuides,
            personCount: personCount,
            maxPersonHeightRatio: representativePersonHeight
        )
        
        let heightFormatted = String(format: "%.1f%%", representativePersonHeight * 100.0)
        let cropEligibility: String
        let isHorizontalVideo = videoSize.width > videoSize.height
        
        if !isHorizontalVideo {
            // Video nguồn vốn dĩ là video dọc: Luôn xuất bản dọc gốc chuẩn, không cần xét điều kiện cắt cúp
            cropEligibility = "Video dọc gốc 9:16 -> Xuất bản dọc chuẩn"
        } else if result.canExportVerticalCrop {
            // Video nguồn là video ngang và đạt chuẩn auto-crop: Xuất 2 bản (Ngang + Dọc phụ)
            cropEligibility = "Video ngang 16:9 -> Đủ điều kiện xuất thêm bản dọc phụ 9:16 (TikTok)"
        } else if let limit = result.maxAllowedHeightRatio {
            // Video nguồn là video ngang nhưng người quá to: Chỉ xuất 1 bản ngang gốc
            cropEligibility = "Video ngang 16:9 -> Chỉ xuất bản ngang 16:9 (Chiều cao \(heightFormatted) > chuẩn \(Int(limit * 100))% cho \(personCount) người)"
        } else {
            // Video nguồn là video ngang nhưng quá 3 người: Chỉ xuất 1 bản ngang gốc
            cropEligibility = "Video ngang 16:9 -> Chỉ xuất bản ngang 16:9 (Đội hình \(personCount) người > 3 người)"
        }
        logHandler?("💃 PHÂN TÍCH THÀNH CÔNG: \(smoothedLegGuides.count)/\(totalSamples) frame có hai đường hợp lệ, tỉ lệ \(result.formattedRatio), \(personCount) người, chiều cao \(heightFormatted) khung hình -> \(cropEligibility)")
        
        return result
    }
    
    // MARK: - Làm mượt Bounding Box Tracking (Gaussian 1-2-1 Smoothing)
    private func smoothTrackingData(_ data: [FrameBoundingBox]) -> [FrameBoundingBox] {
        guard data.count > 2 else { return data }
        var smoothed: [FrameBoundingBox] = []
        let n = data.count
        for i in 0..<n {
            let prev = data[max(0, i - 1)].rect
            let curr = data[i].rect
            let next = data[min(n - 1, i + 1)].rect
            
            let smoothX = (prev.origin.x + 2.0 * curr.origin.x + next.origin.x) / 4.0
            let smoothY = (prev.origin.y + 2.0 * curr.origin.y + next.origin.y) / 4.0
            let smoothW = (prev.width + 2.0 * curr.width + next.width) / 4.0
            let smoothH = (prev.height + 2.0 * curr.height + next.height) / 4.0
            
            let smoothRect = CGRect(x: smoothX, y: smoothY, width: smoothW, height: smoothH)
            smoothed.append(FrameBoundingBox(time: data[i].time, rect: smoothRect))
        }
        return smoothed
    }

    /// Chặn điểm Vision nhảy bất thường rồi lọc đối xứng 5 frame. Vì toàn bộ video
    /// được phân tích trước nên bộ lọc không tạo độ trễ khi preview hoặc xuất.
    private func smoothLegGuides(_ data: [FrameLegGuide]) -> [FrameLegGuide] {
        guard data.count > 1 else { return data }
        let sorted = data.sorted { CMTimeCompare($0.time, $1.time) < 0 }
        var stabilized: [FrameLegGuide] = []
        stabilized.reserveCapacity(sorted.count)

        for guide in sorted {
            guard let previous = stabilized.last else {
                stabilized.append(guide)
                continue
            }
            let deltaTime = max(1.0 / 120.0, guide.time.seconds - previous.time.seconds)
            let maxStep = max(0.006, min(0.08, deltaTime * 0.8))
            func limited(_ value: Double, around reference: Double) -> Double {
                max(reference - maxStep, min(reference + maxStep, value))
            }
            let hip = limited(guide.hipYNorm, around: previous.hipYNorm)
            let ankle = limited(guide.ankleYNorm, around: previous.ankleYNorm)
            if hip > ankle + 0.02 {
                stabilized.append(FrameLegGuide(time: guide.time, hipYNorm: hip, ankleYNorm: ankle))
            } else {
                stabilized.append(FrameLegGuide(time: guide.time, hipYNorm: previous.hipYNorm, ankleYNorm: previous.ankleYNorm))
            }
        }

        let weights = [1.0, 2.0, 3.0, 2.0, 1.0]
        return stabilized.indices.map { index in
            var hip = 0.0
            var ankle = 0.0
            var total = 0.0
            for offset in -2...2 {
                let sampleIndex = max(0, min(stabilized.count - 1, index + offset))
                let weight = weights[offset + 2]
                hip += stabilized[sampleIndex].hipYNorm * weight
                ankle += stabilized[sampleIndex].ankleYNorm * weight
                total += weight
            }
            return FrameLegGuide(
                time: stabilized[index].time,
                hipYNorm: hip / total,
                ankleYNorm: ankle / total
            )
        }
    }
    
    // MARK: - Trích xuất tọa độ hông, mắt cá chân và tỉ lệ
    private struct BodyMetricsSample {
        let hipY: Double
        let guideHipY: Double
        let ankleY: Double
        let torsoLength: Double
        let legLength: Double
        let totalHeight: Double
        let ratio: Double
    }
    
    private func extractBodyMetrics(from person: VNHumanBodyPoseObservation) -> BodyMetricsSample? {
        let leftHip = try? person.recognizedPoint(.leftHip)
        let rightHip = try? person.recognizedPoint(.rightHip)
        let root = try? person.recognizedPoint(.root)
        
        let leftShoulder = try? person.recognizedPoint(.leftShoulder)
        let rightShoulder = try? person.recognizedPoint(.rightShoulder)
        let neck = try? person.recognizedPoint(.neck)
        let nose = try? person.recognizedPoint(.nose)
        
        let leftAnkle = try? person.recognizedPoint(.leftAnkle)
        let rightAnkle = try? person.recognizedPoint(.rightAnkle)
        let leftKnee = try? person.recognizedPoint(.leftKnee)
        let rightKnee = try? person.recognizedPoint(.rightKnee)
        
        let minConf: Float = 0.15
        
        // 1. Tọa độ Hông / Mông (Hip Y)
        var hipY: Double = 0.0
        var hipCount = 0
        if let l = leftHip, l.confidence > minConf { hipY += Double(l.location.y); hipCount += 1 }
        if let r = rightHip, r.confidence > minConf { hipY += Double(r.location.y); hipCount += 1 }
        if hipCount > 0 {
            hipY /= Double(hipCount)
        } else if let rt = root, rt.confidence > minConf {
            hipY = Double(rt.location.y)
        } else {
            return nil
        }
        
        // 2. Tọa độ Đỉnh đầu (Head Top Y): Đo từ đỉnh đầu thực tế của nhân vật để xác định chuẩn chiều dài nửa thân trên
        var headTopY: Double = 0.0
        let confNose = (nose?.confidence ?? 0) > minConf
        let confNeck = (neck?.confidence ?? 0) > minConf
        let confLShoulder = (leftShoulder?.confidence ?? 0) > minConf
        let confRShoulder = (rightShoulder?.confidence ?? 0) > minConf
        
        if confNose && confNeck {
            let noseY = Double(nose!.location.y)
            let neckY = Double(neck!.location.y)
            let headHeight = max(0.04, (noseY - neckY) * 1.5)
            headTopY = noseY + headHeight * 0.5
        } else if confNose {
            headTopY = Double(nose!.location.y) + 0.05
        } else if confNeck {
            headTopY = Double(neck!.location.y) + 0.10
        } else if confLShoulder || confRShoulder {
            var shoulderY = 0.0
            var count = 0
            if confLShoulder { shoulderY += Double(leftShoulder!.location.y); count += 1 }
            if confRShoulder { shoulderY += Double(rightShoulder!.location.y); count += 1 }
            headTopY = (shoulderY / Double(count)) + 0.12
        } else {
            return nil
        }
        
        var kneeY: Double?
        var kneeTotal = 0.0
        var kneeCount = 0
        if let l = leftKnee, l.confidence > minConf { kneeTotal += Double(l.location.y); kneeCount += 1 }
        if let r = rightKnee, r.confidence > minConf { kneeTotal += Double(r.location.y); kneeCount += 1 }
        if kneeCount > 0 { kneeY = kneeTotal / Double(kneeCount) }

        // 3. Tọa độ Mắt cá chân (Ankle Y)
        var ankleY: Double = 0.0
        var ankleCount = 0
        if let l = leftAnkle, l.confidence > minConf { ankleY += Double(l.location.y); ankleCount += 1 }
        if let r = rightAnkle, r.confidence > minConf { ankleY += Double(r.location.y); ankleCount += 1 }
        if ankleCount > 0 {
            ankleY /= Double(ankleCount)
        } else if let kneeY = kneeY {
            let thighLength = hipY - kneeY
            ankleY = max(0.02, kneeY - thighLength * 0.9)
        } else {
            return nil
        }
        
        guard headTopY > hipY && hipY > ankleY else {
            return nil
        }
        
        let torsoLength = headTopY - hipY
        let legLength = hipY - ankleY
        let totalHeight = headTopY - ankleY
        // Đường trên trong UI nằm ở đáy vùng hông/đầu đùi. Trên ảnh mẫu,
        // trung điểm hông–gối cho 43%, khớp chính xác vị trí người dùng đánh dấu.
        let guideHipY = kneeY.map { (hipY + $0) / 2.0 }
            ?? (hipY - legLength * 0.25)
        
        guard torsoLength > 0.02 && legLength > 0.03 else {
            return nil
        }
        
        let ratio = legLength / torsoLength
        return BodyMetricsSample(
            hipY: hipY,
            guideHipY: guideHipY,
            ankleY: ankleY,
            torsoLength: torsoLength,
            legLength: legLength,
            totalHeight: totalHeight,
            ratio: ratio
        )
    }
    
    private func calculateMedian(_ array: [Double]) -> Double {
        guard !array.isEmpty else { return 0.0 }
        let sorted = array.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }
}

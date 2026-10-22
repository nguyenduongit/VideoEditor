import Foundation
import AppKit
import CoreGraphics
import CoreImage

/// Dịch vụ kết xuất lớp phủ đồ họa (Overlay) số đếm nhịp và thanh tiến trình chuẩn bị lên khung hình video
public final class DanceBeatOverlayRenderer {
    
    public static let shared = DanceBeatOverlayRenderer()
    
    private init() {}
    
    // Bộ nhớ đệm (Cache) lưu trữ trước các khung hình overlay cho từng trạng thái để đạt tốc độ 60+ FPS
    private var imageCache: [String: CIImage] = [:]
    private let cacheLock = NSLock()
    
    /// Xóa bộ nhớ đệm khi thay đổi kích thước khung hình hoặc cài đặt
    public func clearCache() {
        cacheLock.lock()
        imageCache.removeAll()
        cacheLock.unlock()
    }
    
    /// Tính toán phân bổ số phách cho từng câu đếm:
    /// Nếu vòng cuối cùng không đủ 8 số thì dồn chung với vòng trước đó (vd: 12 số: 1..12).
    public static func computePhraseLengths(totalCounts: Int) -> [Int] {
        guard totalCounts > 0 else { return [8] }
        let fullPhrases = totalCounts / 8
        let remainder = totalCounts % 8
        
        if remainder == 0 {
            return Array(repeating: 8, count: max(1, fullPhrases))
        } else if fullPhrases == 0 {
            return [remainder]
        } else {
            var lengths: [Int] = []
            if fullPhrases > 1 {
                lengths.append(contentsOf: Array(repeating: 8, count: fullPhrases - 1))
            }
            // Vòng cuối dồn chung với vòng trước: 8 + remainder
            lengths.append(8 + remainder)
            return lengths
        }
    }
    
    /// Trả về CIImage lớp phủ đồ họa tại thời điểm `time` trong video (gồm tên phân đoạn ở 3s đầu và số đếm nhịp)
    public func overlayImage(
        at time: Double,
        renderSize: CGSize,
        bpm: Double,
        intervalMode: CountIntervalMode,
        startOffset: Double?,
        endOffset: Double?,
        duration: Double,
        segmentTitle: String? = nil,
        showNumbers: Bool = true
    ) -> CIImage? {
        // 1. Lớp phủ tên đoạn (Hiển thị ở 3s đầu tiên của mỗi đoạn, vị trí cách trên 20%, canh giữa, chữ trắng viền đen, rộng 60%, fade in/out)
        let titleImage: CIImage?
        if let title = segmentTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleImage = renderTitleOverlay(title: title, time: time, renderSize: renderSize)
        } else {
            titleImage = nil
        }
        
        // 2. Lớp phủ số đếm & thanh tiến trình chuẩn bị (chỉ hiển thị nếu bật chức năng hiển thị số)
        let beatImage: CIImage?
        if showNumbers {
            beatImage = renderBeatOverlay(
                at: time,
                renderSize: renderSize,
                bpm: bpm,
                intervalMode: intervalMode,
                startOffset: startOffset,
                endOffset: endOffset,
                duration: duration
            )
        } else {
            beatImage = nil
        }
        
        // 3. Kết hợp 2 lớp phủ
        if let titleImg = titleImage, let beatImg = beatImage {
            return titleImg.composited(over: beatImg)
        } else if let titleImg = titleImage {
            return titleImg
        } else if let beatImg = beatImage {
            return beatImg
        } else {
            return nil
        }
    }
    
    // MARK: - Title Overlay (Tên đoạn ở 3s đầu)
    private func renderTitleOverlay(
        title: String,
        time: Double,
        renderSize: CGSize
    ) -> CIImage? {
        guard time >= 0.0 && time <= 3.0 else { return nil }
        
        // Hiển thị rõ nét 100% ngay từ frame đầu tiên (0.0 -> 2.5s) và fade out mượt mà (2.5s -> 3.0s)
        let alpha: CGFloat
        if time <= 2.5 {
            alpha = 1.0
        } else {
            alpha = CGFloat((3.0 - time) / 0.5)
        }
        
        guard alpha > 0.01 else { return nil }
        
        // Quantize alpha into 30 steps (đảm bảo animation mượt 30fps và tái sử dụng bộ nhớ đệm cache)
        let alphaStep = Int(round(alpha * 30.0))
        let width = Int(renderSize.width)
        let height = Int(renderSize.height)
        let sanitizedTitle = title.replacingOccurrences(of: " ", with: "_")
        let key = "title_\(sanitizedTitle)_a\(alphaStep)_\(width)x\(height)"
        
        return getOrCreateImage(key: key, renderSize: renderSize) {
            drawTitleImage(title: title, alpha: CGFloat(alphaStep) / 30.0, renderSize: renderSize)
        }
    }
    
    private func drawTitleImage(title: String, alpha: CGFloat, renderSize: CGSize) -> CIImage? {
        let width = Int(renderSize.width)
        let height = Int(renderSize.height)
        guard width > 0 && height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Độ rộng mục tiêu: chiếm 60% chiều rộng khung hình theo yêu cầu
        let targetWidth = renderSize.width * 0.60
        let testFont = NSFont.systemFont(ofSize: 100, weight: .heavy)
        let testWidth = (title as NSString).size(withAttributes: [.font: testFont]).width
        let idealFontSize = 100.0 * (targetWidth / max(1.0, testWidth))
        let maxFontSize = renderSize.height * 0.085
        let finalFontSize = max(24.0, min(idealFontSize, maxFontSize))
        let font = NSFont.systemFont(ofSize: finalFontSize, weight: .heavy)
        
        let textShadow = NSShadow()
        textShadow.shadowOffset = CGSize(width: 0, height: -3.0)
        textShadow.shadowBlurRadius = 8.0
        textShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.75 * alpha)
        
        // Pass 1: Viền đen (Black Outline)
        let strokeAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 0.95 * alpha),
            .strokeColor: NSColor(calibratedWhite: 0.0, alpha: 0.95 * alpha),
            .strokeWidth: 9.0, // 9% kích thước font tạo đường viền đen đậm nét bao quanh
            .shadow: textShadow
        ]
        
        // Pass 2: Chữ trắng (White Fill)
        let fillAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 1.0 * alpha)
        ]
        
        let strokeStr = NSAttributedString(string: title, attributes: strokeAttr)
        let fillStr = NSAttributedString(string: title, attributes: fillAttr)
        
        let textSize = fillStr.size()
        
        // Vị trí: Cách trên 20% (y = height * 0.80), canh giữa horizontal (x = width / 2.0)
        let centerX = renderSize.width / 2.0
        let centerY = renderSize.height * 0.80
        
        let drawPt = CGPoint(
            x: centerX - (textSize.width / 2.0),
            y: centerY - (textSize.height / 2.0)
        )
        
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext
        
        // Vẽ viền đen trước, sau đó vẽ thân chữ trắng đè lên
        strokeStr.draw(at: drawPt)
        fillStr.draw(at: drawPt)
        
        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }
    
    // MARK: - Beat Overlay (Đếm nhịp & Thanh chuẩn bị)
    private func renderBeatOverlay(
        at time: Double,
        renderSize: CGSize,
        bpm: Double,
        intervalMode: CountIntervalMode,
        startOffset: Double?,
        endOffset: Double?,
        duration: Double
    ) -> CIImage? {
        guard let startOffset = startOffset, duration > 0.5, bpm > 30.0 else {
            return nil
        }
        
        let secondsPerBeat = 60.0 / bpm
        let secondsPerCount = secondsPerBeat * Double(intervalMode.rawValue)
        let prepDuration = 4.0 * secondsPerBeat  // 1 nhịp chuẩn bị = 4 phách
        let prepStartTime = max(0.0, startOffset - prepDuration)
        let maxLimit = endOffset != nil ? min(duration - 0.3, endOffset! + 0.02) : (duration - 0.3)
        
        // 1. Ngoài phạm vi hoạt động
        if time < prepStartTime - 0.05 || time > maxLimit + 0.5 {
            return nil
        }
        
        let availableDuration = max(0.0, maxLimit - startOffset)
        let totalCounts = Int(floor(availableDuration / secondsPerCount + 0.001)) + 1
        let phraseLengths = DanceBeatOverlayRenderer.computePhraseLengths(totalCounts: totalCounts)
        let firstPhraseLength = phraseLengths.first ?? 8
        
        // 2. Giai đoạn chuẩn bị (Thanh tiến trình: Nền vàng, phần chạy màu xanh lá)
        if time < startOffset {
            let elapsedPrep = max(0.0, time - prepStartTime)
            let actualPrepDur = max(0.1, startOffset - prepStartTime)
            let progress = min(1.0, max(0.0, elapsedPrep / actualPrepDur))
            let prepStep = Int(round(progress * 100.0)) // 101 bước đệm từ 0% đến 100%
            let key = "prep_\(prepStep)_\(firstPhraseLength)_\(Int(renderSize.width))x\(Int(renderSize.height))"
            return getOrCreateImage(key: key, renderSize: renderSize) {
                renderOverlayFrame(
                    renderSize: renderSize,
                    prepProgress: progress,
                    phraseIndex: 1,
                    totalNumbersInPhrase: firstPhraseLength,
                    activeNumber: nil
                )
            }
        }
        
        // 3. Giai đoạn đếm chính thức (Hiển thị đúng số gọi theo câu, dồn vòng cuối nếu không đủ 8)
        if time <= maxLimit {
            let elapsedCount = max(0.0, time - startOffset)
            let currentCountIndex = Int(elapsedCount / secondsPerCount)
            
            var phraseIndex = 1
            var beatInPhrase = 1
            var currentPhraseLength = 8
            var accumulated = 0
            
            for (pIdx, length) in phraseLengths.enumerated() {
                if currentCountIndex < accumulated + length {
                    phraseIndex = pIdx + 1
                    beatInPhrase = (currentCountIndex - accumulated) + 1
                    currentPhraseLength = length
                    break
                }
                accumulated += length
            }
            
            let key = "count_p\(phraseIndex)_b\(beatInPhrase)_len\(currentPhraseLength)_\(Int(renderSize.width))x\(Int(renderSize.height))"
            return getOrCreateImage(key: key, renderSize: renderSize) {
                renderOverlayFrame(
                    renderSize: renderSize,
                    prepProgress: nil,
                    phraseIndex: phraseIndex,
                    totalNumbersInPhrase: currentPhraseLength,
                    activeNumber: beatInPhrase
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Cache Access
    private func getOrCreateImage(key: String, renderSize: CGSize, builder: () -> CIImage?) -> CIImage? {
        cacheLock.lock()
        if let cached = imageCache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        guard let newImg = builder() else { return nil }
        
        cacheLock.lock()
        imageCache[key] = newImg
        cacheLock.unlock()
        return newImg
    }
    
    // MARK: - CoreGraphics Drawing
    private func renderOverlayFrame(
        renderSize: CGSize,
        prepProgress: Double?,
        phraseIndex: Int,
        totalNumbersInPhrase: Int,
        activeNumber: Int?
    ) -> CIImage? {
        let width = Int(renderSize.width)
        let height = Int(renderSize.height)
        guard width > 0 && height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        let centerX = renderSize.width / 2.0
        
        // Chiếm 80% chiều rộng khung hình theo yêu cầu
        let targetSpan = renderSize.width * 0.80
        let M = max(1, totalNumbersInPhrase)
        
        // Kích thước hình tròn to rõ, tự động co giãn vừa vặn M số (kể cả khi vòng dồn lên 12, 14 số)
        let denom = CGFloat(M - 1) + 0.76
        let baseD = 0.76 * (targetSpan / max(1.0, denom))
        let circleD = min(baseD, renderSize.height * 0.095)
        let circleR = circleD / 2.0
        let circleSpacing = (M > 1) ? (targetSpan - circleD) / CGFloat(M - 1) : 0.0
        
        // Vị trí cách mép dưới khoảng 10%
        let line2Y = renderSize.height * 0.10
        let numbersStartX = (M > 1) ? (centerX - (CGFloat(M - 1) / 2.0 * circleSpacing)) : centerX
        
        // 1. Thanh tiến trình chuẩn bị (Line 1 - Nằm trên dòng số đếm, không có backdrop scrim)
        if let progress = prepProgress {
            let barHeight = max(13.0, circleD * 0.22)
            let barCornerRadius = barHeight / 2.0
            let barY = line2Y + circleR + max(20.0, circleD * 0.32)
            let barWidth = targetSpan
            let barStartX = centerX - (barWidth / 2.0)
            let barRect = CGRect(x: barStartX, y: barY, width: barWidth, height: barHeight)
            let barPath = CGPath(roundedRect: barRect, cornerWidth: barCornerRadius, cornerHeight: barCornerRadius, transform: nil)
            
            // A. Nền Vàng (Yellow Background) với bóng mờ giúp nhận diện rõ ràng trên mọi video
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -2.0), blur: 6.0, color: NSColor(calibratedWhite: 0, alpha: 0.45).cgColor)
            context.addPath(barPath)
            context.setFillColor(NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.10, alpha: 1.0).cgColor)
            context.fillPath()
            context.restoreGState()
            
            // B. Phần Chạy Màu Xanh Lá (Green Running Progress)
            let fillWidth = max(0.0, min(barWidth, barWidth * CGFloat(progress)))
            if fillWidth > 0 {
                context.saveGState()
                context.addPath(barPath)
                context.clip() // Bo tròn theo capsule
                
                let fillRect = CGRect(x: barStartX, y: barY, width: fillWidth, height: barHeight)
                context.setFillColor(NSColor(calibratedRed: 0.15, green: 0.82, blue: 0.32, alpha: 1.0).cgColor)
                context.fill(fillRect)
                
                // Vạch chia 4 ô nhịp (25%, 50%, 75%) để người học dễ căn thời gian
                context.setFillColor(NSColor(calibratedWhite: 0.0, alpha: 0.22).cgColor)
                for q in 1...3 {
                    let qx = barStartX + (barWidth * CGFloat(q) / 4.0)
                    context.fill(CGRect(x: qx - 1.0, y: barY, width: 2.0, height: barHeight))
                }
                context.restoreGState()
            }
            
            // C. Viền nhẹ bao quanh thanh tiến trình
            context.saveGState()
            context.addPath(barPath)
            context.setStrokeColor(NSColor(calibratedWhite: 0.0, alpha: 0.25).cgColor)
            context.setLineWidth(1.2)
            context.strokePath()
            context.restoreGState()
        }
        
        // 2. Dòng 2: M Số đếm trong hình tròn (chiếm 80% chiều rộng)
        // Màu chữ đen xám theo yêu cầu
        let charcoalTextColor = NSColor(calibratedWhite: 0.16, alpha: 1.0)
        
        // Màu viền đỏ cam glow mềm mại theo yêu cầu
        let redOrangeBorder = NSColor(calibratedRed: 1.0, green: 0.32, blue: 0.05, alpha: 1.0)
        let redOrangeGlow = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.08, alpha: 0.85)
        
        let hyphenFont = NSFont.systemFont(ofSize: circleD * 0.40, weight: .bold)
        let hyphenShadow = NSShadow()
        hyphenShadow.shadowOffset = CGSize(width: 0, height: -1.0)
        hyphenShadow.shadowBlurRadius = 4.0
        hyphenShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.70)
        
        let hyphenAttr: [NSAttributedString.Key: Any] = [
            .font: hyphenFont,
            .foregroundColor: NSColor.white,
            .shadow: hyphenShadow
        ]
        
        for num in 1...M {
            let cx = numbersStartX + (CGFloat(num - 1) * circleSpacing)
            let cy = line2Y
            let isActive = (activeNumber == num)
            
            // Khi gọi đến số nào thì số đó zoom to hơn 10%
            let scale: CGFloat = isActive ? 1.10 : 1.0
            let curD = circleD * scale
            let curR = curD / 2.0
            let circleRect = CGRect(x: cx - curR, y: cy - curR, width: curD, height: curD)
            let circlePath = CGPath(ellipseIn: circleRect, transform: nil)
            
            context.saveGState()
            
            // A. Nền tròn trắng kèm bóng đổ mềm giúp số luôn tương phản cao trên bất kỳ nền video nào
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -2.0), blur: 6.0, color: NSColor(calibratedWhite: 0.0, alpha: 0.35).cgColor)
            context.addPath(circlePath)
            context.setFillColor(NSColor.white.cgColor)
            context.fillPath()
            context.restoreGState()
            
            // B. Khi gọi đến số nào: Border ngoài màu đỏ cam glow mềm mại
            if isActive {
                context.saveGState()
                context.setShadow(offset: .zero, blur: 18.0 * (circleD / 80.0), color: redOrangeGlow.cgColor)
                context.addPath(circlePath)
                context.setStrokeColor(redOrangeBorder.cgColor)
                context.setLineWidth(max(5.0, curD * 0.075))
                context.strokePath()
                context.restoreGState()
            }
            
            // C. Hiển thị đúng số gọi (Số đầu câu là phraseIndex: 1-2-3-4... 2-2-3-4... Các số sau: 2..8..12)
            let label: String = (num == 1) ? "\(phraseIndex)" : "\(num)"
            
            // Tự động điều chỉnh cỡ chữ nếu số có 2 chữ số (vd: 10, 11, 12...)
            var baseFontSize = curD * 0.54
            if label.count > 1 {
                baseFontSize *= (label.count == 2 ? 0.78 : 0.65)
            }
            let numFont = NSFont.systemFont(ofSize: baseFontSize, weight: .heavy)
            
            let numAttr: [NSAttributedString.Key: Any] = [
                .font: numFont,
                .foregroundColor: charcoalTextColor // Chữ đen xám
            ]
            let numStr = NSAttributedString(string: label, attributes: numAttr)
            let numSize = numStr.size()
            let numPt = CGPoint(
                x: cx - (numSize.width / 2.0),
                y: cy - (numSize.height / 2.0) + (curD * 0.02)
            )
            
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = graphicsContext
            numStr.draw(at: numPt)
            context.restoreGState()
            
            // D. Dấu gạch nối (-) giữa các số
            if num < M {
                let hyphenX = cx + (circleSpacing / 2.0)
                let hyphenStr = NSAttributedString(string: "-", attributes: hyphenAttr)
                let hSize = hyphenStr.size()
                let hPt = CGPoint(x: hyphenX - (hSize.width / 2.0), y: cy - (hSize.height / 2.0))
                hyphenStr.draw(at: hPt)
            }
        }
        
        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }
}

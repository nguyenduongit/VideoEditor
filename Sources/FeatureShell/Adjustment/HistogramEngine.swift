import Foundation
import Domain
import AVFoundation
@preconcurrency import CoreImage
import CoreGraphics
import os

/// Dữ liệu biểu đồ phân bố ánh sáng & màu sắc 256 bins
public struct HistogramData: Sendable, Equatable {
    public let redBins: [Float]
    public let greenBins: [Float]
    public let blueBins: [Float]
    public let lumaBins: [Float]
    public let hasHighlightClipping: Bool
    public let hasShadowClipping: Bool

    public static let empty = HistogramData(
        redBins: Array(repeating: 0.0, count: 256),
        greenBins: Array(repeating: 0.0, count: 256),
        blueBins: Array(repeating: 0.0, count: 256),
        lumaBins: Array(repeating: 0.0, count: 256),
        hasHighlightClipping: false,
        hasShadowClipping: false
    )
}

/// Engine tính toán biểu đồ Histogram thời gian thực từ khung hình video
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
/// Bọc CIContext từ Apple Core Image SDK (CIContext là thread-safe theo tài liệu chính thức Apple; mọi hàm tính toán đều là thuần stateless) (R8.3).
public final class HistogramEngine: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "HistogramEngine")
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public init() {}

    /// Tính toán Histogram 256 bins từ CIImage hiện tại.
    public func calculateHistogram(from image: CIImage) -> HistogramData {
        let sampleWidth = 128
        let sampleHeight = 72
        let sampleRect = CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)

        let scaleX = CGFloat(sampleWidth) / max(1.0, image.extent.width)
        let scaleY = CGFloat(sampleHeight) / max(1.0, image.extent.height)
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var pixelData = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        ciContext.render(
            scaledImage,
            toBitmap: &pixelData,
            rowBytes: sampleWidth * 4,
            bounds: sampleRect,
            format: .RGBA8,
            colorSpace: colorSpace
        )

        var rCounts = [Int](repeating: 0, count: 256)
        var gCounts = [Int](repeating: 0, count: 256)
        var bCounts = [Int](repeating: 0, count: 256)
        var lCounts = [Int](repeating: 0, count: 256)

        let totalPixels = sampleWidth * sampleHeight
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Int(pixelData[offset])
            let g = Int(pixelData[offset + 1])
            let b = Int(pixelData[offset + 2])
            // Công thức Luma chuẩn ITU-R BT.709
            let lum = Int(0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b))

            rCounts[r] += 1
            gCounts[g] += 1
            bCounts[b] += 1
            lCounts[min(255, lum)] += 1
        }

        let maxCount = max(1, max(rCounts.max() ?? 1, max(gCounts.max() ?? 1, bCounts.max() ?? 1)))
        let rNorm = rCounts.map { Float($0) / Float(maxCount) }
        let gNorm = gCounts.map { Float($0) / Float(maxCount) }
        let bNorm = bCounts.map { Float($0) / Float(maxCount) }
        let lNorm = lCounts.map { Float($0) / Float(maxCount) }

        // Cảnh báo clipping nếu vùng quá sáng hoặc quá tối vượt ngưỡng 5% tổng điểm ảnh
        let highlightPixels = lCounts[250...255].reduce(0, +)
        let shadowPixels = lCounts[0...5].reduce(0, +)
        let clipThreshold = Int(Double(totalPixels) * 0.05)

        return HistogramData(
            redBins: rNorm,
            greenBins: gNorm,
            blueBins: bNorm,
            lumaBins: lNorm,
            hasHighlightClipping: highlightPixels > clipThreshold,
            hasShadowClipping: shadowPixels > clipThreshold
        )
    }

    /// Phân tích và trích xuất chỉ số đo đạc quang phổ (Color Telemetry) từ khung hình video.
    /// Tự động loại trừ viền đen (letterbox/pillarbox) và ước lượng cân bằng trắng theo các điểm ảnh gần trung tính.
    public func analyzeTelemetry(from image: CIImage) -> ColorTelemetryProfile {
        let sampleWidth = 128
        let sampleHeight = 72
        let sampleRect = CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)

        let translated = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))
        let scaleX = CGFloat(sampleWidth) / max(1.0, translated.extent.width)
        let scaleY = CGFloat(sampleHeight) / max(1.0, translated.extent.height)
        let scaledImage = translated.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var pixelData = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        ciContext.render(
            scaledImage, toBitmap: &pixelData, rowBytes: sampleWidth * 4,
            bounds: sampleRect, format: .RGBA8, colorSpace: colorSpace
        )

        let roi = detectActiveContentBounds(pixelData: pixelData, width: sampleWidth, height: sampleHeight)
        let metrics = computePixelMetrics(pixelData: pixelData, width: sampleWidth, roi: roi)
        let (p5, p95, shadowClip, highlightClip) = computeToneMetrics(lCounts: metrics.lCounts, totalPixels: metrics.count)
        let (cast, suggestedTemp, suggestedTint) = detectColorCast(
            meanR: metrics.wbRed, meanG: metrics.wbGreen, meanBlue: metrics.wbBlue
        )

        return ColorTelemetryProfile(
            averageLuma: metrics.avgLuma, blackPoint: p5, whitePoint: p95, dynamicRange: max(0.0, p95 - p5),
            shadowClippingRatio: shadowClip, highlightClippingRatio: highlightClip,
            meanRed: metrics.meanR, meanGreen: metrics.meanG, meanBlue: metrics.meanB,
            dominantCast: cast, suggestedTempOffset: suggestedTemp, suggestedTintOffset: suggestedTint,
            averageSaturation: metrics.avgSat
        )
    }

    private struct PixelAnalysisMetrics {
        let meanR: Float
        let meanG: Float
        let meanB: Float
        let wbRed: Float
        let wbGreen: Float
        let wbBlue: Float
        let avgLuma: Float
        let avgSat: Float
        let lCounts: [Int]
        let count: Int
    }

    private func detectActiveContentBounds(pixelData: [UInt8], width: Int, height: Int) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        func isBlackRow(_ y: Int) -> Bool {
            var sum = 0
            for x in 0..<width {
                let off = (y * width + x) * 4
                let lum = Int(pixelData[off]) + Int(pixelData[off + 1]) + Int(pixelData[off + 2])
                if lum > 15 { return false }
                sum += lum
            }
            return sum < width * 9
        }
        func isBlackCol(_ x: Int, minY: Int, maxY: Int) -> Bool {
            guard maxY >= minY else { return false }
            for y in minY...maxY {
                let off = (y * width + x) * 4
                if Int(pixelData[off]) + Int(pixelData[off + 1]) + Int(pixelData[off + 2]) > 15 { return false }
            }
            return true
        }
        var minY = 0, maxY = height - 1
        while minY < height / 3 && isBlackRow(minY) { minY += 1 }
        while maxY > (height * 2) / 3 && isBlackRow(maxY) { maxY -= 1 }
        var minX = 0, maxX = width - 1
        while minX < width / 3 && isBlackCol(minX, minY: minY, maxY: maxY) { minX += 1 }
        while maxX > (width * 2) / 3 && isBlackCol(maxX, minY: minY, maxY: maxY) { maxX -= 1 }
        if (maxX - minX + 1) * (maxY - minY + 1) < (width * height) / 4 {
            return (0, width - 1, 0, height - 1)
        }
        return (minX, maxX, minY, maxY)
    }

    private func computePixelMetrics(
        pixelData: [UInt8],
        width: Int,
        roi: (minX: Int, maxX: Int, minY: Int, maxY: Int)
    ) -> PixelAnalysisMetrics {
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumL = 0.0, sumSat = 0.0
        var wbR = 0.0, wbG = 0.0, wbB = 0.0, wbWeightSum = 0.0
        var lCounts = [Int](repeating: 0, count: 256)
        var count = 0

        for y in roi.minY...roi.maxY {
            for x in roi.minX...roi.maxX {
                let offset = (y * width + x) * 4
                let r = Double(pixelData[offset])
                let g = Double(pixelData[offset + 1])
                let b = Double(pixelData[offset + 2])
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let maxRGB = max(r, max(g, b))
                let minRGB = min(r, min(g, b))
                let sat = maxRGB > 0.0 ? (maxRGB - minRGB) / maxRGB : 0.0

                sumR += r; sumG += g; sumB += b; sumL += lum; sumSat += sat
                lCounts[min(255, Int(lum))] += 1
                count += 1

                let normLum = lum / 255.0
                if normLum >= 0.12 && normLum <= 0.88 && sat < 0.35 {
                    let weight = 1.0 - (sat / 0.35) * 0.7
                    wbR += r * weight; wbG += g * weight; wbB += b * weight
                    wbWeightSum += weight
                }
            }
        }
        let total = Double(max(1, count))
        let meanR = Float((sumR / total) / 255.0)
        let meanG = Float((sumG / total) / 255.0)
        let meanB = Float((sumB / total) / 255.0)
        let resolvedWBR = wbWeightSum > 20.0 ? Float((wbR / wbWeightSum) / 255.0) : meanR
        let resolvedWBG = wbWeightSum > 20.0 ? Float((wbG / wbWeightSum) / 255.0) : meanG
        let resolvedWBB = wbWeightSum > 20.0 ? Float((wbB / wbWeightSum) / 255.0) : meanB

        return PixelAnalysisMetrics(
            meanR: meanR, meanG: meanG, meanB: meanB,
            wbRed: resolvedWBR, wbGreen: resolvedWBG, wbBlue: resolvedWBB,
            avgLuma: Float((sumL / total) / 255.0), avgSat: Float(sumSat / total),
            lCounts: lCounts, count: max(1, count)
        )
    }

    private func computeToneMetrics(lCounts: [Int], totalPixels: Int) -> (Float, Float, Float, Float) {
        var cumulative = 0
        var p5: Float?
        var p95: Float?
        let p5Threshold = Int(Double(totalPixels) * 0.05)
        let p95Threshold = Int(Double(totalPixels) * 0.95)

        for (idx, count) in lCounts.enumerated() {
            cumulative += count
            if p5 == nil && cumulative >= p5Threshold { p5 = Float(idx) / 255.0 }
            if p95 == nil && cumulative >= p95Threshold { p95 = Float(idx) / 255.0; break }
        }
        let resolvedP5 = p5 ?? 0.05
        let resolvedP95 = p95 ?? 0.95
        let shadowClip = Float(lCounts[0...5].reduce(0, +)) / Float(totalPixels)
        let highlightClip = Float(lCounts[250...255].reduce(0, +)) / Float(totalPixels)
        return (resolvedP5, resolvedP95, shadowClip, highlightClip)
    }

    private func detectColorCast(meanR: Float, meanG: Float, meanBlue: Float) -> (String, Float, Float) {
        let cast: String
        if meanR - meanBlue > 0.05 {
            cast = "warm"
        } else if meanBlue - meanR > 0.05 {
            cast = "cool"
        } else if meanG - (meanR + meanBlue) / 2.0 > 0.04 {
            cast = "green"
        } else if (meanR + meanBlue) / 2.0 - meanG > 0.04 {
            cast = "magenta"
        } else {
            cast = "neutral"
        }
        let suggestedTemp = max(-100.0, min(100.0, (meanBlue - meanR) * 150.0))
        let suggestedTint = max(-100.0, min(100.0, (((meanR + meanBlue) / 2.0) - meanG) * 150.0))
        return (cast, suggestedTemp, suggestedTint)
    }

    /// Trích xuất và tổng hợp quang phổ từ nhiều khung hình (20%, 50%, 80% thời lượng clip) để đại diện toàn cảnh.
    public func extractMultiFrameTelemetry(from assetURL: URL, start: CMTime, duration: CMTime) async -> ColorTelemetryProfile? {
        let durSec = max(0.0, CMTimeGetSeconds(duration))
        let ratios: [Double] = durSec > 0.4 ? [0.2, 0.5, 0.8] : [0.5]
        var profiles: [ColorTelemetryProfile] = []

        for r in ratios {
            let sampleTime = CMTimeAdd(start, CMTime(seconds: durSec * r, preferredTimescale: 600))
            if let image = await extractFrame(from: assetURL, at: sampleTime) {
                profiles.append(analyzeTelemetry(from: image))
            }
        }
        guard !profiles.isEmpty else { return nil }
        let n = Float(profiles.count)
        let avgR = profiles.map(\.meanRed).reduce(0, +) / n
        let avgG = profiles.map(\.meanGreen).reduce(0, +) / n
        let avgB = profiles.map(\.meanBlue).reduce(0, +) / n
        let avgP5 = profiles.map(\.blackPoint).reduce(0, +) / n
        let avgP95 = profiles.map(\.whitePoint).reduce(0, +) / n
        let avgTemp = profiles.map(\.suggestedTempOffset).reduce(0, +) / n
        let avgTint = profiles.map(\.suggestedTintOffset).reduce(0, +) / n
        let (cast, _, _) = detectColorCast(meanR: avgR, meanG: avgG, meanBlue: avgB)

        return ColorTelemetryProfile(
            averageLuma: profiles.map(\.averageLuma).reduce(0, +) / n,
            blackPoint: avgP5,
            whitePoint: avgP95,
            dynamicRange: max(0.0, avgP95 - avgP5),
            shadowClippingRatio: profiles.map(\.shadowClippingRatio).reduce(0, +) / n,
            highlightClippingRatio: profiles.map(\.highlightClippingRatio).reduce(0, +) / n,
            meanRed: avgR, meanGreen: avgG, meanBlue: avgB,
            dominantCast: cast,
            suggestedTempOffset: avgTemp,
            suggestedTintOffset: avgTint,
            averageSaturation: profiles.map(\.averageSaturation).reduce(0, +) / n
        )
    }

    /// Trích xuất nhanh khung hình ngầm (headless) từ tệp media video tại thời điểm time
    public func extractFrame(from assetURL: URL, at time: CMTime) async -> CIImage? {
        let asset = AVURLAsset(url: assetURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        let tolerance = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return CIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

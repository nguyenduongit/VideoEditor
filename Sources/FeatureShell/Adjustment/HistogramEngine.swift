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
    public func analyzeTelemetry(from image: CIImage) -> ColorTelemetryProfile {
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

        var sumR: Double = 0
        var sumG: Double = 0
        var sumB: Double = 0
        var sumL: Double = 0
        var lCounts = [Int](repeating: 0, count: 256)

        let totalPixels = sampleWidth * sampleHeight
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Double(pixelData[offset])
            let g = Double(pixelData[offset + 1])
            let b = Double(pixelData[offset + 2])
            let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

            sumR += r
            sumG += g
            sumB += b
            sumL += lum
            lCounts[min(255, Int(lum))] += 1
        }

        let meanR = Float((sumR / Double(totalPixels)) / 255.0)
        let meanG = Float((sumG / Double(totalPixels)) / 255.0)
        let meanBlue = Float((sumB / Double(totalPixels)) / 255.0)
        let avgLuma = Float((sumL / Double(totalPixels)) / 255.0)

        // Tính Black Point (5th percentile) và White Point (95th percentile)
        var cumulative = 0
        var p5: Float = 0.05
        var p95: Float = 0.95
        let p5Threshold = Int(Double(totalPixels) * 0.05)
        let p95Threshold = Int(Double(totalPixels) * 0.95)

        for (idx, count) in lCounts.enumerated() {
            cumulative += count
            if cumulative >= p5Threshold && p5 == 0.05 {
                p5 = Float(idx) / 255.0
            }
            if cumulative >= p95Threshold {
                p95 = Float(idx) / 255.0
                break
            }
        }

        let shadowClip = Float(lCounts[0...5].reduce(0, +)) / Float(totalPixels)
        let highlightClip = Float(lCounts[250...255].reduce(0, +)) / Float(totalPixels)

        let cast: String
        if meanR - meanBlue > 0.06 {
            cast = "warm"
        } else if meanBlue - meanR > 0.06 {
            cast = "cool"
        } else if meanG - (meanR + meanBlue) / 2.0 > 0.05 {
            cast = "green"
        } else if (meanR + meanBlue) / 2.0 - meanG > 0.05 {
            cast = "magenta"
        } else {
            cast = "neutral"
        }

        let suggestedTemp = max(-100.0, min(100.0, (meanBlue - meanR) * 150.0))
        let suggestedTint = max(-100.0, min(100.0, (((meanR + meanBlue) / 2.0) - meanG) * 150.0))

        return ColorTelemetryProfile(
            averageLuma: avgLuma,
            blackPoint: p5,
            whitePoint: p95,
            dynamicRange: max(0.0, p95 - p5),
            shadowClippingRatio: shadowClip,
            highlightClippingRatio: highlightClip,
            meanRed: meanR,
            meanGreen: meanG,
            meanBlue: meanBlue,
            dominantCast: cast,
            suggestedTempOffset: suggestedTemp,
            suggestedTintOffset: suggestedTint
        )
    }

    /// Trích xuất nhanh khung hình ngầm (headless) từ tệp media video tại thời điểm time
    public func extractFrame(from assetURL: URL, at time: CMTime) async -> CIImage? {
        let asset = AVURLAsset(url: assetURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .positiveInfinity

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return CIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

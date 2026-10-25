import Foundation

/// Báo cáo telemetry quang phổ đo đạc được từ một khung hình video (dành cho AI / MCP phân tích).
/// Tuân thủ quy tắc R2.3 (Domain thuần khiết) và R3.1 (File <= 300 dòng) của AGENTS.md.
public struct ColorTelemetryProfile: Codable, Equatable, Sendable {
    // 1. Phơi sáng & Độ sáng (Luma)
    public var averageLuma: Float           // Độ sáng trung bình (0.0 ... 1.0)
    public var blackPoint: Float            // Mức 5% tối nhất (0.0 ... 1.0)
    public var whitePoint: Float            // Mức 95% sáng nhất (0.0 ... 1.0)
    public var dynamicRange: Float          // Độ tương phản thực tế (whitePoint - blackPoint)
    public var shadowClippingRatio: Float   // Tỉ lệ % bị bết đen (< 2% IRE)
    public var highlightClippingRatio: Float// Tỉ lệ % bị cháy sáng (> 98% IRE)

    // 2. Cân bằng trắng & Ám màu (White Balance & Color Cast)
    public var meanRed: Float               // Giá trị đỏ trung bình (0.0 ... 1.0)
    public var meanGreen: Float             // Giá trị lục trung bình (0.0 ... 1.0)
    public var meanBlue: Float              // Giá trị lam trung bình (0.0 ... 1.0)
    public var dominantCast: String         // Nhận diện ám màu: "neutral", "warm", "cool", "green", "magenta"
    public var suggestedTempOffset: Float   // Gợi ý bù trừ nhiệt độ (-100 ... +100)
    public var suggestedTintOffset: Float   // Gợi ý bù trừ sắc thái (-100 ... +100)

    public init(
        averageLuma: Float = 0.5,
        blackPoint: Float = 0.05,
        whitePoint: Float = 0.95,
        dynamicRange: Float = 0.90,
        shadowClippingRatio: Float = 0.0,
        highlightClippingRatio: Float = 0.0,
        meanRed: Float = 0.5,
        meanGreen: Float = 0.5,
        meanBlue: Float = 0.5,
        dominantCast: String = "neutral",
        suggestedTempOffset: Float = 0.0,
        suggestedTintOffset: Float = 0.0
    ) {
        self.averageLuma = averageLuma
        self.blackPoint = blackPoint
        self.whitePoint = whitePoint
        self.dynamicRange = dynamicRange
        self.shadowClippingRatio = shadowClippingRatio
        self.highlightClippingRatio = highlightClippingRatio
        self.meanRed = meanRed
        self.meanGreen = meanGreen
        self.meanBlue = meanBlue
        self.dominantCast = dominantCast
        self.suggestedTempOffset = suggestedTempOffset
        self.suggestedTintOffset = suggestedTintOffset
    }
}

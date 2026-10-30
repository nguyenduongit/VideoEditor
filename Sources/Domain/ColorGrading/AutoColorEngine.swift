import Foundation

/// Phong cách chỉnh màu tự động.
/// - `neutral`: Cân bằng trung tính chuẩn xác (khôi phục điểm đen/trắng, sửa ám màu đối xứng, không ép bạc vùng tối).
/// - `softAndAiry`: Sau khi cân bằng trung tính, pha thêm lớp nâng sáng thoáng và mở nhẹ vùng tối.
public enum AutoColorStyle: String, Codable, Equatable, Sendable {
    case neutral
    case softAndAiry
}

/// Kết quả tính toán thông số chỉnh màu tự động từ phân tích quang phổ khung hình.
/// Tuân thủ AGENTS.md R2.3 (Domain 100% thuần khiết, chỉ import Foundation).
public struct AutoColorAdjustmentResult: Codable, Equatable, Sendable {
    public var basic: BasicGradingParameters
    public var sharpenAmount: Float

    public init(basic: BasicGradingParameters = BasicGradingParameters(), sharpenAmount: Float = 6.0) {
        self.basic = basic
        self.sharpenAmount = sharpenAmount
    }
}

/// Engine tính toán thông số chỉnh màu tự động 2 bước dựa trên chỉ số quang phổ `ColorTelemetryProfile`.
/// Tuân thủ AGENTS.md R2.3 (Domain 100% thuần khiết) và R3.1.
public struct AutoColorEngine: Sendable {
    public init() {}

    /// Tính toán bộ thông số chỉnh màu theo quy trình 2 bước:
    /// 1. Cân bằng trung tính (Neutral Correction) dựa trên quang phổ thực tế.
    /// 2. Pha trộn phong cách (Style Look) theo `style` và `intensity` (0.0 ... 1.0).
    public func computeAdjustment(
        from telemetry: ColorTelemetryProfile,
        style: AutoColorStyle = .neutral,
        intensity: Float = 1.0
    ) -> AutoColorAdjustmentResult {
        let clampedIntensity = max(0.0, min(1.0, Double(intensity)))
        let neutral = computeNeutralCorrection(from: telemetry)

        let finalBasic: BasicGradingParameters
        switch style {
        case .neutral:
            finalBasic = scaleParameters(neutral, by: clampedIntensity)
        case .softAndAiry:
            let airy = applySoftAndAiryLook(to: neutral, telemetry: telemetry)
            finalBasic = scaleParameters(airy, by: clampedIntensity)
        }

        let sharpen = Float((4.0 * clampedIntensity).rounded())
        return AutoColorAdjustmentResult(basic: finalBasic, sharpenAmount: sharpen)
    }

    // MARK: - Bước 1: Cân bằng trung tính (Neutral Correction)

    private func computeNeutralCorrection(from t: ColorTelemetryProfile) -> BasicGradingParameters {
        let exposure = resolveNeutralExposure(luma: Double(t.averageLuma), highlightClip: Double(t.highlightClippingRatio))
        let (shadow, black) = resolveNeutralShadowAndBlack(
            luma: Double(t.averageLuma),
            blackPoint: Double(t.blackPoint),
            shadowClip: Double(t.shadowClippingRatio)
        )
        let (highlight, white) = resolveNeutralHighlightAndWhite(
            whitePoint: Double(t.whitePoint),
            highlightClip: Double(t.highlightClippingRatio)
        )
        let contrast = resolveNeutralContrast(dynamicRange: Double(t.dynamicRange))
        let (temp, tint) = resolveNeutralWhiteBalance(
            suggestedTemp: Double(t.suggestedTempOffset),
            suggestedTint: Double(t.suggestedTintOffset)
        )
        let (saturation, brilliance) = resolveNeutralColorfulness(averageSaturation: Double(t.averageSaturation))

        return BasicGradingParameters(
            temp: Float(temp),
            tint: Float(tint),
            saturation: Float(saturation),
            exposure: Float(exposure),
            contrast: Float(contrast),
            highlight: Float(highlight),
            shadow: Float(shadow),
            white: Float(white),
            black: Float(black),
            brilliance: Float(brilliance)
        )
    }

    private func resolveNeutralExposure(luma: Double, highlightClip: Double) -> Int {
        if luma > 0.62 || highlightClip > 0.06 {
            let pull = (0.55 - luma) * 28.0 - (highlightClip * 30.0)
            return Int(max(-16.0, min(-1.0, pull.rounded())))
        } else if luma < 0.44 {
            let push = (0.48 - luma) * 38.0
            return Int(max(1.0, min(16.0, push.rounded())))
        }
        return 0
    }

    private func resolveNeutralShadowAndBlack(
        luma: Double,
        blackPoint: Double,
        shadowClip: Double
    ) -> (Int, Int) {
        // Shadow: chỉ nâng khi vùng tối bị bết hoặc thiếu sáng tổng thể
        var shadow = 0
        if shadowClip > 0.02 || luma < 0.42 {
            let clipLift = shadowClip * 110.0
            let lumaLift = max(0.0, (0.44 - luma) * 45.0)
            shadow = Int(max(4.0, min(30.0, (clipLift + lumaLift).rounded())))
        }

        // Black point: chuẩn tự nhiên nằm ở khoảng 0.03 ... 0.08
        let black: Int
        if blackPoint < 0.02 || shadowClip > 0.04 {
            let lift = (0.04 - blackPoint) * 260.0 + shadowClip * 60.0
            black = Int(max(4.0, min(18.0, lift.rounded())))
        } else if blackPoint > 0.12 {
            // Khung hình bị bạc / mờ sương -> hạ điểm đen để lấy lại chiều sâu
            let Dehaze = (0.08 - blackPoint) * 90.0
            black = Int(max(-15.0, min(-2.0, Dehaze.rounded())))
        } else {
            black = 0
        }

        return (shadow, black)
    }

    private func resolveNeutralHighlightAndWhite(whitePoint: Double, highlightClip: Double) -> (Int, Int) {
        var highlight = 0
        if highlightClip > 0.03 || whitePoint > 0.95 {
            let pull = 4.0 + highlightClip * 85.0 + max(0.0, whitePoint - 0.94) * 80.0
            highlight = -Int(max(2.0, min(20.0, pull.rounded())))
        }

        var white = 0
        if whitePoint < 0.78 && highlightClip < 0.01 {
            let boost = (0.85 - whitePoint) * 40.0
            white = Int(max(2.0, min(12.0, boost.rounded())))
        }

        return (highlight, white)
    }

    private func resolveNeutralContrast(dynamicRange: Double) -> Int {
        if dynamicRange < 0.65 {
            let boost = (0.75 - dynamicRange) * 28.0
            return Int(max(3.0, min(10.0, boost.rounded())))
        } else if dynamicRange > 0.93 {
            return -3
        }
        return 0
    }

    private func resolveNeutralWhiteBalance(suggestedTemp: Double, suggestedTint: Double) -> (Int, Int) {
        // Đối xứng hoàn toàn, không cộng độ lệch cố định; vùng chết (deadzone) nhỏ để tránh nhiễu
        let temp: Int
        if abs(suggestedTemp) < 4.0 {
            temp = 0
        } else {
            temp = Int(max(-25.0, min(25.0, (suggestedTemp * 0.45).rounded())))
        }

        let tint: Int
        if abs(suggestedTint) < 4.0 {
            tint = 0
        } else {
            tint = Int(max(-15.0, min(15.0, (suggestedTint * 0.35).rounded())))
        }
        return (temp, tint)
    }

    private func resolveNeutralColorfulness(averageSaturation: Double) -> (Int, Int) {
        if averageSaturation < 0.16 {
            return (5, 6)
        } else if averageSaturation < 0.23 {
            return (2, 3)
        } else if averageSaturation > 0.45 {
            return (-4, -2)
        }
        return (0, 0)
    }

    // MARK: - Bước 2: Pha trộn phong cách (Style Look)

    private func applySoftAndAiryLook(
        to base: BasicGradingParameters,
        telemetry: ColorTelemetryProfile
    ) -> BasicGradingParameters {
        var result = base
        if telemetry.averageLuma <= 0.70 {
            result.exposure = min(16.0, base.exposure + 3.0)
        }
        result.shadow = min(40.0, max(base.shadow + 14.0, 18.0))
        result.black = min(24.0, max(base.black + 10.0, 10.0))
        result.contrast = max(-4.0, min(6.0, base.contrast + 2.0))
        return result
    }

    private func scaleParameters(_ params: BasicGradingParameters, by factor: Double) -> BasicGradingParameters {
        guard factor < 0.999 else { return params }
        func scale(_ v: Float) -> Float { Float((Double(v) * factor).rounded()) }
        return BasicGradingParameters(
            temp: scale(params.temp),
            tint: scale(params.tint),
            saturation: scale(params.saturation),
            exposure: scale(params.exposure),
            contrast: scale(params.contrast),
            highlight: scale(params.highlight),
            shadow: scale(params.shadow),
            white: scale(params.white),
            black: scale(params.black),
            brilliance: scale(params.brilliance)
        )
    }
}

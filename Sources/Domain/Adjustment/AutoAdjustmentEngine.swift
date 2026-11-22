import Foundation

/// Phong cách cân chỉnh màu tự động.
/// - `neutral`: Cân bằng tự động chuẩn phong cách Trong Trẻo & Sáng Thoáng (Clean Airy Daylight & Natural Skin/Foliage).
/// - `softAndAiry`: Tăng cường thêm độ mở vùng tối và độ mềm mại vùng trung.
public enum AutoAdjustmentStyle: String, Codable, Equatable, Sendable {
    case neutral
    case softAndAiry
}

/// Tương thích ngược với tên gọi cũ
public typealias AutoColorStyle = AutoAdjustmentStyle

/// Kết quả tính toán thông số cân chỉnh tự động từ phân tích quang phổ khung hình.
/// Tuân thủ AGENTS.md (Domain 100% thuần khiết, chỉ import Foundation).
public struct AutoAdjustmentResult: Codable, Equatable, Sendable {
    public var basic: BasicGradingParameters
    public var hsl: HSLAdjustments
    public var sharpenAmount: Float

    public init(
        basic: BasicGradingParameters = BasicGradingParameters(),
        hsl: HSLAdjustments = HSLAdjustments(),
        sharpenAmount: Float = 6.0
    ) {
        self.basic = basic
        self.hsl = hsl
        self.sharpenAmount = sharpenAmount
    }
}

/// Tương thích ngược với tên gọi cũ
public typealias AutoColorAdjustmentResult = AutoAdjustmentResult

/// Engine tính toán thông số cân chỉnh tự động vòng kín (Closed-Loop Telemetry Convergence) dựa trên `ColorTelemetryProfile`.
/// Tự động hội tụ quang phổ của mọi clip về phong cách Sáng Thoáng, Trắng Trong & Tự Nhiên (Clean Airy Daylight):
/// - Khử độ ám vàng/đỏ đục dư thừa để sắc trắng tinh khiết, giữ độ ấm nhẹ tự nhiên cho tông da (`R - B ~ +0.045`).
/// - Nâng sáng thoáng đãng (`Luma ~ 0.61`), mở rõ chi tiết vùng tối (`Shadow` & `Black` lift) và kìm vùng sáng (`Highlight < 0`) chống cháy bầu trời/áo trắng.
/// - Làm dịu độ gắt màu (`Saturation`) kết hợp làm sạch tông da và lá cây qua `HSL`.
/// Tuân thủ AGENTS.md (Domain thuần khiết, 1 File = 1 Primary Type, Hàm <= 50 dòng).
public struct AutoAdjustmentEngine: Sendable {
    public init() {}

    public func computeAdjustment(
        from telemetry: ColorTelemetryProfile,
        style: AutoAdjustmentStyle = .neutral,
        intensity: Float = 1.0
    ) -> AutoAdjustmentResult {
        let clampedIntensity = max(0.0, min(1.0, Double(intensity)))
        let baseBasic = computeAdaptiveBasic(from: telemetry)
        let baseHSL = computeAdaptiveHSL(from: telemetry, resolvedTemp: baseBasic.temp)

        let finalBasic: BasicGradingParameters
        switch style {
        case .neutral:
            finalBasic = scaleBasic(baseBasic, by: clampedIntensity)
        case .softAndAiry:
            let airy = applyExtraAiryBoost(to: baseBasic, telemetry: telemetry)
            finalBasic = scaleBasic(airy, by: clampedIntensity)
        }

        let finalHSL = scaleHSL(baseHSL, by: clampedIntensity)
        let sharpen = Float((5.0 * clampedIntensity).rounded())
        return AutoAdjustmentResult(basic: finalBasic, hsl: finalHSL, sharpenAmount: sharpen)
    }

    // MARK: - Bước 1: Hội tụ Quang phổ Thích ứng (Closed-Loop Adaptive Basic)

    private func computeAdaptiveBasic(from t: ColorTelemetryProfile) -> BasicGradingParameters {
        let luma = Double(t.averageLuma)
        let blackPoint = Double(t.blackPoint)
        let whitePoint = Double(t.whitePoint)
        let shadowClip = Double(t.shadowClippingRatio)
        let highlightClip = Double(t.highlightClippingRatio)

        let exposure = resolveAdaptiveExposure(luma: luma, highlightClip: highlightClip)
        let (shadow, black) = resolveAdaptiveShadowAndBlack(
            luma: luma,
            blackPoint: blackPoint,
            shadowClip: shadowClip
        )
        let (highlight, white) = resolveAdaptiveHighlightAndWhite(
            whitePoint: whitePoint,
            highlightClip: highlightClip,
            exposure: exposure
        )
        let contrast = resolveAdaptiveContrast(dynamicRange: Double(t.dynamicRange), luma: luma)
        let (temp, tint) = resolveAdaptiveWhiteBalance(from: t)
        let (saturation, brilliance) = resolveAdaptiveColorfulness(
            averageSaturation: Double(t.averageSaturation),
            luma: luma
        )

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

    private func resolveAdaptiveExposure(luma: Double, highlightClip: Double) -> Int {
        let targetLuma = 0.615
        if luma > 0.66 || highlightClip > 0.12 {
            let pull = (0.62 - luma) * 32.0 - (highlightClip * 24.0)
            return Int(max(-16.0, min(-1.0, pull.rounded())))
        } else if luma < targetLuma {
            let deficit = targetLuma - luma
            let clipDamp = max(0.35, 1.0 - highlightClip * 5.0)
            let push = deficit * 110.0 * clipDamp
            return Int(max(1.0, min(18.0, push.rounded())))
        }
        return 0
    }

    private func resolveAdaptiveShadowAndBlack(
        luma: Double,
        blackPoint: Double,
        shadowClip: Double
    ) -> (Int, Int) {
        let targetBlackPoint = 0.285
        let bpDeficit = max(0.0, targetBlackPoint - blackPoint)
        let lumaDeficit = max(0.0, 0.61 - luma)

        var shadow = 0
        if bpDeficit > 0.005 || lumaDeficit > 0.01 || shadowClip > 0.01 {
            let rawShadow = bpDeficit * 210.0 + lumaDeficit * 85.0 + shadowClip * 95.0
            shadow = Int(max(4.0, min(36.0, rawShadow.rounded())))
        }

        let black: Int
        if luma > 0.72 && blackPoint > 0.12 {
            let dehaze = (0.08 - blackPoint) * 75.0
            black = Int(max(-12.0, min(-2.0, dehaze.rounded())))
        } else if blackPoint < 0.275 || shadowClip > 0.02 {
            let lift = (0.275 - min(0.275, blackPoint)) * 190.0 + shadowClip * 45.0
            black = Int(max(3.0, min(20.0, lift.rounded())))
        } else if blackPoint > 0.34 {
            let dehaze = (0.30 - blackPoint) * 75.0
            black = Int(max(-12.0, min(-2.0, dehaze.rounded())))
        } else {
            black = 0
        }
        return (shadow, black)
    }

    private func resolveAdaptiveHighlightAndWhite(
        whitePoint: Double,
        highlightClip: Double,
        exposure: Int
    ) -> (Int, Int) {
        var highlight = 0
        let wpExcess = max(0.0, whitePoint - 0.88)
        let expComp = max(0.0, Double(exposure)) * 0.60
        if wpExcess > 0.01 || highlightClip > 0.01 || expComp > 0.5 {
            let pull = wpExcess * 75.0 + highlightClip * 85.0 + expComp
            highlight = -Int(max(3.0, min(24.0, pull.rounded())))
        }

        var white = 0
        if whitePoint < 0.85 && highlightClip < 0.01 {
            let boost = (0.92 - whitePoint) * 38.0
            white = Int(max(3.0, min(12.0, boost.rounded())))
        } else if highlight < -4 {
            white = 4
        }
        return (highlight, white)
    }

    private func resolveAdaptiveContrast(dynamicRange: Double, luma: Double) -> Int {
        if dynamicRange < 0.58 {
            let boost = (0.68 - dynamicRange) * 26.0
            return Int(max(2.0, min(10.0, boost.rounded())))
        } else if dynamicRange > 0.88 && luma > 0.50 {
            return -2
        }
        return 0
    }

    private func resolveAdaptiveWhiteBalance(from t: ColorTelemetryProfile) -> (Int, Int) {
        let warmth = Double(t.meanRed - t.meanBlue)
        let suggestedTemp = Double(t.suggestedTempOffset)
        let suggestedTint = Double(t.suggestedTintOffset)
        let targetWarmth = 0.032

        let temp: Int
        if warmth > targetWarmth + 0.012 || suggestedTemp < -4.0 {
            let excess = max(warmth - targetWarmth, -suggestedTemp / 180.0)
            temp = -Int(max(2.0, min(28.0, (excess * 225.0).rounded())))
        } else if warmth < -0.015 || suggestedTemp > 4.0 {
            let coolExcess = max(-warmth, suggestedTemp / 160.0)
            temp = Int(max(2.0, min(24.0, (coolExcess * 175.0).rounded())))
        } else {
            temp = 0
        }

        let tint: Int
        if abs(suggestedTint) >= 3.5 {
            tint = Int(max(-15.0, min(15.0, (suggestedTint * 0.45).rounded())))
        } else if temp <= -10 {
            tint = -3
        } else {
            tint = 0
        }
        return (temp, tint)
    }

    private func resolveAdaptiveColorfulness(averageSaturation: Double, luma: Double) -> (Int, Int) {
        let saturation: Int
        if averageSaturation > 0.23 {
            let calm = (averageSaturation - 0.22) * 130.0
            saturation = -Int(max(2.0, min(16.0, calm.rounded())))
        } else if averageSaturation < 0.17 {
            let boost = (0.21 - averageSaturation) * 85.0
            saturation = Int(max(2.0, min(12.0, boost.rounded())))
        } else {
            saturation = 0
        }

        let lumaDeficit = max(0.0, 0.63 - luma)
        let brilliance = Int(max(3.0, min(14.0, (lumaDeficit * 82.0).rounded())))
        return (saturation, brilliance)
    }

    // MARK: - Bước 2: Tinh chỉnh HSL Thích ứng

    private func computeAdaptiveHSL(from t: ColorTelemetryProfile, resolvedTemp: Float) -> HSLAdjustments {
        var hsl = HSLAdjustments()
        if resolvedTemp <= -6.0 || (t.meanRed - t.meanBlue) > 0.06 {
            hsl.orange = HSLChannel(hue: 0, saturation: -4, luminance: 6)
            hsl.yellow = HSLChannel(hue: 6, saturation: -8, luminance: 5)
            hsl.green = HSLChannel(hue: 4, saturation: 0, luminance: 4)
        }
        return hsl
    }

    private func applyExtraAiryBoost(
        to base: BasicGradingParameters,
        telemetry: ColorTelemetryProfile
    ) -> BasicGradingParameters {
        var result = base
        if telemetry.averageLuma <= 0.70 {
            result.exposure = min(18.0, base.exposure + 3.0)
        }
        result.shadow = min(40.0, max(base.shadow + 8.0, 18.0))
        result.black = min(24.0, max(base.black + 5.0, 10.0))
        return result
    }

    private func scaleBasic(_ params: BasicGradingParameters, by factor: Double) -> BasicGradingParameters {
        guard factor < 0.999 else { return params }
        func s(_ v: Float) -> Float { Float((Double(v) * factor).rounded()) }
        return BasicGradingParameters(
            temp: s(params.temp), tint: s(params.tint), saturation: s(params.saturation),
            exposure: s(params.exposure), contrast: s(params.contrast), highlight: s(params.highlight),
            shadow: s(params.shadow), white: s(params.white), black: s(params.black), brilliance: s(params.brilliance)
        )
    }

    private func scaleHSL(_ hsl: HSLAdjustments, by factor: Double) -> HSLAdjustments {
        guard factor < 0.999, !hsl.isNeutral else { return hsl }
        func sc(_ ch: HSLChannel) -> HSLChannel {
            HSLChannel(
                hue: Float((Double(ch.hue) * factor).rounded()),
                saturation: Float((Double(ch.saturation) * factor).rounded()),
                luminance: Float((Double(ch.luminance) * factor).rounded())
            )
        }
        var out = hsl
        for i in 0..<8 { out[i] = sc(out[i]) }
        return out
    }
}

/// Tương thích ngược với tên gọi cũ
public typealias AutoColorEngine = AutoAdjustmentEngine

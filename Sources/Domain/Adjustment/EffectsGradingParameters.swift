import Foundation

/// Cấu hình các hiệu ứng chất liệu: Tối 4 góc (Vignette), Hạt phim (Film Grain), Sắc nét (Sharpen)
public struct EffectsGradingParameters: Codable, Equatable, Sendable {
    // Vignette
    public var vignetteAmount: Float = 0.0     // -100.0 ... +100.0 (âm: làm sáng góc, dương: làm tối góc)
    public var vignetteMidpoint: Float = 50.0  // 0.0 ... 100.0 (bán kính vùng trung tâm)
    public var vignetteFeather: Float = 50.0   // 0.0 ... 100.0 (độ mờ chuyển tiếp)

    // Film Grain
    public var grainAmount: Float = 0.0        // 0.0 ... 100.0 (cường độ hạt)
    public var grainSize: Float = 50.0         // 0.0 ... 100.0 (kích cỡ hạt)

    // Sharpen
    public var sharpenAmount: Float = 0.0      // 0.0 ... 100.0 (độ sắc nét)

    public init(
        vignetteAmount: Float = 0.0,
        vignetteMidpoint: Float = 50.0,
        vignetteFeather: Float = 50.0,
        grainAmount: Float = 0.0,
        grainSize: Float = 50.0,
        sharpenAmount: Float = 0.0
    ) {
        self.vignetteAmount = vignetteAmount
        self.vignetteMidpoint = vignetteMidpoint
        self.vignetteFeather = vignetteFeather
        self.grainAmount = grainAmount
        self.grainSize = grainSize
        self.sharpenAmount = sharpenAmount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.vignetteAmount = (try? c.decodeIfPresent(Float.self, forKey: .vignetteAmount)) ?? 0.0
        self.vignetteMidpoint = (try? c.decodeIfPresent(Float.self, forKey: .vignetteMidpoint)) ?? 50.0
        self.vignetteFeather = (try? c.decodeIfPresent(Float.self, forKey: .vignetteFeather)) ?? 50.0
        self.grainAmount = (try? c.decodeIfPresent(Float.self, forKey: .grainAmount)) ?? 0.0
        self.grainSize = (try? c.decodeIfPresent(Float.self, forKey: .grainSize)) ?? 50.0
        self.sharpenAmount = (try? c.decodeIfPresent(Float.self, forKey: .sharpenAmount)) ?? 0.0
    }

    public var isNeutral: Bool {
        abs(vignetteAmount) < 0.001 &&
        abs(grainAmount) < 0.001 &&
        abs(sharpenAmount) < 0.001
    }
}

/// Cấu hình 3D LUT (Look-Up Table .cube)
public struct LUTConfiguration: Codable, Equatable, Sendable {
    public var lutName: String = ""              // Tên file .cube
    public var lutDataString: String = ""        // Dữ liệu text hoặc base64 của file .cube
    public var intensity: Float = 100.0          // Cường độ áp dụng (0.0 ... 100.0)
    public var isEnabled: Bool = false           // Bật/tắt LUT

    public init(
        lutName: String = "",
        lutDataString: String = "",
        intensity: Float = 100.0,
        isEnabled: Bool = false
    ) {
        self.lutName = lutName
        self.lutDataString = lutDataString
        self.intensity = intensity
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.lutName = (try? c.decodeIfPresent(String.self, forKey: .lutName)) ?? ""
        self.lutDataString = (try? c.decodeIfPresent(String.self, forKey: .lutDataString)) ?? ""
        self.intensity = (try? c.decodeIfPresent(Float.self, forKey: .intensity)) ?? 100.0
        self.isEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? false
    }

    public var isNeutral: Bool {
        !isEnabled || lutName.isEmpty || lutDataString.isEmpty || intensity < 0.001
    }
}

import Foundation

/// Cấu hình tham số và thuật toán động của một clip Hiệu ứng thị giác (Effect Layer).
/// Hỗ trợ cả 5 hiệu ứng cơ bản lẫn Gói Sáng Tạo Mở (`customParameters` + `filterPipeline` + `CIColorKernel`).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng).
public struct EffectConfiguration: Codable, Sendable, Equatable {
    public var type: EffectType
    public var intensity: Double
    public var speed: Double
    public var blurRadius: Double
    public var customParameters: [CustomParameterDescriptor]
    public var parameterValues: [String: Double]
    public var filterPipeline: [CreativeFilterStep]

    public init(
        type: EffectType = .fadeIn,
        intensity: Double = 1.0,
        speed: Double = 1.0,
        blurRadius: Double = 24.0,
        customParameters: [CustomParameterDescriptor] = [],
        parameterValues: [String: Double] = [:],
        filterPipeline: [CreativeFilterStep] = []
    ) {
        self.type = type
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        self.intensity = max(0.0, min(1.0, norm))
        self.speed = max(0.1, min(3.0, speed))
        self.blurRadius = max(1.0, min(100.0, blurRadius))
        self.customParameters = customParameters
        var mergedValues = parameterValues
        for param in customParameters where mergedValues[param.id] == nil {
            mergedValues[param.id] = param.defaultValue
        }
        self.parameterValues = mergedValues
        self.filterPipeline = filterPipeline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? container.decode(EffectType.self, forKey: .type)) ?? .fadeIn
        let rawIntensity = (try? container.decode(Double.self, forKey: .intensity)) ?? 1.0
        let norm = rawIntensity > 1.0 ? (rawIntensity / 100.0) : rawIntensity
        self.intensity = max(0.0, min(1.0, norm))
        self.speed = max(0.1, min(3.0, (try? container.decode(Double.self, forKey: .speed)) ?? 1.0))
        self.blurRadius = max(1.0, min(100.0, (try? container.decode(Double.self, forKey: .blurRadius)) ?? 24.0))
        let params = (try? container.decodeIfPresent([CustomParameterDescriptor].self, forKey: .customParameters)) ?? []
        self.customParameters = params
        var values = (try? container.decodeIfPresent([String: Double].self, forKey: .parameterValues)) ?? [:]
        for param in params where values[param.id] == nil {
            values[param.id] = param.defaultValue
        }
        self.parameterValues = values
        self.filterPipeline = (try? container.decodeIfPresent([CreativeFilterStep].self, forKey: .filterPipeline)) ?? []
    }

    /// Trả về giá trị hiện tại của một tham số tùy chỉnh (fallback về defaultValue của descriptor)
    public func value(forParameter id: String) -> Double {
        if let val = parameterValues[id] {
            return val
        }
        if let desc = customParameters.first(where: { $0.id == id }) {
            return desc.defaultValue
        }
        return 0.0
    }

    /// Cập nhật giá trị của một tham số tùy chỉnh (tự động giới hạn trong khoảng min...max của descriptor)
    public mutating func setValue(_ newValue: Double, forParameter id: String) {
        if let desc = customParameters.first(where: { $0.id == id }) {
            parameterValues[id] = max(desc.minValue, min(desc.maxValue, newValue))
        } else {
            parameterValues[id] = newValue
        }
    }

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> EffectConfiguration? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EffectConfiguration.self, from: data)
    }
}

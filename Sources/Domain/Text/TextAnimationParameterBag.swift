import Foundation

/// Dynamic numeric and string channel output evaluated from a `TextAnimationGraph`.
/// Unknown channels are preserved for modular `TextAnimationRenderPlugin` instances.
public struct TextAnimationParameterBag: Codable, Sendable, Equatable {
    public private(set) var values: [String: Double]
    public private(set) var stringValues: [String: String]

    public init(
        values: [String: Double] = [:],
        stringValues: [String: String] = [:]
    ) {
        self.values = values
        self.stringValues = stringValues
    }

    enum CodingKeys: String, CodingKey {
        case values
        case stringValues
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.values = try container.decodeIfPresent([String: Double].self, forKey: .values) ?? [:]
        self.stringValues = try container.decodeIfPresent([String: String].self, forKey: .stringValues) ?? [:]
    }

    public subscript(channel: String) -> Double? {
        values[channel]
    }

    public var channelNames: Set<String> {
        var names = Set(values.keys)
        for key in stringValues.keys { names.insert(key) }
        return names
    }

    public func stringValue(for channel: String) -> String? {
        stringValues[channel]
    }

    public mutating func setString(_ value: String, for channel: String) {
        guard !channel.isEmpty else { return }
        stringValues[channel] = value
    }

    public mutating func mergeStrings(_ additions: [String: String]) {
        for (channel, value) in additions where !channel.isEmpty {
            stringValues[channel] = value
        }
    }

    public func firstValue(forKeys keys: [String], default fallback: Double = 0.0) -> Double {
        for key in keys {
            if let found = values[key] { return found }
        }
        return fallback
    }

    public mutating func apply(
        _ value: Double,
        to channel: String,
        mode: TextAnimationBlendMode,
        weight: Double = 1.0
    ) {
        guard !channel.isEmpty, value.isFinite else { return }
        let w = min(1.0, max(0.0, weight))
        guard w > 0.0 else { return }

        let current = values[channel] ?? Self.defaultValue(for: channel)
        let result = Self.blend(current: current, incoming: value, mode: mode, weight: w)
        values[channel] = result.isFinite ? result : current
    }

    private static func blend(
        current: Double,
        incoming: Double,
        mode: TextAnimationBlendMode,
        weight w: Double
    ) -> Double {
        switch mode {
        case .replace: return current + (incoming - current) * w
        case .add: return current + incoming * w
        case .subtract: return current - incoming * w
        case .multiply: return current * (1.0 + (incoming - 1.0) * w)
        case .minimum: return min(current, current + (incoming - current) * w)
        case .maximum: return max(current, current + (incoming - current) * w)
        case .screen:
            let screened = 1.0 - (1.0 - current) * (1.0 - incoming)
            return current + (screened - current) * w
        }
    }

    private static func defaultValue(for channel: String) -> Double {
        switch channel {
        case "transform.scale.x", "transform.scale.y", "transform.scaleX", "transform.scaleY",
             "transform.opacity", "opacity", "mask.reveal.x", "mask.reveal.y", "path.trim.progress":
            return 1.0
        case "mask.reveal.linear", "effects.liquid.phase":
            return -1.0
        case "effects.dissolve.angle":
            return -0.75
        case "effects.meshWarp.frequency":
            return 1.5
        default:
            return 0.0
        }
    }
}

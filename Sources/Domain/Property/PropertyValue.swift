import Foundation

/// A type-safe polymorphic value representing a property of a clip.
/// Encodes to and decodes from natural JSON primitives (number, string, bool).
public enum PropertyValue: Sendable, Equatable, Hashable {
    case number(Double)
    case string(String)
    case bool(Bool)

    public var asNumber: Double? {
        if case .number(let val) = self { return val }
        return nil
    }

    public var asString: String? {
        if case .string(let val) = self { return val }
        return nil
    }

    public var asBool: Bool? {
        if case .bool(let val) = self { return val }
        return nil
    }
}

extension PropertyValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
            return
        }
        if let doubleVal = try? container.decode(Double.self) {
            self = .number(doubleVal)
            return
        }
        if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode PropertyValue from JSON value"
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let val):
            try container.encode(val)
        case .string(let val):
            try container.encode(val)
        case .bool(let val):
            try container.encode(val)
        }
    }
}

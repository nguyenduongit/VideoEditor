import Foundation

/// Normalized 2D transform pivot (`x: -1...1` horizontal, `y: -1...1` vertical)
/// with 100% backward-compatible Codable decoding for legacy `"Center"`, `"Top"`, `"Bottom"` strings.
public struct TextAnchorPoint: Codable, Hashable, Sendable, CaseIterable, Identifiable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = max(-1.0, min(1.0, x))
        self.y = max(-1.0, min(1.0, y))
    }

    public static let center = TextAnchorPoint(x: 0.0, y: 0.0)
    public static let bottom = TextAnchorPoint(x: 0.0, y: -1.0)
    public static let top = TextAnchorPoint(x: 0.0, y: 1.0)
    public static let leading = TextAnchorPoint(x: -1.0, y: 0.0)
    public static let trailing = TextAnchorPoint(x: 1.0, y: 0.0)
    public static let topLeading = TextAnchorPoint(x: -1.0, y: 1.0)
    public static let topTrailing = TextAnchorPoint(x: 1.0, y: 1.0)
    public static let bottomLeading = TextAnchorPoint(x: -1.0, y: -1.0)
    public static let bottomTrailing = TextAnchorPoint(x: 1.0, y: -1.0)

    public static let allCases: [TextAnchorPoint] = [
        .center, .bottom, .top, .leading, .trailing,
        .topLeading, .topTrailing, .bottomLeading, .bottomTrailing
    ]

    public var id: String { rawValue }

    public var rawValue: String {
        if let named = Self.namedPresets.first(where: {
            abs($0.anchor.x - x) < 0.001 && abs($0.anchor.y - y) < 0.001
        }) {
            return named.raw
        }
        return String(format: "%.3f,%.3f", x, y)
    }

    public var title: String { rawValue }

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        if let matched = Self.namedPresets.first(where: { $0.raw.lowercased() == normalized }) {
            self = matched.anchor
            return
        }
        switch normalized {
        case "left": self = .leading; return
        case "right": self = .trailing; return
        case "topleft", "top left": self = .topLeading; return
        case "topright", "top right": self = .topTrailing; return
        case "bottomleft", "bottom left": self = .bottomLeading; return
        case "bottomright", "bottom right": self = .bottomTrailing; return
        default: break
        }
        let parts = trimmed.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, parts[0].isFinite, parts[1].isFinite else { return nil }
        self.init(x: parts[0], y: parts[1])
    }

    private enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let raw = try? single.decode(String.self),
           let parsed = Self(rawValue: raw) {
            self = parsed
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedX = try container.decodeIfPresent(Double.self, forKey: .x) ?? 0.0
        let decodedY = try container.decodeIfPresent(Double.self, forKey: .y) ?? 0.0
        self.init(x: decodedX, y: decodedY)
    }

    public func encode(to encoder: Encoder) throws {
        if Self.namedPresets.contains(where: {
            abs($0.anchor.x - x) < 0.001 && abs($0.anchor.y - y) < 0.001
        }) {
            var single = encoder.singleValueContainer()
            try single.encode(rawValue)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }

    private static let namedPresets: [(raw: String, anchor: TextAnchorPoint)] = [
        ("Center", .center),
        ("Bottom", .bottom),
        ("Top", .top),
        ("Leading", .leading),
        ("Trailing", .trailing),
        ("Top Leading", .topLeading),
        ("Top Trailing", .topTrailing),
        ("Bottom Leading", .bottomLeading),
        ("Bottom Trailing", .bottomTrailing)
    ]
}

import Foundation

public struct TextStyleDescriptor: Codable, Sendable, Hashable, Equatable {
    public var fontSize: CGFloat
    public var textColorHex: String
    public var isBold: Bool
    public var isItalic: Bool

    public init(
        fontSize: CGFloat = 36,
        textColorHex: String = "#FFFFFF",
        isBold: Bool = false,
        isItalic: Bool = false
    ) {
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.isBold = isBold
        self.isItalic = isItalic
    }
}

/// Identifies the asset or programmatic generator backing a timeline clip block.
/// Serialized with an envelope structure `{ type, payload }` adhering to AGENTS.md rule R5.5.
public enum ClipSource: Codable, Sendable, Hashable, Equatable {
    case file(url: URL)
    case text(content: String, style: TextStyleDescriptor)
    case color(hex: String)
    case adjustment

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum SourceType: String, Codable {
        case file
        case text
        case color
        case adjustment
    }

    private struct FilePayload: Codable {
        let url: URL
    }

    private struct TextPayload: Codable {
        let content: String
        let style: TextStyleDescriptor
    }

    private struct ColorPayload: Codable {
        let hex: String
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SourceType.self, forKey: .type)
        switch type {
        case .file:
            let payload = try container.decode(FilePayload.self, forKey: .payload)
            self = .file(url: payload.url)
        case .text:
            let payload = try container.decode(TextPayload.self, forKey: .payload)
            self = .text(content: payload.content, style: payload.style)
        case .color:
            let payload = try container.decode(ColorPayload.self, forKey: .payload)
            self = .color(hex: payload.hex)
        case .adjustment:
            self = .adjustment
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let url):
            try container.encode(SourceType.file, forKey: .type)
            try container.encode(FilePayload(url: url), forKey: .payload)
        case .text(let content, let style):
            try container.encode(SourceType.text, forKey: .type)
            try container.encode(TextPayload(content: content, style: style), forKey: .payload)
        case .color(let hex):
            try container.encode(SourceType.color, forKey: .type)
            try container.encode(ColorPayload(hex: hex), forKey: .payload)
        case .adjustment:
            try container.encode(SourceType.adjustment, forKey: .type)
        }
    }
}

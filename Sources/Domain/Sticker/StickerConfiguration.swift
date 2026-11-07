import Foundation

/// Định dạng nguồn nhãn dán hỗ trợ Vector tĩnh sắc nét (`.svg`), ảnh tĩnh (`.png`), và hoạt họa đa khung hình (`.gif`, `.apng`).
public enum StickerFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case svg = "svg"
    case png = "png"
    case gif = "gif"
    case apng = "apng"

    public var id: String { rawValue }

    public var isAnimated: Bool {
        self == .gif || self == .apng
    }

    public var displayName: String {
        switch self {
        case .svg: return "Vector SVG"
        case .png: return "Ảnh PNG"
        case .gif: return "Ảnh động GIF"
        case .apng: return "Ảnh động APNG"
        }
    }
}

public enum StickerLoopMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case loop = "loop"
    case playOnce = "play_once"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .loop:
            return "Lặp vô tận (Loop)"
        case .playOnce:
            return "Chạy 1 lần (Once)"
        }
    }
}

/// Cấu hình thuộc tính lõi, đồ họa Vector SVG, hòa trộn, đổ bóng và hoạt ảnh `In / Out / Loop` của Sticker Clip.
/// Tuân thủ quy tắc R2.3 (thuần Domain), R3.1 (<= 300 dòng), và R5.5 (Serialization tương thích tiến/lùi) của AGENTS.md.
public struct StickerConfiguration: Codable, Sendable, Equatable {
    public var format: StickerFormat
    public var loopMode: StickerLoopMode
    public var playbackSpeed: Double
    public var flipHorizontal: Bool
    public var flipVertical: Bool
    public var sourceURLString: String?
    public var svgMarkup: String?
    public var systemSymbolFallback: String?
    public var blendMode: TextLayerBlendMode
    public var hasShadow: Bool
    public var shadowColorHex: String
    public var shadowBlur: Double
    public var shadowDistance: Double
    public var shadowAngleDegrees: Double
    public var animation: TextAnimationConfiguration

    public init(
        format: StickerFormat = .apng,
        loopMode: StickerLoopMode = .loop,
        playbackSpeed: Double = 1.0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        sourceURLString: String? = nil,
        svgMarkup: String? = nil,
        systemSymbolFallback: String? = "face.smiling",
        blendMode: TextLayerBlendMode = .normal,
        hasShadow: Bool = false,
        shadowColorHex: String = "#00000099",
        shadowBlur: Double = 8.0,
        shadowDistance: Double = 4.0,
        shadowAngleDegrees: Double = -45.0,
        animation: TextAnimationConfiguration = TextAnimationConfiguration()
    ) {
        self.format = format
        self.loopMode = loopMode
        self.playbackSpeed = max(0.25, min(4.0, playbackSpeed))
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.sourceURLString = sourceURLString
        self.svgMarkup = svgMarkup
        self.systemSymbolFallback = systemSymbolFallback
        self.blendMode = blendMode
        self.hasShadow = hasShadow
        self.shadowColorHex = shadowColorHex
        self.shadowBlur = max(0.0, min(50.0, shadowBlur))
        self.shadowDistance = max(0.0, min(80.0, shadowDistance))
        self.shadowAngleDegrees = max(-180.0, min(180.0, shadowAngleDegrees))
        self.animation = animation
    }

    private enum CodingKeys: String, CodingKey {
        case format, loopMode, playbackSpeed, flipHorizontal, flipVertical
        case sourceURLString, svgMarkup, systemSymbolFallback
        case blendMode, hasShadow, shadowColorHex, shadowBlur, shadowDistance, shadowAngleDegrees
        case animation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.format = (try? c.decodeIfPresent(StickerFormat.self, forKey: .format)) ?? .apng
        self.loopMode = (try? c.decodeIfPresent(StickerLoopMode.self, forKey: .loopMode)) ?? .loop
        let rawSpeed = (try? c.decodeIfPresent(Double.self, forKey: .playbackSpeed)) ?? 1.0
        self.playbackSpeed = max(0.25, min(4.0, rawSpeed))
        self.flipHorizontal = (try? c.decodeIfPresent(Bool.self, forKey: .flipHorizontal)) ?? false
        self.flipVertical = (try? c.decodeIfPresent(Bool.self, forKey: .flipVertical)) ?? false
        self.sourceURLString = try? c.decodeIfPresent(String.self, forKey: .sourceURLString)
        self.svgMarkup = try? c.decodeIfPresent(String.self, forKey: .svgMarkup)
        self.systemSymbolFallback = (try? c.decodeIfPresent(String.self, forKey: .systemSymbolFallback)) ?? "face.smiling"
        self.blendMode = (try? c.decodeIfPresent(TextLayerBlendMode.self, forKey: .blendMode)) ?? .normal
        self.hasShadow = (try? c.decodeIfPresent(Bool.self, forKey: .hasShadow)) ?? false
        self.shadowColorHex = (try? c.decodeIfPresent(String.self, forKey: .shadowColorHex)) ?? "#00000099"
        self.shadowBlur = max(0.0, min(50.0, (try? c.decodeIfPresent(Double.self, forKey: .shadowBlur)) ?? 8.0))
        self.shadowDistance = max(0.0, min(80.0, (try? c.decodeIfPresent(Double.self, forKey: .shadowDistance)) ?? 4.0))
        self.shadowAngleDegrees = max(-180.0, min(180.0, (try? c.decodeIfPresent(Double.self, forKey: .shadowAngleDegrees)) ?? -45.0))
        self.animation = (try? c.decodeIfPresent(TextAnimationConfiguration.self, forKey: .animation)) ?? TextAnimationConfiguration()
    }

    public var shadowOffsetX: Double {
        let rad = shadowAngleDegrees * .pi / 180.0
        return cos(rad) * shadowDistance
    }

    public var shadowOffsetY: Double {
        let rad = shadowAngleDegrees * .pi / 180.0
        return -sin(rad) * shadowDistance
    }

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> StickerConfiguration? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StickerConfiguration.self, from: data)
    }
}

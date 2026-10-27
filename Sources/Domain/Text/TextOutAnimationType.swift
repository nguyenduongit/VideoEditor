import Foundation

/// Nhóm danh mục phân loại cho hoạt ảnh Ra (Out Animation)
public enum TextOutAnimationCategory: String, CaseIterable, Sendable, Identifiable {
    case all = "Tất cả"
    case fadeSlide = "Mờ dần & Trượt thoát"
    case dissolveDrop = "Tan biến, Rơi & Co lại"
    case spinFlip = "Xoay, Lật & Đóng khung"
    case retroDigital = "Màn hình & Kỹ thuật số"

    public var id: String { rawValue }
}

/// Danh mục đầy đủ 19 hiệu ứng biến mất (Out Animation) chuyên nghiệp
public enum TextOutAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"

    // 1. Mờ dần & Trượt thoát (Fade & Slide Out)
    case fadeOut = "Fade Out"
    case zoomOut = "Zoom Out"
    case zoomInOut = "Zoom In Out"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"

    // 2. Tan biến, Rơi vỡ & Tiêu biến (Dissolve, Drop & Shrink)
    case dissolve = "Dissolve"
    case dropOut = "Drop Out"
    case shrink = "Shrink"
    case vaporize = "Vaporize"
    case shatter = "Shatter"

    // 3. Xoay, Lật & Đóng khung (Spin, Flip & Close)
    case spinOut = "Spin Out"
    case rollOut = "Roll Out"
    case flipOut = "Flip Out"
    case blinds = "Blinds"

    // 4. Hiệu ứng Màn hình & Tín hiệu (Retro & Digital)
    case tvOff = "TV Off"
    case glitchOut = "Glitch Out"
    case scanOut = "Scan Out"

    public var id: String { rawValue }

    public var category: TextOutAnimationCategory {
        switch self {
        case .none:
            return .all
        case .fadeOut, .zoomOut, .zoomInOut, .slideUp, .slideDown, .slideLeft, .slideRight:
            return .fadeSlide
        case .dissolve, .dropOut, .shrink, .vaporize, .shatter:
            return .dissolveDrop
        case .spinOut, .rollOut, .flipOut, .blinds:
            return .spinFlip
        case .tvOff, .glitchOut, .scanOut:
            return .retroDigital
        }
    }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .fadeOut: return "sun.min"
        case .zoomOut: return "minus.magnifyingglass"
        case .zoomInOut: return "plus.magnifyingglass"
        case .slideUp: return "arrow.up"
        case .slideDown: return "arrow.down"
        case .slideLeft: return "arrow.left"
        case .slideRight: return "arrow.right"
        case .dissolve: return "bubbles.and.sparkles"
        case .dropOut: return "arrow.down.to.line"
        case .shrink: return "arrow.down.right.and.arrow.up.left"
        case .vaporize: return "smoke.fill"
        case .shatter: return "scissors.badge.ellipsis"
        case .spinOut: return "rotate.right"
        case .rollOut: return "circle.dotted.and.circle"
        case .flipOut: return "rotate.3d"
        case .blinds: return "rectangle.split.3x1"
        case .tvOff: return "tv.slash"
        case .glitchOut: return "bolt.trianglebadge.exclamationmark"
        case .scanOut: return "barcode.viewfinder"
        }
    }
}

extension TextOutAnimationType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        guard let raw else {
            self = .none
            return
        }
        if let match = TextOutAnimationType(rawValue: raw) {
            self = match
            return
        }
        switch raw.lowercased() {
        case "blur out", "blurout": self = .dissolve
        case "whip out", "whippanright": self = .slideRight
        case "jelly snap", "elasticsnapout": self = .shrink
        case "shatter glitch", "shatterglitch": self = .shatter
        case "3d fold", "folddown3d": self = .flipOut
        case "fall down", "falldown": self = .dropOut
        case "mask sink", "masksink": self = .slideDown
        case "cinema squeeze", "trackingcollapse": self = .shrink
        case "glitch dissolve", "glitchdissolve": self = .glitchOut
        case "fly out top", "flyouttop": self = .slideUp
        case "fly out bottom", "flyoutbottom": self = .slideDown
        case "fly out left", "flyoutleft": self = .slideLeft
        case "fly out right", "flyoutright": self = .slideRight
        case "spiral fly", "spiralflyaway": self = .spinOut
        case "shockwave", "shockwaveblast": self = .dissolve
        case "pixel dissolve", "pixelatedissolve": self = .dissolve
        default: self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

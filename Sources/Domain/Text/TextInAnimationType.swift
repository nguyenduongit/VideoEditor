import Foundation

/// Nhóm danh mục phân loại cho hoạt ảnh Vào (In Animation)
public enum TextInAnimationCategory: String, CaseIterable, Sendable, Identifiable {
    case all = "Tất cả"
    case basicMotion = "Cơ bản & Mờ dần"
    case typewriterDrawing = "Đánh máy & Bút vẽ"
    case bounceSpring = "Nảy, Rơi & Lò xo"
    case flipSpin = "Lật & Xoay 3D"
    case glitchCinematic = "Kỹ thuật số & Glitch"

    public var id: String { rawValue }
}

/// Danh mục đầy đủ 30 hiệu ứng xuất hiện (In Animation) chuyên nghiệp
public enum TextInAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"

    // 1. Chuyển động cơ bản & Mờ dần (Basic & Motion)
    case fadeIn = "Fade In"
    case zoomIn = "Zoom In"
    case zoomOutIn = "Zoom Out In"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case moveIn = "Move In"
    case wipe = "Wipe"

    // 2. Hiệu ứng Đánh máy & Bút vẽ (Typewriter & Drawing)
    case typewriter1 = "Typewriter I"
    case typewriter2 = "Typewriter II"
    case handwriting = "Handwriting"
    case inkSplash = "Ink Splash"
    case chalk = "Chalk"

    // 3. Nảy, Rơi & Trọng lực (Bounce, Drop & Spring)
    case drop = "Drop"
    case bounce = "Bounce"
    case pendulum = "Pendulum"
    case wobble = "Wobble"

    // 4. Lật & Xoay 3D (Flip & Spin)
    case flipHorizontal = "Flip Horizontal"
    case flipVertical = "Flip Vertical"
    case flip3D = "3D Flip"
    case spinIn = "Spin In"
    case rollIn = "Roll In"
    case pageTurn = "Page Turn"

    // 5. Kỹ thuật số, Glitch & Hiện đại (Glitch & Cinematic)
    case glitch = "Glitch"
    case pixelate = "Pixelate"
    case blurIn = "Blur In"
    case lightStreak = "Light Streak"
    case unfold = "Unfold"
    case cascade = "Cascade"

    public var id: String { rawValue }

    public var category: TextInAnimationCategory {
        switch self {
        case .none:
            return .all
        case .fadeIn, .zoomIn, .zoomOutIn, .slideUp, .slideDown, .slideLeft, .slideRight, .moveIn, .wipe:
            return .basicMotion
        case .typewriter1, .typewriter2, .handwriting, .inkSplash, .chalk:
            return .typewriterDrawing
        case .drop, .bounce, .pendulum, .wobble:
            return .bounceSpring
        case .flipHorizontal, .flipVertical, .flip3D, .spinIn, .rollIn, .pageTurn:
            return .flipSpin
        case .glitch, .pixelate, .blurIn, .lightStreak, .unfold, .cascade:
            return .glitchCinematic
        }
    }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .fadeIn: return "sun.max"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOutIn: return "minus.magnifyingglass"
        case .slideUp: return "arrow.up"
        case .slideDown: return "arrow.down"
        case .slideLeft: return "arrow.left"
        case .slideRight: return "arrow.right"
        case .moveIn: return "arrow.right.to.line"
        case .wipe: return "paintbrush.pointed"
        case .typewriter1: return "keyboard"
        case .typewriter2: return "keyboard.badge.ellipsis"
        case .handwriting: return "pencil.and.scribble"
        case .inkSplash: return "drop.fill"
        case .chalk: return "scribble"
        case .drop: return "arrow.down.to.line"
        case .bounce: return "figure.run"
        case .pendulum: return "metronome"
        case .wobble: return "waveform.path"
        case .flipHorizontal: return "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .flipVertical: return "arrow.up.and.down.righttriangle.up.righttriangle.down"
        case .flip3D: return "rotate.3d"
        case .spinIn: return "rotate.right"
        case .rollIn: return "circle.dotted.and.circle"
        case .pageTurn: return "book.pages"
        case .glitch: return "bolt.badge.clock"
        case .pixelate: return "square.grid.3x3.fill"
        case .blurIn: return "aqi.medium"
        case .lightStreak: return "sparkles"
        case .unfold: return "rectangle.expand.vertical"
        case .cascade: return "water.waves"
        }
    }
}

extension TextInAnimationType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        guard let raw else {
            self = .none
            return
        }
        if let match = TextInAnimationType(rawValue: raw) {
            self = match
            return
        }
        // Backward-compatibility mapping for legacy names
        switch raw.lowercased() {
        case "typewriter": self = .typewriter1
        case "jelly pop", "elasticjellyin": self = .bounce
        case "pop bounce", "spring drop", "wave bounce": self = .bounce
        case "whip pan", "whippanleft": self = .moveIn
        case "glitch slice", "glitchslicein": self = .glitch
        case "3d unfold", "origamiunfold": self = .unfold
        case "swoosh drop", "swooshdrop": self = .drop
        case "crash fall", "crashbounce": self = .drop
        case "3d flip x", "flipx3d": self = .flipVertical
        case "shockwave", "shockwaveblast": self = .lightStreak
        case "neon flicker", "neonflicker": self = .glitch
        case "vortex spin", "vortexspin": self = .spinIn
        case "mask reveal", "maskreveal": self = .wipe
        case "cinema expand", "trackingexpand": self = .zoomIn
        default: self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

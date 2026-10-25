import Foundation

/// Danh mục đường cong gia tốc chuyển động (Motion Easing)
public enum TextMotionEasing: String, Codable, Sendable, CaseIterable, Identifiable {
    case smooth = "Smooth"
    case spring = "Spring"
    case bounce = "Bounce"
    case elastic = "Elastic"

    public var id: String { rawValue }
}

/// Danh mục hiệu ứng xuất hiện (In Animation) cho Text Clip
public enum TextInAnimationType: String, Codable, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case typewriter = "Typewriter"
    case fadeIn = "Fade In"
    case zoomIn = "Zoom In"
    case blurIn = "Blur In"
    case popBounce = "Pop Bounce"
    case elasticJellyIn = "Jelly Pop"
    case whipPanLeft = "Whip Pan"
    case glitchSliceIn = "Glitch Slice"
    case origamiUnfold = "3D Unfold"
    case swooshDrop = "Swoosh Drop"
    case waveBounce = "Wave Bounce"
    case springDrop = "Spring Drop"
    case maskReveal = "Mask Reveal"
    case trackingExpand = "Cinema Expand"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case flyInTop = "Fly In Top"
    case flyInBottom = "Fly In Bottom"
    case flyInLeft = "Fly In Left"
    case flyInRight = "Fly In Right"
    case vortexSpin = "Vortex Spin"
    case shockwaveBlast = "Shockwave"
    case crashBounce = "Crash Fall"
    case neonFlicker = "Neon Flicker"
    case flip3D = "3D Flip"
    case flipX3D = "3D Flip X"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .typewriter: return "keyboard"
        case .fadeIn: return "sun.max"
        case .zoomIn: return "plus.magnifyingglass"
        case .blurIn: return "aqi.medium"
        case .popBounce: return "sparkles"
        case .elasticJellyIn: return "circle.dotted.and.circle"
        case .whipPanLeft: return "wind"
        case .glitchSliceIn: return "scissors.badge.ellipsis"
        case .origamiUnfold: return "book.pages"
        case .swooshDrop: return "arrow.down.right.circle.fill"
        case .waveBounce: return "water.waves"
        case .springDrop: return "arrow.down.bounce"
        case .maskReveal: return "rectangle.and.hand.point.up.left"
        case .trackingExpand: return "arrow.left.and.right"
        case .slideUp: return "arrow.up"
        case .slideDown: return "arrow.down"
        case .slideLeft: return "arrow.left"
        case .slideRight: return "arrow.right"
        case .flyInTop: return "airplane.arrival"
        case .flyInBottom: return "arrow.up.to.line"
        case .flyInLeft: return "arrow.right.to.line"
        case .flyInRight: return "arrow.left.to.line"
        case .vortexSpin: return "tropicalstorm"
        case .shockwaveBlast: return "bolt.shield.fill"
        case .crashBounce: return "hammer"
        case .neonFlicker: return "lightbulb.slash"
        case .flip3D: return "rotate.3d"
        case .flipX3D: return "arrow.triangle.2.circlepath.doc.on.clipboard"
        }
    }
}

/// Danh mục hiệu ứng biến mất (Out Animation) cho Text Clip
public enum TextOutAnimationType: String, Codable, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case fadeOut = "Fade Out"
    case zoomOut = "Zoom Out"
    case blurOut = "Blur Out"
    case whipPanRight = "Whip Out"
    case elasticSnapOut = "Jelly Snap"
    case shatterGlitch = "Shatter Glitch"
    case foldDown3D = "3D Fold"
    case fallDown = "Fall Down"
    case maskSink = "Mask Sink"
    case trackingCollapse = "Cinema Squeeze"
    case glitchDissolve = "Glitch Dissolve"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case flyOutTop = "Fly Out Top"
    case flyOutBottom = "Fly Out Bottom"
    case flyOutLeft = "Fly Out Left"
    case flyOutRight = "Fly Out Right"
    case spiralFlyAway = "Spiral Fly"
    case shockwaveBlast = "Shockwave"
    case pixelateDissolve = "Pixel Dissolve"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .fadeOut: return "sun.min"
        case .zoomOut: return "minus.magnifyingglass"
        case .blurOut: return "aqi.low"
        case .whipPanRight: return "wind.snow"
        case .elasticSnapOut: return "arrow.up.and.down.circle"
        case .shatterGlitch: return "bolt.trianglebadge.exclamationmark"
        case .foldDown3D: return "rectangle.compress.vertical"
        case .fallDown: return "arrow.down.to.line"
        case .maskSink: return "rectangle.bottomhalf.filled"
        case .trackingCollapse: return "arrow.right.and.left"
        case .glitchDissolve: return "tornado"
        case .slideUp: return "arrow.up"
        case .slideDown: return "arrow.down"
        case .slideLeft: return "arrow.left"
        case .slideRight: return "arrow.right"
        case .flyOutTop: return "airplane.departure"
        case .flyOutBottom: return "arrow.down.to.line"
        case .flyOutLeft: return "arrow.left.to.line"
        case .flyOutRight: return "arrow.right.to.line"
        case .spiralFlyAway: return "hurricane"
        case .shockwaveBlast: return "flame"
        case .pixelateDissolve: return "bubbles.and.sparkles"
        }
    }
}

/// Danh mục hiệu ứng lặp liên tục (Loop Animation) cho Text Clip
public enum TextLoopAnimationType: String, Codable, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case lightSweep = "Light Sweep"
    case jellyWave = "Jelly Wave"
    case swing3D = "3D Pendulum"
    case liquidWave = "Liquid Wave"
    case pulse = "Pulse"
    case floating = "Floating"
    case wiggle = "Wiggle"
    case rainbow = "Rainbow"
    case glitch = "Glitch"
    case heartbeat = "Heartbeat"
    case neonPulse = "Neon Pulse"
    case earthquake = "Earthquake"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .lightSweep: return "wand.and.rays"
        case .jellyWave: return "waveform.circle.fill"
        case .swing3D: return "gyroscope"
        case .liquidWave: return "drop.degreesign.fill"
        case .pulse: return "waveform.path.ecg"
        case .floating: return "water.waves"
        case .wiggle: return "skew"
        case .rainbow: return "paintpalette"
        case .glitch: return "bolt.horizontal"
        case .heartbeat: return "heart.fill"
        case .neonPulse: return "lightbulb.fill"
        case .earthquake: return "waveform"
        }
    }
}

/// Cấu hình hoạt ảnh chuyển động toàn diện cho Text Clip
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, không UI) và R4.3 (đơn nhiệm).
public struct TextAnimationConfiguration: Codable, Sendable, Equatable {
    public var inType: TextInAnimationType
    public var inDuration: Double
    public var outType: TextOutAnimationType
    public var outDuration: Double
    public var loopType: TextLoopAnimationType
    public var loopSpeed: Double
    public var comboType: TextComboAnimationType
    public var scope: TextAnimationScope
    public var staggerDirection: TextStaggerDirection
    public var staggerDelay: Double
    public var anchorPoint: TextAnchorPoint
    public var rgbSplitIntensity: Double
    public var lightSweepIntensity: Double
    public var isMaskEnabled: Bool
    public var isMotionBlurEnabled: Bool
    public var isTypewriterCursorVisible: Bool
    public var highlightColorHex: String
    public var motionEasing: TextMotionEasing

    public init(
        inType: TextInAnimationType = .none,
        inDuration: Double = 0.5,
        outType: TextOutAnimationType = .none,
        outDuration: Double = 0.5,
        loopType: TextLoopAnimationType = .none,
        loopSpeed: Double = 1.0,
        comboType: TextComboAnimationType = .none,
        scope: TextAnimationScope = .wholeBlock,
        staggerDirection: TextStaggerDirection = .forward,
        staggerDelay: Double = 0.04,
        anchorPoint: TextAnchorPoint = .center,
        rgbSplitIntensity: Double = 0.0,
        lightSweepIntensity: Double = 0.0,
        isMaskEnabled: Bool = false,
        isMotionBlurEnabled: Bool = true,
        isTypewriterCursorVisible: Bool = true,
        highlightColorHex: String = "#FDE047",
        motionEasing: TextMotionEasing = .smooth
    ) {
        self.inType = inType
        self.inDuration = max(0.1, min(3.0, inDuration))
        self.outType = outType
        self.outDuration = max(0.1, min(3.0, outDuration))
        self.loopType = loopType
        self.loopSpeed = max(0.2, min(5.0, loopSpeed))
        self.comboType = comboType
        self.scope = scope
        self.staggerDirection = staggerDirection
        self.staggerDelay = max(0.01, min(0.2, staggerDelay))
        self.anchorPoint = anchorPoint
        self.rgbSplitIntensity = max(0.0, min(20.0, rgbSplitIntensity))
        self.lightSweepIntensity = max(0.0, min(1.0, lightSweepIntensity))
        self.isMaskEnabled = isMaskEnabled
        self.isMotionBlurEnabled = isMotionBlurEnabled
        self.isTypewriterCursorVisible = isTypewriterCursorVisible
        self.highlightColorHex = highlightColorHex
        self.motionEasing = motionEasing
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.inType = (try? c.decodeIfPresent(TextInAnimationType.self, forKey: .inType)) ?? .none
        self.inDuration = (try? c.decodeIfPresent(Double.self, forKey: .inDuration)) ?? 0.5
        self.outType = (try? c.decodeIfPresent(TextOutAnimationType.self, forKey: .outType)) ?? .none
        self.outDuration = (try? c.decodeIfPresent(Double.self, forKey: .outDuration)) ?? 0.5
        self.loopType = (try? c.decodeIfPresent(TextLoopAnimationType.self, forKey: .loopType)) ?? .none
        self.loopSpeed = (try? c.decodeIfPresent(Double.self, forKey: .loopSpeed)) ?? 1.0
        self.comboType = (try? c.decodeIfPresent(TextComboAnimationType.self, forKey: .comboType)) ?? .none
        self.scope = (try? c.decodeIfPresent(TextAnimationScope.self, forKey: .scope)) ?? .wholeBlock
        self.staggerDirection = (try? c.decodeIfPresent(TextStaggerDirection.self, forKey: .staggerDirection)) ?? .forward
        self.staggerDelay = (try? c.decodeIfPresent(Double.self, forKey: .staggerDelay)) ?? 0.04
        self.anchorPoint = (try? c.decodeIfPresent(TextAnchorPoint.self, forKey: .anchorPoint)) ?? .center
        self.rgbSplitIntensity = (try? c.decodeIfPresent(Double.self, forKey: .rgbSplitIntensity)) ?? 0.0
        self.lightSweepIntensity = (try? c.decodeIfPresent(Double.self, forKey: .lightSweepIntensity)) ?? 0.0
        self.isMaskEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isMaskEnabled)) ?? false
        self.isMotionBlurEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isMotionBlurEnabled)) ?? true
        self.isTypewriterCursorVisible = (try? c.decodeIfPresent(Bool.self, forKey: .isTypewriterCursorVisible)) ?? true
        self.highlightColorHex = (try? c.decodeIfPresent(String.self, forKey: .highlightColorHex)) ?? "#FDE047"
        self.motionEasing = (try? c.decodeIfPresent(TextMotionEasing.self, forKey: .motionEasing)) ?? .smooth
    }

    public var isDefault: Bool {
        inType == .none && outType == .none && loopType == .none && comboType == .none
            && rgbSplitIntensity == 0.0 && lightSweepIntensity == 0.0 && !isMaskEnabled
    }
}

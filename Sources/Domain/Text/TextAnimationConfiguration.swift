import Foundation

/// Danh mục đường cong gia tốc chuyển động (Motion Easing)
public enum TextMotionEasing: String, Codable, Sendable, CaseIterable, Identifiable {
    case smooth = "Smooth"
    case spring = "Spring"
    case bounce = "Bounce"
    case elastic = "Elastic"

    public var id: String { rawValue }
}

/// Cấu hình hoạt ảnh chuyển động toàn diện cho Text Clip (In, Out, Loop & Open Creative Manifests).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, không UI) và R4.3 (đơn nhiệm).
public struct TextAnimationConfiguration: Codable, Sendable, Equatable, Hashable {
    public var inType: TextInAnimationType
    public var inDuration: Double
    public var outType: TextOutAnimationType
    public var outDuration: Double
    public var loopType: TextLoopAnimationType
    public var loopSpeed: Double
    /// Backward-compatibility: comboType is retained for legacy project data compatibility
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

    /// Gói công thức hoạt ảnh sáng tạo mở (Open Creative Animation Manifest) cho 3 pha In, Out, Loop
    public var inManifest: CreativeAnimationManifest?
    public var outManifest: CreativeAnimationManifest?
    public var loopManifest: CreativeAnimationManifest?
    public var parameterValues: [String: Double]

    public init(
        inType: TextInAnimationType = .none,
        inDuration: Double = 1.0,
        outType: TextOutAnimationType = .none,
        outDuration: Double = 1.0,
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
        motionEasing: TextMotionEasing = .smooth,
        inManifest: CreativeAnimationManifest? = nil,
        outManifest: CreativeAnimationManifest? = nil,
        loopManifest: CreativeAnimationManifest? = nil,
        parameterValues: [String: Double] = [:]
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
        self.inManifest = inManifest
        self.outManifest = outManifest
        self.loopManifest = loopManifest
        self.parameterValues = parameterValues
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.inType = (try? c.decodeIfPresent(TextInAnimationType.self, forKey: .inType)) ?? .none
        self.inDuration = (try? c.decodeIfPresent(Double.self, forKey: .inDuration)) ?? 1.0
        self.outType = (try? c.decodeIfPresent(TextOutAnimationType.self, forKey: .outType)) ?? .none
        self.outDuration = (try? c.decodeIfPresent(Double.self, forKey: .outDuration)) ?? 1.0
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
        self.inManifest = try? c.decodeIfPresent(CreativeAnimationManifest.self, forKey: .inManifest)
        self.outManifest = try? c.decodeIfPresent(CreativeAnimationManifest.self, forKey: .outManifest)
        self.loopManifest = try? c.decodeIfPresent(CreativeAnimationManifest.self, forKey: .loopManifest)
        self.parameterValues = (try? c.decodeIfPresent([String: Double].self, forKey: .parameterValues)) ?? [:]
    }

    public var hasInAnimation: Bool {
        inManifest != nil || inType != .none
    }

    public var hasOutAnimation: Bool {
        outManifest != nil || outType != .none
    }

    public var hasLoopAnimation: Bool {
        loopManifest != nil || loopType != .none
    }

    public var isDefault: Bool {
        !hasInAnimation && !hasOutAnimation && !hasLoopAnimation
            && rgbSplitIntensity == 0.0 && lightSweepIntensity == 0.0 && !isMaskEnabled
    }

    public func value(forParameter id: String, in manifest: CreativeAnimationManifest?) -> Double {
        if let stored = parameterValues[id] { return stored }
        return manifest?.customParameters.first(where: { $0.id == id })?.defaultValue ?? 0.0
    }

    public mutating func setValue(_ value: Double, forParameter id: String, in manifest: CreativeAnimationManifest?) {
        if let descriptor = manifest?.customParameters.first(where: { $0.id == id }) {
            parameterValues[id] = max(descriptor.minValue, min(descriptor.maxValue, value))
        } else {
            parameterValues[id] = value
        }
    }
}

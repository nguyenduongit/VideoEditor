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

    // MARK: - Script-Driven Continuous Animation (Dev-Authored)
    public var scriptId: String
    public var scriptDuration: Double
    public var scriptInDuration: Double
    public var scriptLoopDuration: Double
    public var scriptOutDuration: Double
    public var isScriptLoop: Bool
    public var scriptSpeed: Double

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
        parameterValues: [String: Double] = [:],
        scriptId: String = "none",
        scriptDuration: Double = 5.0,
        scriptInDuration: Double = 1.0,
        scriptLoopDuration: Double = 3.0,
        scriptOutDuration: Double = 1.0,
        isScriptLoop: Bool = false,
        scriptSpeed: Double = 1.0
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
        self.scriptId = scriptId
        self.scriptInDuration = max(0.0, min(20.0, scriptInDuration))
        self.scriptLoopDuration = max(0.2, min(80.0, scriptLoopDuration))
        self.scriptOutDuration = max(0.0, min(20.0, scriptOutDuration))
        self.scriptDuration = max(0.2, min(120.0, scriptDuration))
        self.isScriptLoop = isScriptLoop
        self.scriptSpeed = max(0.2, min(4.0, scriptSpeed))
    }

    enum CodingKeys: String, CodingKey {
        case inType, inDuration, outType, outDuration, loopType, loopSpeed, comboType
        case scope, staggerDirection, staggerDelay, anchorPoint
        case rgbSplitIntensity, lightSweepIntensity, isMaskEnabled, isMotionBlurEnabled
        case isTypewriterCursorVisible, highlightColorHex, motionEasing
        case inManifest, outManifest, loopManifest, parameterValues
        case scriptId, scriptDuration, scriptInDuration, scriptLoopDuration, scriptOutDuration
        case isScriptLoop, scriptSpeed
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
        self.scriptId = (try? c.decodeIfPresent(String.self, forKey: .scriptId)) ?? "none"
        self.scriptInDuration = (try? c.decodeIfPresent(Double.self, forKey: .scriptInDuration)) ?? 1.0
        self.scriptLoopDuration = (try? c.decodeIfPresent(Double.self, forKey: .scriptLoopDuration)) ?? 3.0
        self.scriptOutDuration = (try? c.decodeIfPresent(Double.self, forKey: .scriptOutDuration)) ?? 1.0
        self.scriptDuration = (try? c.decodeIfPresent(Double.self, forKey: .scriptDuration)) ?? 5.0
        self.isScriptLoop = (try? c.decodeIfPresent(Bool.self, forKey: .isScriptLoop)) ?? false
        self.scriptSpeed = (try? c.decodeIfPresent(Double.self, forKey: .scriptSpeed)) ?? 1.0
    }

    public var hasScriptAnimation: Bool {
        scriptId != "none" && !scriptId.isEmpty
    }

    /// Số giây Loop cơ sở (bội số nguyên của 1s, mặc định 3s) trước khi nhân hệ số `scriptSpeed`.
    public var scriptBaseLoopSeconds: Int {
        let unit = max(0.1, scriptInDuration > 0.05 ? scriptInDuration : scriptSpeed)
        return max(1, min(30, Int((scriptLoopDuration / unit).rounded())))
    }

    /// Áp dụng quy tắc thời lượng chuẩn hóa:
    /// - Base In = 1s, Base Out = 1s, Base Loop = `baseLoopSeconds` (bội số nguyên của 1s).
    /// - Khi thay đổi `speed` (ví dụ 1.2x): In = 1.2s, Loop = 3.6s, Out = 1.2s, Tổng = 6.0s.
    public mutating func applyUnifiedScriptTiming(baseLoopSeconds: Int, speed: Double) {
        let cleanLoop = max(1, min(30, baseLoopSeconds))
        let cleanSpeed = max(0.2, min(4.0, (speed * 100.0).rounded() / 100.0))
        self.scriptSpeed = cleanSpeed
        self.scriptInDuration = (1.0 * cleanSpeed * 100.0).rounded() / 100.0
        self.scriptLoopDuration = (Double(cleanLoop) * cleanSpeed * 100.0).rounded() / 100.0
        self.scriptOutDuration = (1.0 * cleanSpeed * 100.0).rounded() / 100.0
        self.scriptDuration = (Double(2 + cleanLoop) * cleanSpeed * 100.0).rounded() / 100.0
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
        !hasScriptAnimation && !hasInAnimation && !hasOutAnimation && !hasLoopAnimation
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

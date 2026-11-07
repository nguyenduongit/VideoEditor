import Foundation

/// Phân loại pha hoạt ảnh trong Thư viện Animation Sáng Tạo Mở (In, Out, Loop)
public enum AnimationPhaseCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case inAnimation = "In"
    case outAnimation = "Out"
    case loopAnimation = "Loop"

    public var id: String { rawValue }
}

/// Đặc tả Công thức Chuyển động Toán học & Quang học Động (Open Creative Animation Manifest).
/// Cho phép cộng đồng tự do lập trình phương trình chuyển động 2D/3D, Squash & Stretch, Glitch/Blur và thanh trượt tùy chỉnh.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R5.6 (Forward Compatibility).
public struct CreativeAnimationManifest: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var iconName: String
    public var phase: AnimationPhaseCategory
    public var defaultScope: TextAnimationScope
    public var defaultStaggerDirection: TextStaggerDirection
    public var customParameters: [CustomParameterDescriptor]

    // Các kênh phương trình biến đổi không gian 2D/3D & Quang học
    public var offsetXExpr: String?
    public var offsetYExpr: String?
    public var scaleXExpr: String?
    public var scaleYExpr: String?
    public var rotationExpr: String?
    public var skewXExpr: String?
    public var perspectiveXExpr: String?
    public var perspectiveYExpr: String?
    public var opacityExpr: String?
    public var blurExpr: String?
    public var rgbSplitExpr: String?
    public var pixelateExpr: String?
    public var trackingExpr: String?
    public var glowExpr: String?
    public var hueExpr: String?
    public var revealExpr: String?

    public init(
        id: String,
        name: String,
        iconName: String = "sparkles",
        phase: AnimationPhaseCategory,
        defaultScope: TextAnimationScope = .perCharacter,
        defaultStaggerDirection: TextStaggerDirection = .forward,
        customParameters: [CustomParameterDescriptor] = [],
        offsetXExpr: String? = nil,
        offsetYExpr: String? = nil,
        scaleXExpr: String? = nil,
        scaleYExpr: String? = nil,
        rotationExpr: String? = nil,
        skewXExpr: String? = nil,
        perspectiveXExpr: String? = nil,
        perspectiveYExpr: String? = nil,
        opacityExpr: String? = nil,
        blurExpr: String? = nil,
        rgbSplitExpr: String? = nil,
        pixelateExpr: String? = nil,
        trackingExpr: String? = nil,
        glowExpr: String? = nil,
        hueExpr: String? = nil,
        revealExpr: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.phase = phase
        self.defaultScope = defaultScope
        self.defaultStaggerDirection = defaultStaggerDirection
        self.customParameters = customParameters
        self.offsetXExpr = offsetXExpr
        self.offsetYExpr = offsetYExpr
        self.scaleXExpr = scaleXExpr
        self.scaleYExpr = scaleYExpr
        self.rotationExpr = rotationExpr
        self.skewXExpr = skewXExpr
        self.perspectiveXExpr = perspectiveXExpr
        self.perspectiveYExpr = perspectiveYExpr
        self.opacityExpr = opacityExpr
        self.blurExpr = blurExpr
        self.rgbSplitExpr = rgbSplitExpr
        self.pixelateExpr = pixelateExpr
        self.trackingExpr = trackingExpr
        self.glowExpr = glowExpr
        self.hueExpr = hueExpr
        self.revealExpr = revealExpr
    }
}


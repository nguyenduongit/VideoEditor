import Foundation
import CoreMedia

/// Kiểu căn chỉnh vị trí hiệu ứng chuyển cảnh so với vết cắt giữa 2 clip.
public enum TransitionAlignment: String, Codable, Sendable, CaseIterable, Hashable {
    case center = "center"
    case startOnCut = "start"
    case endOnCut = "end"

    public var displayName: String {
        switch self {
        case .center:
            return "Ở giữa"
        case .startOnCut:
            return "Từ vết cắt"
        case .endOnCut:
            return "Đến vết cắt"
        }
    }
}

/// Đường cong gia tốc thời gian (Easing) cho chuyển cảnh giữa 2 clip.
public enum TransitionEasing: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case linear = "linear"
    case easeIn = "ease_in"
    case easeOut = "ease_out"
    case easeInOut = "ease_in_out"
    case cubicBezier = "cubic_bezier"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .linear: return "Đều (Linear)"
        case .easeIn: return "Nhanh dần (Ease In)"
        case .easeOut: return "Chậm dần (Ease Out)"
        case .easeInOut: return "Mượt hai đầu (Ease In-Out)"
        case .cubicBezier: return "Động lực (Cubic Punch)"
        }
    }

    /// Nội suy tiến trình thô `t` (`0.0...1.0`) sang tiến trình đã làm mượt.
    public func apply(to rawProgress: Double) -> Double {
        let t = max(0.0, min(1.0, rawProgress))
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t * t
        case .easeOut:
            let inv = 1.0 - t
            return 1.0 - inv * inv * inv
        case .easeInOut:
            return t < 0.5
                ? 4.0 * t * t * t
                : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
        case .cubicBezier:
            // Đường cong punch nhanh ở tâm vết cắt (tương đương Bezier tốc độ cao NLE)
            let s = t * t * (3.0 - 2.0 * t)
            return s * s * (3.0 - 2.0 * s)
        }
    }
}

/// Họ thuật toán GPU Dual-Texture Metal Kernel chuyển tiếp giữa 2 khung hình (8 họ chuẩn + mở rộng).
public enum TransitionShaderType: String, Codable, Sendable, CaseIterable, Hashable {
    case dissolve = "dissolve"
    case directionalPush = "directional_push"
    case whipPanLeft = "whip_pan_left"
    case whipPanRight = "whip_pan_right"
    case zoomBlur = "zoom_blur"
    case crossWarp = "cross_warp"
    case glitchWipe = "glitch_wipe"
    case lightLeak = "light_leak"
    case geometricWipe = "geometric_wipe"

    public var displayName: String {
        switch self {
        case .dissolve: return "Hòa tan (Dissolve)"
        case .directionalPush: return "Đẩy khung hình (Push)"
        case .whipPanLeft: return "Whip Pan Trái"
        case .whipPanRight: return "Whip Pan Phải"
        case .zoomBlur: return "Zoom Blur"
        case .crossWarp: return "Uốn sóng (Cross Warp)"
        case .glitchWipe: return "Glitch Slice"
        case .lightLeak: return "Vệt sáng (Light Leak)"
        case .geometricWipe: return "Hình học (Geometric Wipe)"
        }
    }

    /// Tên hàm Metal Compute Kernel 2-texture tương ứng trong `BuiltInMetalShaders`.
    public var metalKernelName: String {
        switch self {
        case .dissolve: return "metal_transition_dissolve"
        case .directionalPush: return "metal_transition_push"
        case .whipPanLeft, .whipPanRight: return "metal_transition_whip_pan"
        case .zoomBlur: return "metal_transition_zoom_blur"
        case .crossWarp: return "metal_transition_cross_warp"
        case .glitchWipe: return "metal_transition_glitch_slice"
        case .lightLeak: return "metal_transition_light_leak"
        case .geometricWipe: return "metal_transition_geometric_wipe"
        }
    }
}

/// Nút chuyển cảnh phi phá hủy liên kết trực tiếp 2 clip kề nhau trên cùng một Layer/Track.
/// Hỗ trợ tham số động `parameterValues`, mã nguồn MSL tùy chỉnh `customMetalSource`, `easing` và `crossfadeAudio`.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R3.1 và R7.1 (Transaction / Undo-Redo).
public struct CutTransition: Identifiable, Codable, Sendable, Hashable, Equatable {
    public let id: UUID
    public var presetID: String
    public var name: String
    public var leadingClipID: UUID
    public var trailingClipID: UUID
    public var duration: RationalTime
    public var alignment: TransitionAlignment
    public var shaderType: TransitionShaderType
    public var easing: TransitionEasing
    public var crossfadeAudio: Bool
    public var parameterValues: [String: Double]
    public var customMetalSource: String?

    public init(
        id: UUID = UUID(),
        presetID: String,
        name: String,
        leadingClipID: UUID,
        trailingClipID: UUID,
        duration: RationalTime = RationalTime(cmTime: CMTime(value: 300, timescale: 600)),
        alignment: TransitionAlignment = .center,
        shaderType: TransitionShaderType = .dissolve,
        easing: TransitionEasing = .easeInOut,
        crossfadeAudio: Bool = true,
        parameterValues: [String: Double] = [:],
        customMetalSource: String? = nil
    ) {
        self.id = id
        self.presetID = presetID
        self.name = name
        self.leadingClipID = leadingClipID
        self.trailingClipID = trailingClipID
        self.duration = duration
        self.alignment = alignment
        self.shaderType = shaderType
        self.easing = easing
        self.crossfadeAudio = crossfadeAudio
        self.parameterValues = parameterValues
        self.customMetalSource = customMetalSource
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.presetID = (try? c.decode(String.self, forKey: .presetID)) ?? "dissolve_default"
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Chuyển cảnh"
        self.leadingClipID = try c.decode(UUID.self, forKey: .leadingClipID)
        self.trailingClipID = try c.decode(UUID.self, forKey: .trailingClipID)
        self.duration = (try? c.decode(RationalTime.self, forKey: .duration))
            ?? RationalTime(cmTime: CMTime(value: 300, timescale: 600))
        self.alignment = (try? c.decode(TransitionAlignment.self, forKey: .alignment)) ?? .center
        self.shaderType = (try? c.decode(TransitionShaderType.self, forKey: .shaderType)) ?? .dissolve
        self.easing = (try? c.decodeIfPresent(TransitionEasing.self, forKey: .easing)) ?? .easeInOut
        self.crossfadeAudio = (try? c.decodeIfPresent(Bool.self, forKey: .crossfadeAudio)) ?? true
        self.parameterValues = (try? c.decodeIfPresent([String: Double].self, forKey: .parameterValues)) ?? [:]
        self.customMetalSource = try? c.decodeIfPresent(String.self, forKey: .customMetalSource)
    }
}

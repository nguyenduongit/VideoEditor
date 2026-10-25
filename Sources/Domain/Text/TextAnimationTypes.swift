import Foundation

/// Phạm vi áp dụng hoạt ảnh (Toàn khối, từng từ hoặc từng ký tự)
public enum TextAnimationScope: String, Codable, Sendable, CaseIterable, Identifiable {
    case wholeBlock = "Whole Block"
    case perWord = "Per Word"
    case perCharacter = "Per Character"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wholeBlock: return "Cả khối"
        case .perWord: return "Từng từ"
        case .perCharacter: return "Từng chữ"
        }
    }
}

/// Hướng lan truyền độ trễ (Stagger Direction) khi chạy hoạt ảnh Từng từ / Từng chữ
public enum TextStaggerDirection: String, Codable, Sendable, CaseIterable, Identifiable {
    case forward = "Forward"
    case backward = "Backward"
    case centerOut = "Center Out"
    case edgesIn = "Edges In"
    case random = "Random"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .forward: return "Trái → Phải"
        case .backward: return "Phải → Trái"
        case .centerOut: return "Từ tâm"
        case .edgesIn: return "Hai đầu"
        case .random: return "Ngẫu nhiên"
        }
    }
}

/// Điểm neo tâm biến đổi (Pivot / Anchor Point) của chữ khi xoay hoặc phóng to
public enum TextAnchorPoint: String, Codable, Sendable, CaseIterable, Identifiable {
    case center = "Center"
    case bottom = "Bottom"
    case top = "Top"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .center: return "Tâm giữa"
        case .bottom: return "Chân chữ"
        case .top: return "Đỉnh chữ"
        }
    }
}

/// Danh mục hoạt ảnh kết hợp (Combo Animation) chạy đồng bộ suốt thời lượng clip
public enum TextComboAnimationType: String, Codable, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case karaokeBox = "Karaoke Box"
    case karaokeGlow = "Karaoke Glow"
    case elasticJelly = "Elastic Jelly"
    case flip3DSwing = "3D Swing"
    case pendulum = "Pendulum"
    case zoomShake = "Zoom Shake"
    case kineticBounce = "Kinetic Bounce"
    case glitchPulse = "Glitch Pulse"
    case stopMotionJitter = "Stop Motion"
    case cyberScanline = "Cyber Scan"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .karaokeBox: return "rectangle.fill.on.rectangle.angled.fill"
        case .karaokeGlow: return "mic.and.signal.meter.fill"
        case .elasticJelly: return "circle.hexagongrid.fill"
        case .flip3DSwing: return "rotate.3d.fill"
        case .pendulum: return "metronome"
        case .zoomShake: return "arrow.up.left.and.down.right.magnifyingglass"
        case .kineticBounce: return "figure.run"
        case .glitchPulse: return "bolt.badge.clock"
        case .stopMotionJitter: return "film.stack"
        case .cyberScanline: return "barcode.viewfinder"
        }
    }
}

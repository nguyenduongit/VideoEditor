import Foundation

/// Định danh các loại video thuật toán toán học (Procedural / Generative Video Types).
/// Tuân thủ AGENTS.md R2.3 (Domain thuần khiết không UI), R3.1 (File <= 300 dòng), R8.3 (Sendable).
public enum ProceduralType: String, CaseIterable, Codable, Sendable {
    // Nhóm 1: Nền chuyển động
    case meshAurora = "mesh_aurora"
    case topographicLines = "topographic_lines"
    case retroGrid = "retro_grid"

    // Nhóm 2: Lớp phủ điện ảnh
    case filmGrain = "film_grain"
    case floatingBokeh = "floating_bokeh"
    case lightLeaks = "light_leaks"

    // Nhóm 3: Công cụ & Tiện ích
    case blackScreen = "black_screen"
    case chromaStudio = "chroma_studio"
    case filmCountdown = "film_countdown"
    case colorBars = "color_bars"

    // Nhóm 4: Thị giác & Thôi miên
    case hypnoticTunnel = "hypnotic_tunnel"
    case matrixRain = "matrix_rain"

    public var displayName: String {
        switch self {
        case .meshAurora: return "Cực quang Aurora"
        case .topographicLines: return "Đường đồng mức"
        case .retroGrid: return "Lưới 3D Synthwave"
        case .filmGrain: return "Hạt phim 35mm"
        case .floatingBokeh: return "Đốm bụi sáng"
        case .lightLeaks: return "Vệt lóa sáng"
        case .blackScreen: return "Màn hình đen"
        case .chromaStudio: return "Phông xanh Chroma"
        case .filmCountdown: return "Đếm ngược cổ điển"
        case .colorBars: return "Kiểm chuẩn SMPTE"
        case .hypnoticTunnel: return "Đường hầm xoáy"
        case .matrixRain: return "Mưa ký tự Matrix"
        }
    }

    public var category: String {
        switch self {
        case .blackScreen, .chromaStudio, .colorBars:
            return "Màu nền & Phông"
        case .meshAurora, .topographicLines, .retroGrid:
            return "Nền chuyển động"
        case .filmGrain, .floatingBokeh, .lightLeaks:
            return "Lớp phủ điện ảnh"
        case .hypnoticTunnel, .matrixRain, .filmCountdown:
            return "Thị giác & Hiệu ứng"
        }
    }

    public var defaultBlendMode: String {
        switch self {
        case .filmGrain, .floatingBokeh, .lightLeaks:
            return "screen"
        default:
            return "normal"
        }
    }

    public var defaultPrimaryColorHex: String {
        switch self {
        case .meshAurora: return "#4E65FF"
        case .topographicLines: return "#0F172A"
        case .retroGrid: return "#0A0017"
        case .filmGrain: return "#808080"
        case .floatingBokeh: return "#FFD166"
        case .lightLeaks: return "#FF9F1C"
        case .blackScreen: return "#000000"
        case .chromaStudio: return "#00FF00"
        case .filmCountdown: return "#1A1A1A"
        case .colorBars: return "#C0C0C0"
        case .hypnoticTunnel: return "#00F0FF"
        case .matrixRain: return "#00FF66"
        }
    }

    public var defaultSecondaryColorHex: String {
        switch self {
        case .meshAurora: return "#92EFFD"
        case .topographicLines: return "#38BDF8"
        case .retroGrid: return "#FF007F"
        case .filmGrain: return "#FFFFFF"
        case .floatingBokeh: return "#EF476F"
        case .lightLeaks: return "#E71D36"
        case .blackScreen: return "#000000"
        case .chromaStudio: return "#0000FF"
        case .filmCountdown: return "#FFFFFF"
        case .colorBars: return "#000000"
        case .hypnoticTunnel: return "#7928CA"
        case .matrixRain: return "#003311"
        }
    }
}

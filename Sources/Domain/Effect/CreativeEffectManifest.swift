import Foundation

/// Khai báo một thanh trượt tham số tùy chỉnh do tác giả gói sáng tạo (Creative Package) tự định nghĩa trong JSON.
/// Khi gói được thêm vào Timeline, Inspector sẽ tự động sinh thanh trượt điều khiển tương ứng.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R5.6 (Tương thích ngược & tiến).
public struct CustomParameterDescriptor: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var minValue: Double
    public var maxValue: Double
    public var defaultValue: Double
    public var step: Double
    public var unit: String

    public init(
        id: String,
        title: String,
        minValue: Double = 0.0,
        maxValue: Double = 1.0,
        defaultValue: Double = 0.5,
        step: Double = 0.01,
        unit: String = ""
    ) {
        self.id = id
        self.title = title
        let safeMin = min(minValue, maxValue)
        let safeMax = max(minValue, maxValue == minValue ? minValue + 1.0 : maxValue)
        self.minValue = safeMin
        self.maxValue = safeMax
        self.defaultValue = max(safeMin, min(safeMax, defaultValue))
        self.step = max(0.001, step)
        self.unit = unit
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "Tham số"
        let minV = (try? c.decodeIfPresent(Double.self, forKey: .minValue)) ?? 0.0
        let maxV = (try? c.decodeIfPresent(Double.self, forKey: .maxValue)) ?? 1.0
        let safeMin = min(minV, maxV)
        let safeMax = max(minV, maxV == minV ? minV + 1.0 : maxV)
        self.minValue = safeMin
        self.maxValue = safeMax
        let defV = (try? c.decodeIfPresent(Double.self, forKey: .defaultValue)) ?? safeMin
        self.defaultValue = max(safeMin, min(safeMax, defV))
        self.step = max(0.001, (try? c.decodeIfPresent(Double.self, forKey: .step)) ?? 0.01)
        self.unit = (try? c.decodeIfPresent(String.self, forKey: .unit)) ?? ""
    }
}

/// Một bước xử lý trong Pipeline đồ họa động của Gói Sáng Tạo Mở (Open Creative Package).
/// Hỗ trợ cả bộ lọc CoreImage nguyên tử (`CIPixellate`, `CIBloom`...), bộ lọc Metal Compute tích hợp (`RGBSplit`, `VHSRetro`, `ThermalVision`, `MetalShockwave`...),
/// và mã nguồn Metal Shading Language (`MSL`) tùy chỉnh biên dịch lúc chạy (Runtime GPU Compilation).
public struct CreativeFilterStep: Codable, Sendable, Equatable {
    public var filterName: String
    public var kernelSource: String?
    public var metalKernelName: String?
    /// Ánh xạ tên tham số -> biểu thức giá trị:
    /// Hỗ trợ hằng số số thực (vd: `"12.5"`), biến hệ thống (`"$progress"`, `"$time"`, `"$intensity"`, `"$speed"`),
    /// tham số tùy chỉnh (`"$param.<id>"`), hoặc biểu thức toán học (`"$param.amount * $intensity"`).
    public var parameterBindings: [String: String]

    public init(
        filterName: String,
        kernelSource: String? = nil,
        metalKernelName: String? = nil,
        parameterBindings: [String: String] = [:]
    ) {
        self.filterName = filterName
        self.kernelSource = kernelSource
        self.metalKernelName = metalKernelName
        self.parameterBindings = parameterBindings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.filterName = (try? c.decode(String.self, forKey: .filterName)) ?? "CIBloom"
        self.kernelSource = try? c.decodeIfPresent(String.self, forKey: .kernelSource)
        self.metalKernelName = try? c.decodeIfPresent(String.self, forKey: .metalKernelName)
        self.parameterBindings = (try? c.decodeIfPresent([String: String].self, forKey: .parameterBindings)) ?? [:]
    }
}


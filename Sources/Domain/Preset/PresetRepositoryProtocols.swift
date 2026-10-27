import Foundation

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu thiết lập sẵn chỉnh màu (Adjustment Presets)
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R2.6 (Protocol tại Domain).
public protocol AdjustmentPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [AdjustmentPreset]
    func savePreset(_ preset: AdjustmentPreset) async throws
    func deletePreset(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu thiết lập sẵn chữ & hoạt ảnh (Text Presets)
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R2.6 (Protocol tại Domain).
public protocol TextPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [TextPreset]
    func savePreset(_ preset: TextPreset) async throws
    func deletePreset(id: String) async throws
}

/// Điểm cung cấp trung gian cho Dependency Injection giữa App Composition Root và Feature UI
/// Giúp FeatureShell không cần import trực tiếp tầng Infrastructure hay Supabase SDK (R2.1, R2.5).
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class PresetRepositoryProvider: @unchecked Sendable {

    private let lock = NSLock()
    private var _adjustmentRepository: (any AdjustmentPresetRepositoryProtocol)?
    private var _textRepository: (any TextPresetRepositoryProtocol)?

    public init() {}

    public var adjustmentRepository: (any AdjustmentPresetRepositoryProtocol)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _adjustmentRepository
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _adjustmentRepository = newValue
        }
    }

    public var textRepository: (any TextPresetRepositoryProtocol)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _textRepository
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _textRepository = newValue
        }
    }
}

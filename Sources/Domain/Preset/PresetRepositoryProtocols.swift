import Foundation

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu thiết lập sẵn chỉnh màu (Adjustment Presets)
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R2.6 (Protocol tại Domain).
public protocol AdjustmentPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [AdjustmentPreset]
    func savePreset(_ preset: AdjustmentPreset) async throws
    func deletePreset(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu thiết lập sẵn chữ & hoạt ảnh (Text Presets)
public protocol TextPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [TextPreset]
    func savePreset(_ preset: TextPreset) async throws
    func deletePreset(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu thiết lập sẵn hiệu ứng thị giác (Effect Presets)
public protocol EffectPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [EffectPreset]
    func savePreset(_ preset: EffectPreset) async throws
    func deletePreset(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ gói hoạt ảnh sáng tạo mở (Animation Presets)
public protocol AnimationPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [AnimationPreset]
    func savePreset(_ preset: AnimationPreset) async throws
    func deletePreset(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu nhãn dán Vector SVG / GIF / APNG (Sticker Presets)
public protocol StickerPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [StickerPreset]
    func savePreset(_ preset: StickerPreset) async throws
    func deletePreset(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu chuyển cảnh (Transition Presets)
public protocol TransitionPresetRepositoryProtocol: Sendable {
    func fetchPresets() async throws -> [TransitionPreset]
    func savePreset(_ preset: TransitionPreset) async throws
    func deletePreset(id: String) async throws
}

/// Điểm cung cấp trung gian cho Dependency Injection giữa App Composition Root và Feature UI.
/// Giúp FeatureShell không cần import trực tiếp tầng Infrastructure hay Supabase SDK (R2.1, R2.5).
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class PresetRepositoryProvider: @unchecked Sendable {

    private let lock = NSLock()
    private var _adjustmentRepository: (any AdjustmentPresetRepositoryProtocol)?
    private var _textRepository: (any TextPresetRepositoryProtocol)?
    private var _effectRepository: (any EffectPresetRepositoryProtocol)?
    private var _animationRepository: (any AnimationPresetRepositoryProtocol)?
    private var _stickerRepository: (any StickerPresetRepositoryProtocol)?
    private var _transitionRepository: (any TransitionPresetRepositoryProtocol)?

    public init() {}

    public var adjustmentRepository: (any AdjustmentPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _adjustmentRepository }
        set { lock.lock(); defer { lock.unlock() }; _adjustmentRepository = newValue }
    }

    public var textRepository: (any TextPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _textRepository }
        set { lock.lock(); defer { lock.unlock() }; _textRepository = newValue }
    }

    public var effectRepository: (any EffectPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _effectRepository }
        set { lock.lock(); defer { lock.unlock() }; _effectRepository = newValue }
    }

    public var animationRepository: (any AnimationPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _animationRepository }
        set { lock.lock(); defer { lock.unlock() }; _animationRepository = newValue }
    }

    public var stickerRepository: (any StickerPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _stickerRepository }
        set { lock.lock(); defer { lock.unlock() }; _stickerRepository = newValue }
    }

    public var transitionRepository: (any TransitionPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _transitionRepository }
        set { lock.lock(); defer { lock.unlock() }; _transitionRepository = newValue }
    }
}

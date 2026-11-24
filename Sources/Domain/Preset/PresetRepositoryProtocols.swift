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

/// Hợp đồng quản lý nạp và đồng bộ thư viện Audio BGM / SFX qua Cloud URL (`audio_library`)
public protocol AudioLibraryRepositoryProtocol: Sendable {
    func fetchAudioItems() async throws -> [AudioLibraryItem]
    func saveAudioItem(_ item: AudioLibraryItem) async throws
    func deleteAudioItem(id: String) async throws
}

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ mẫu Stock Media (Videos, Backgrounds, SFX) qua Cloud URL
public protocol StockMediaRepositoryProtocol: Sendable {
    func fetchStockItems() async throws -> [StockMediaItem]
    func saveStockItem(_ item: StockMediaItem) async throws
    func deleteStockItem(id: String) async throws
}

/// Hợp đồng quản lý đồng bộ danh mục yêu thích (Favorites) của người dùng trên Supabase
public protocol FavoriteRepositoryProtocol: Sendable {
    func fetchFavorites(for tab: String) async throws -> Set<String>
    func addFavorite(id: String, for tab: String) async throws
    func removeFavorite(id: String, for tab: String) async throws
}

/// Điểm cung cấp trung gian cho Dependency Injection giữa App Composition Root và Feature UI.
/// Giúp FeatureShell không cần import trực tiếp tầng Infrastructure hay Supabase SDK (R2.1, R2.5).
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class PresetRepositoryProvider: @unchecked Sendable {

    private let lock = NSLock()
    private var _adjustmentRepository: (any AdjustmentPresetRepositoryProtocol)?
    private var _textRepository: (any TextPresetRepositoryProtocol)?
    private var _audioRepository: (any AudioLibraryRepositoryProtocol)?
    private var _stockMediaRepository: (any StockMediaRepositoryProtocol)?
    private var _favoriteRepository: (any FavoriteRepositoryProtocol)?

    public init() {}

    public var adjustmentRepository: (any AdjustmentPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _adjustmentRepository }
        set { lock.lock(); defer { lock.unlock() }; _adjustmentRepository = newValue }
    }

    public var textRepository: (any TextPresetRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _textRepository }
        set { lock.lock(); defer { lock.unlock() }; _textRepository = newValue }
    }

    public var audioRepository: (any AudioLibraryRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _audioRepository }
        set { lock.lock(); defer { lock.unlock() }; _audioRepository = newValue }
    }

    public var stockMediaRepository: (any StockMediaRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _stockMediaRepository }
        set { lock.lock(); defer { lock.unlock() }; _stockMediaRepository = newValue }
    }

    public var favoriteRepository: (any FavoriteRepositoryProtocol)? {
        get { lock.lock(); defer { lock.unlock() }; return _favoriteRepository }
        set { lock.lock(); defer { lock.unlock() }; _favoriteRepository = newValue }
    }
}

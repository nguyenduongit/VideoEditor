import Foundation

/// Hợp đồng quản lý nạp, lưu trữ và đồng bộ danh sách Action tùy chỉnh.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R2.6 (Protocol tại Domain).
public protocol ActionRepositoryProtocol: Sendable {
    func fetchActions() async throws -> [CustomAction]
    func saveAction(_ action: CustomAction) async throws
    func deleteAction(id: String) async throws
}

/// Điểm cung cấp trung gian cho Dependency Injection giữa App Composition Root và Feature UI
/// Giúp FeatureShell không cần import trực tiếp tầng Infrastructure hay Supabase SDK (R2.1, R2.5).
public final class ActionRepositoryProvider: @unchecked Sendable {
    public static let shared = ActionRepositoryProvider()

    private let lock = NSLock()
    private var _actionRepository: (any ActionRepositoryProtocol)?

    public init() {}

    public var actionRepository: (any ActionRepositoryProtocol)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _actionRepository
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _actionRepository = newValue
        }
    }
}

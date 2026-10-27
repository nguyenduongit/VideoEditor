import Foundation

/// Bộ nạp và đồng bộ các mẫu chữ (Text Presets) trực tuyến từ Supabase và bộ nhớ đệm RAM.
/// Tuyệt đối không lưu file đĩa cục bộ theo yêu cầu hệ thống chỉ lưu trữ Online.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public final class TextTemplateLoader: @unchecked Sendable {

    private let lock = NSLock()
    private var cachedTemplates: [TextPreset]?
    private var inMemoryPresets: [TextPreset] = []
    public private(set) var hasSyncedFromRemote = false

    public init() {}

    /// Đặt lại trạng thái đồng bộ (phục vụ unit test)
    public func resetSyncState() {
        lock.lock()
        hasSyncedFromRemote = false
        inMemoryPresets = []
        cachedTemplates = nil
        lock.unlock()
    }

    /// Cập nhật toàn bộ danh sách presets trên RAM (nhận từ Supabase API)
    public func setInMemoryTemplates(_ presets: [TextPreset]) {
        lock.lock()
        hasSyncedFromRemote = true
        inMemoryPresets = presets
        cachedTemplates = presets
        lock.unlock()
    }

    /// Thêm mới hoặc cập nhật 1 preset trên RAM khi người dùng lưu/ghi đè
    public func updateInMemoryPreset(_ preset: TextPreset) {
        lock.lock()
        if let idx = inMemoryPresets.firstIndex(where: { $0.id == preset.id }) {
            inMemoryPresets[idx] = preset
        } else {
            inMemoryPresets.append(preset)
        }
        cachedTemplates = inMemoryPresets
        lock.unlock()
    }

    /// Xóa 1 preset khỏi RAM khi người dùng xóa
    public func removeInMemoryPreset(id: String) {
        lock.lock()
        inMemoryPresets.removeAll { $0.id == id }
        cachedTemplates = inMemoryPresets
        lock.unlock()
    }

    /// Nạp toàn bộ danh sách TextPreset từ RAM đã đồng bộ với Supabase hoặc fallback mặc định
    public func loadAllTemplates(forceReload: Bool = false) -> [TextPreset] {
        lock.lock()
        defer { lock.unlock() }
        if hasSyncedFromRemote {
            return inMemoryPresets
        }
        if !inMemoryPresets.isEmpty {
            return inMemoryPresets
        }
        return Self.fallbackBuiltInTemplates
    }

    private static let fallbackBuiltInTemplates: [TextPreset] = [
        TextPreset.default
    ]

    /// Xóa bộ nhớ đệm và nạp lại từ Supabase / RAM
    @discardableResult
    public func reload() -> [TextPreset] {
        lock.lock()
        hasSyncedFromRemote = false
        lock.unlock()
        return loadAllTemplates(forceReload: true)
    }

    /// Xóa preset khỏi bộ nhớ RAM
    public func deleteTemplateFromUserCache(id: String) {
        removeInMemoryPreset(id: id)
    }

    /// Giải mã danh sách JSON trả về từ Supabase và nạp vào bộ nhớ RAM
    public func mergeSupabaseTemplateScripts(_ jsonPayloads: [String], persistToCache: Bool = true) -> [TextPreset] {
        for payload in jsonPayloads {
            guard let preset = TextPreset.decode(from: payload) else { continue }
            updateInMemoryPreset(preset)
        }
        return loadAllTemplates(forceReload: true)
    }

    /// Lưu 1 mẫu `TextPreset` vào RAM (không ghi file xuống đĩa máy)
    public func saveTemplateToUserCache(_ preset: TextPreset) -> URL? {
        updateInMemoryPreset(preset)
        return nil
    }
}

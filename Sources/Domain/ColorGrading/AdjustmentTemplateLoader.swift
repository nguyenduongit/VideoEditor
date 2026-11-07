import Foundation

/// Bộ nạp và đồng bộ các mẫu chỉnh màu (Adjustment Presets) trực tuyến từ Supabase và bộ nhớ đệm RAM.
/// Tuyệt đối không lưu file đĩa cục bộ theo yêu cầu hệ thống chỉ lưu trữ Online.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class AdjustmentTemplateLoader: @unchecked Sendable {

    private let lock = NSLock()
    private var cachedTemplates: [AdjustmentPreset]?
    private var inMemoryPresets: [AdjustmentPreset] = []
    private var _hasSyncedFromRemote = false

    public var hasSyncedFromRemote: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasSyncedFromRemote
    }

    public init() {}

    public func resetSyncState() {
        lock.lock()
        _hasSyncedFromRemote = false
        inMemoryPresets = []
        cachedTemplates = nil
        lock.unlock()
    }

    public func setInMemoryTemplates(_ presets: [AdjustmentPreset]) {
        lock.lock()
        _hasSyncedFromRemote = true
        inMemoryPresets = presets
        cachedTemplates = presets
        lock.unlock()
    }

    public func updateInMemoryPreset(_ preset: AdjustmentPreset) {
        lock.lock()
        if let idx = inMemoryPresets.firstIndex(where: { $0.id == preset.id }) {
            inMemoryPresets[idx] = preset
        } else {
            inMemoryPresets.append(preset)
        }
        cachedTemplates = inMemoryPresets
        lock.unlock()
    }

    public func removeInMemoryPreset(id: String) {
        lock.lock()
        inMemoryPresets.removeAll { $0.id == id }
        cachedTemplates = inMemoryPresets
        lock.unlock()
    }

    public func loadAllTemplates(forceReload: Bool = false) -> [AdjustmentPreset] {
        lock.lock()
        defer { lock.unlock() }
        if _hasSyncedFromRemote {
            return inMemoryPresets
        }
        if !inMemoryPresets.isEmpty {
            return inMemoryPresets
        }
        return Self.fallbackBuiltInTemplates
    }

    private static let fallbackBuiltInTemplates: [AdjustmentPreset] = [
        AdjustmentPreset.default
    ] + AdjustmentPreset.creativeCatalog

    @discardableResult
    public func reload() -> [AdjustmentPreset] {
        lock.lock()
        _hasSyncedFromRemote = false
        lock.unlock()
        return loadAllTemplates(forceReload: true)
    }

    public func deleteTemplateFromUserCache(id: String) {
        removeInMemoryPreset(id: id)
    }

    public func mergeSupabaseTemplateScripts(_ jsonPayloads: [String], persistToCache: Bool = true) -> [AdjustmentPreset] {
        for payload in jsonPayloads {
            guard let preset = AdjustmentPreset.decode(from: payload) else { continue }
            updateInMemoryPreset(preset)
        }
        return loadAllTemplates(forceReload: true)
    }

    public func saveTemplateToUserCache(_ preset: AdjustmentPreset) -> URL? {
        updateInMemoryPreset(preset)
        return nil
    }
}

import Foundation

/// Bộ nạp và đồng bộ các mẫu hiệu ứng thị giác (Effect Presets) trực tuyến từ Supabase và bộ nhớ đệm RAM.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class EffectTemplateLoader: @unchecked Sendable {

    private let lock = NSLock()
    private var inMemoryPresets: [EffectPreset] = []
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
        lock.unlock()
    }

    public func setInMemoryTemplates(_ presets: [EffectPreset]) {
        lock.lock()
        _hasSyncedFromRemote = true
        var merged = EffectPreset.systemTemplates
        for p in presets {
            if let idx = merged.firstIndex(where: { $0.id == p.id }) {
                merged[idx] = p
            } else {
                merged.append(p)
            }
        }
        inMemoryPresets = merged
        lock.unlock()
    }

    public func updateInMemoryPreset(_ preset: EffectPreset) {
        lock.lock()
        if inMemoryPresets.isEmpty {
            inMemoryPresets = EffectPreset.systemTemplates
        }
        if let idx = inMemoryPresets.firstIndex(where: { $0.id == preset.id }) {
            inMemoryPresets[idx] = preset
        } else {
            inMemoryPresets.append(preset)
        }
        lock.unlock()
    }

    public func removeInMemoryPreset(id: String) {
        lock.lock()
        inMemoryPresets.removeAll { $0.id == id && !$0.isSystem }
        lock.unlock()
    }

    public func loadAllTemplates(forceReload: Bool = false) -> [EffectPreset] {
        lock.lock()
        defer { lock.unlock() }
        if !inMemoryPresets.isEmpty {
            return inMemoryPresets
        }
        return EffectPreset.systemTemplates
    }

    @discardableResult
    public func reload() -> [EffectPreset] {
        lock.lock()
        _hasSyncedFromRemote = false
        lock.unlock()
        return loadAllTemplates(forceReload: true)
    }

    public func mergeSupabaseTemplateScripts(_ jsonPayloads: [String]) -> [EffectPreset] {
        for payload in jsonPayloads {
            guard let preset = EffectPreset.decode(from: payload) else { continue }
            updateInMemoryPreset(preset)
        }
        return loadAllTemplates(forceReload: true)
    }
}

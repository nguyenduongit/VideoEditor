import Foundation

/// Bộ nạp và quản lý các mẫu Chuyển cảnh (`TransitionPreset`) trong bộ nhớ RAM và đồng bộ Supabase.
/// Bảo toàn danh mục gốc `builtInCatalog` theo đúng thứ tự chuẩn và đồng bộ hóa `hasSyncedFromRemote` dưới `NSLock`.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R3.1 và R8.3 (Thread-safe).
public final class TransitionTemplateLoader: @unchecked Sendable {
    private let lock = NSLock()
    private var inMemoryPresets: [TransitionPreset] = []
    private var _hasSyncedFromRemote = false

    public var hasSyncedFromRemote: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasSyncedFromRemote
    }

    public init() {}

    public func setInMemoryTemplates(_ presets: [TransitionPreset]) {
        lock.lock()
        _hasSyncedFromRemote = true
        let byID = Dictionary( presets.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        let systemIDs = Set(TransitionPreset.builtInCatalog.map(\.id))

        var ordered: [TransitionPreset] = []
        ordered.reserveCapacity(TransitionPreset.builtInCatalog.count + presets.count)
        for sys in TransitionPreset.builtInCatalog {
            ordered.append(byID[sys.id] ?? sys)
        }
        for item in presets where !systemIDs.contains(item.id) && !item.isSystem {
            ordered.append(item)
        }
        inMemoryPresets = ordered
        lock.unlock()
    }

    public func updateInMemoryPreset(_ preset: TransitionPreset) {
        lock.lock()
        if inMemoryPresets.isEmpty {
            inMemoryPresets = TransitionPreset.builtInCatalog
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

    public func loadAllTemplates(forceReload: Bool = false) -> [TransitionPreset] {
        lock.lock()
        defer { lock.unlock() }
        if _hasSyncedFromRemote || !inMemoryPresets.isEmpty {
            return inMemoryPresets
        }
        return TransitionPreset.builtInCatalog
    }

    @discardableResult
    public func reload() -> [TransitionPreset] {
        lock.lock()
        _hasSyncedFromRemote = false
        lock.unlock()
        return loadAllTemplates(forceReload: true)
    }

    public func mergeJSONPayloads(_ jsonPayloads: [String]) -> [TransitionPreset] {
        for payload in jsonPayloads {
            guard let preset = TransitionPreset.decode(from: payload) else { continue }
            updateInMemoryPreset(preset)
        }
        return loadAllTemplates(forceReload: true)
    }
}

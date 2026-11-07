import Foundation

/// Bộ nạp và quản lý danh sách Mẫu Nhãn dán (Sticker Presets — SVG, PNG, GIF, APNG) trong bộ nhớ RAM và từ Supabase.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R3.1 và R8.3 (NSLock bảo vệ toàn bộ biến chia sẻ).
public final class StickerTemplateLoader: @unchecked Sendable {
    private let lock = NSLock()
    private var inMemoryPresets: [StickerPreset] = []
    private var _hasSyncedFromRemote = false

    public var hasSyncedFromRemote: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasSyncedFromRemote
    }

    public init() {}

    public func setInMemoryTemplates(_ presets: [StickerPreset]) {
        lock.lock()
        defer { lock.unlock() }
        _hasSyncedFromRemote = true
        var mergedByID: [String: StickerPreset] = [:]
        for sys in StickerPreset.builtInCatalog {
            mergedByID[sys.id] = sys
        }
        for remote in presets {
            mergedByID[remote.id] = remote
        }
        let orderedIDs = StickerPreset.builtInCatalog.map(\.id)
            + presets.map(\.id).filter { id in !StickerPreset.builtInCatalog.contains(where: { $0.id == id }) }
        inMemoryPresets = orderedIDs.compactMap { mergedByID[$0] }
    }

    public func updateInMemoryPreset(_ preset: StickerPreset) {
        lock.lock()
        defer { lock.unlock() }
        if inMemoryPresets.isEmpty {
            inMemoryPresets = StickerPreset.builtInCatalog
        }
        if let idx = inMemoryPresets.firstIndex(where: { $0.id == preset.id }) {
            inMemoryPresets[idx] = preset
        } else {
            inMemoryPresets.append(preset)
        }
    }

    public func removeInMemoryPreset(id: String) {
        lock.lock()
        defer { lock.unlock() }
        inMemoryPresets.removeAll { $0.id == id }
    }

    public func loadAllTemplates(forceReload: Bool = false) -> [StickerPreset] {
        lock.lock()
        defer { lock.unlock() }
        if !inMemoryPresets.isEmpty {
            return inMemoryPresets
        }
        return StickerPreset.builtInCatalog
    }

    @discardableResult
    public func reload() -> [StickerPreset] {
        lock.lock()
        _hasSyncedFromRemote = false
        lock.unlock()
        return loadAllTemplates(forceReload: true)
    }

    public func mergeJSONPayloads(_ jsonPayloads: [String]) -> [StickerPreset] {
        for payload in jsonPayloads {
            guard let preset = StickerPreset.decode(from: payload) else { continue }
            updateInMemoryPreset(preset)
        }
        return loadAllTemplates(forceReload: true)
    }
}

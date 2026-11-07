import Foundation

/// Bộ nạp và đồng bộ các gói hoạt ảnh sáng tạo mở (Animation Presets) trực tuyến từ Supabase và bộ nhớ đệm RAM.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class AnimationTemplateLoader: @unchecked Sendable {

    private let lock = NSLock()
    private var inMemoryPresets: [AnimationPreset] = []
    private var _hasSyncedFromRemote = false

    public var hasSyncedFromRemote: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasSyncedFromRemote
    }

    public init() {}

    /// Đặt lại trạng thái đồng bộ (phục vụ unit test)
    public func resetSyncState() {
        lock.lock()
        _hasSyncedFromRemote = false
        inMemoryPresets = []
        lock.unlock()
    }

    /// Cập nhật toàn bộ danh sách presets trên RAM (nhận từ Supabase API), luôn đảm bảo các mẫu hệ thống có mặt
    public func setInMemoryTemplates(_ presets: [AnimationPreset]) {
        lock.lock()
        _hasSyncedFromRemote = true
        var merged = AnimationPreset.systemTemplates
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

    /// Thêm mới hoặc cập nhật 1 preset trên RAM
    public func updateInMemoryPreset(_ preset: AnimationPreset) {
        lock.lock()
        if inMemoryPresets.isEmpty {
            inMemoryPresets = AnimationPreset.systemTemplates
        }
        if let idx = inMemoryPresets.firstIndex(where: { $0.id == preset.id }) {
            inMemoryPresets[idx] = preset
        } else {
            inMemoryPresets.append(preset)
        }
        lock.unlock()
    }

    /// Xóa 1 preset khỏi RAM
    public func removeInMemoryPreset(id: String) {
        lock.lock()
        inMemoryPresets.removeAll { $0.id == id && !$0.isSystem }
        lock.unlock()
    }

    /// Nạp toàn bộ danh sách AnimationPreset từ RAM đã đồng bộ với Supabase hoặc fallback mặc định
    public func loadAllTemplates(forceReload: Bool = false) -> [AnimationPreset] {
        lock.lock()
        defer { lock.unlock() }
        if !inMemoryPresets.isEmpty {
            return inMemoryPresets
        }
        return AnimationPreset.systemTemplates
    }

    /// Nạp các gói Animation lọc theo pha (In / Out / Loop)
    public func loadTemplates(for phase: AnimationPhaseCategory) -> [AnimationPreset] {
        loadAllTemplates().filter { $0.phase == phase }
    }

    /// Xóa bộ nhớ đệm và nạp lại
    @discardableResult
    public func reload() -> [AnimationPreset] {
        lock.lock()
        _hasSyncedFromRemote = false
        lock.unlock()
        return loadAllTemplates(forceReload: true)
    }
}


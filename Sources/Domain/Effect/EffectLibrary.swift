import Foundation

/// Dev-authored local Effects System Library provider (`EffectLibraryItem`).
/// Read-only to end users per AGENTS.md Article 15; supports in-session registration strictly for dev/MCP runtime usage.
/// Thread-safety is guaranteed via an internal `NSLock`.
public final class EffectLibrary: @unchecked Sendable {
    private let lock = NSLock()
    private var runtimeItems: [EffectLibraryItem] = []

    public init() {}

    /// Returns all built-in system effects plus any dev/MCP runtime items registered for the current session.
    public func loadAllItems() -> [EffectLibraryItem] {
        lock.lock()
        defer { lock.unlock() }
        if runtimeItems.isEmpty {
            return EffectLibraryItem.systemItems
        }
        return EffectLibraryItem.systemItems + runtimeItems
    }

    public func item(withID id: String) -> EffectLibraryItem? {
        loadAllItems().first { $0.id == id }
    }

    /// Registers or updates an effect item in memory for the current dev/MCP session only (never persisted).
    public func registerRuntimeItem(_ item: EffectLibraryItem) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = runtimeItems.firstIndex(where: { $0.id == item.id }) {
            runtimeItems[idx] = item
        } else {
            runtimeItems.append(item)
        }
    }
}

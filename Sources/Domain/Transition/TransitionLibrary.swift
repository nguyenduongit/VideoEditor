import Foundation

/// Dev-authored local Transitions System Library provider (`TransitionLibraryItem`).
/// Read-only to end users per AGENTS.md Article 15; supports in-session registration strictly for dev/MCP runtime usage.
/// Thread-safety is guaranteed via an internal `NSLock`.
public final class TransitionLibrary: @unchecked Sendable {
    private let lock = NSLock()
    private var runtimeItems: [TransitionLibraryItem] = []

    public init() {}

    /// Returns all 83 built-in system transitions plus any dev/MCP runtime items registered for the current session.
    public func loadAllItems() -> [TransitionLibraryItem] {
        lock.lock()
        defer { lock.unlock() }
        if runtimeItems.isEmpty {
            return TransitionLibraryItem.systemItems
        }
        return TransitionLibraryItem.systemItems + runtimeItems
    }

    public func item(withID id: String) -> TransitionLibraryItem? {
        loadAllItems().first { $0.id == id }
    }

    /// Registers or updates a transition item in memory for the current dev/MCP session only (never persisted).
    public func registerRuntimeItem(_ item: TransitionLibraryItem) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = runtimeItems.firstIndex(where: { $0.id == item.id }) {
            runtimeItems[idx] = item
        } else {
            runtimeItems.append(item)
        }
    }
}

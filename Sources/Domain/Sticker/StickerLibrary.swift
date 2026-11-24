import Foundation

/// Dev-authored local Stickers System Library provider (`StickerLibraryItem`).
/// Read-only to end users per AGENTS.md Article 15; supports in-session registration strictly for dev/MCP runtime usage.
/// Thread-safety is guaranteed via an internal `NSLock`.
public final class StickerLibrary: @unchecked Sendable {
    private let lock = NSLock()
    private var runtimeItems: [StickerLibraryItem] = []

    public init() {}

    /// Returns all built-in system stickers plus any dev/MCP runtime items registered for the current session.
    public func loadAllItems() -> [StickerLibraryItem] {
        lock.lock()
        defer { lock.unlock() }
        if runtimeItems.isEmpty {
            return StickerLibraryItem.systemItems
        }
        return StickerLibraryItem.systemItems + runtimeItems
    }

    public func item(withID id: String) -> StickerLibraryItem? {
        loadAllItems().first { $0.id == id }
    }

    /// Registers or updates a sticker item in memory for the current dev/MCP session only (never persisted).
    public func registerRuntimeItem(_ item: StickerLibraryItem) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = runtimeItems.firstIndex(where: { $0.id == item.id }) {
            runtimeItems[idx] = item
        } else {
            runtimeItems.append(item)
        }
    }
}

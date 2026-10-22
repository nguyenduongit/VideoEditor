import Foundation

/// A thread-safe, bounded Least-Recently-Used (LRU) in-memory cache.
/// When the cache reaches its capacity, the oldest unread/unwritten item is automatically evicted.
/// Optionally listens for `Notification.Name.appDidReceiveMemoryWarning` to purge all cached data.
public final class LRUCache<Key: Hashable, Value>: @unchecked Sendable {
    private final class Node {
        let key: Key
        var value: Value
        weak var prev: Node?
        var next: Node?

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    public let capacity: Int
    private let lock = NSLock()
    private var map: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private var memoryObserver: (any NSObjectProtocol)?

    public init(capacity: Int, clearOnMemoryWarning: Bool = true) {
        self.capacity = max(1, capacity)
        if clearOnMemoryWarning {
            self.memoryObserver = NotificationCenter.default.addObserver(
                forName: .appDidReceiveMemoryWarning,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.removeAll()
            }
        }
    }

    deinit {
        if let memoryObserver {
            NotificationCenter.default.removeObserver(memoryObserver)
        }
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return map.count
    }

    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = map[key] else { return nil }
        moveToHead(node)
        return node.value
    }

    public func set(_ value: Value, for key: Key) {
        lock.lock()
        defer { lock.unlock() }

        if let existing = map[key] {
            existing.value = value
            moveToHead(existing)
            return
        }

        let newNode = Node(key: key, value: value)
        map[key] = newNode
        insertAtHead(newNode)

        if map.count > capacity, let oldest = tail {
            removeNode(oldest)
            map.removeValue(forKey: oldest.key)
        }
    }

    @discardableResult
    public func remove(for key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = map.removeValue(forKey: key) else { return nil }
        removeNode(node)
        return node.value
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        map.removeAll()
        head = nil
        tail = nil
    }

    public subscript(key: Key) -> Value? {
        get { get(key) }
        set {
            if let newValue {
                set(newValue, for: key)
            } else {
                _ = remove(for: key)
            }
        }
    }

    // MARK: - Linked List Operations (Must be called within lock)

    private func insertAtHead(_ node: Node) {
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func removeNode(_ node: Node) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }

        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }

        node.prev = nil
        node.next = nil
    }

    private func moveToHead(_ node: Node) {
        guard head !== node else { return }
        removeNode(node)
        insertAtHead(node)
    }
}

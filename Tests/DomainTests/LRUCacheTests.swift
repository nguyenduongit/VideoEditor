import Testing
import Foundation
@testable import Domain

@Suite("LRUCacheTests", .serialized)
struct LRUCacheTests {
    @Test("Basic set, get and subscript operations")
    func testBasicSetAndGet() {
        let cache = LRUCache<String, Int>(capacity: 3, clearOnMemoryWarning: false)
        #expect(cache.count == 0)

        cache.set(100, for: "A")
        cache["B"] = 200

        #expect(cache.count == 2)
        #expect(cache.get("A") == 100)
        #expect(cache["B"] == 200)
        #expect(cache.get("C") == nil)
    }

    @Test("Eviction occurs strictly in LRU order when capacity exceeded")
    func testEvictionWhenCapacityExceeded() {
        let cache = LRUCache<String, String>(capacity: 3, clearOnMemoryWarning: false)

        cache.set("valA", for: "A")
        cache.set("valB", for: "B")
        cache.set("valC", for: "C")
        #expect(cache.count == 3)

        // Adding 4th item evicts oldest item ("A")
        cache.set("valD", for: "D")
        #expect(cache.count == 3)
        #expect(cache.get("A") == nil)
        #expect(cache.get("B") == "valB")
        #expect(cache.get("C") == "valC")
        #expect(cache.get("D") == "valD")
    }

    @Test("Accessing an item promotes it to MRU, protecting it from immediate eviction")
    func testAccessOrderPromotion() {
        let cache = LRUCache<String, String>(capacity: 3)

        cache.set("valA", for: "A")
        cache.set("valB", for: "B")
        cache.set("valC", for: "C")

        // Access "A" -> order becomes: A (MRU), C, B (LRU)
        _ = cache.get("A")

        // Inserting "D" should evict "B", NOT "A"
        cache.set("valD", for: "D")

        #expect(cache.get("A") == "valA")
        #expect(cache.get("B") == nil)
        #expect(cache.get("C") == "valC")
        #expect(cache.get("D") == "valD")
    }

    @Test("Updating existing key updates value without altering capacity count")
    func testUpdateExistingKey() {
        let cache = LRUCache<String, Int>(capacity: 2)

        cache.set(1, for: "X")
        cache.set(2, for: "Y")
        #expect(cache.count == 2)

        cache.set(999, for: "X")
        #expect(cache.count == 2)
        #expect(cache.get("X") == 999)
    }

    @Test("Remove item and removeAll operations")
    func testRemoveAndRemoveAll() {
        let cache = LRUCache<String, Int>(capacity: 3)

        cache.set(10, for: "K1")
        cache.set(20, for: "K2")

        let removed = cache.remove(for: "K1")
        #expect(removed == 10)
        #expect(cache.get("K1") == nil)
        #expect(cache.count == 1)

        cache.removeAll()
        #expect(cache.count == 0)
        #expect(cache.get("K2") == nil)
    }

    @Test("Memory pressure notification purges all items")
    func testMemoryPressureNotificationPurgesCache() {
        let cache = LRUCache<String, String>(capacity: 10, clearOnMemoryWarning: true)

        cache.set("one", for: "1")
        cache.set("two", for: "2")
        #expect(cache.count == 2)

        NotificationCenter.default.post(
            name: .appDidReceiveMemoryWarning,
            object: nil
        )

        #expect(cache.count == 0)
        #expect(cache.get("1") == nil)
    }

    @Test("Concurrent reads and writes do not crash or race")
    func testConcurrentAccess() async {
        let cache = LRUCache<Int, Int>(capacity: 50)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    cache.set(i * 10, for: i)
                    _ = cache.get(i)
                }
            }
        }

        #expect(cache.count <= 50)
    }
}

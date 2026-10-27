import Foundation

/// Registry providing property descriptors for each clip kind.
/// Complies with R5.1 & R6.1 of AGENTS.md: Inspector looks up descriptors through this registry.
/// An toàn luồng được bảo vệ bởi NSLock nội bộ theo quy tắc R8.3 của AGENTS.md.
public final class ClipPropertyRegistry: @unchecked Sendable {

    private var storage: [ClipKind: [PropertyDescriptor]] = [:]
    private var tabsStorage: [ClipKind: [String]] = [:]
    private let lock = NSLock()

    public init() {
        registerBuiltInDescriptors()
    }

    public func register(descriptors: [PropertyDescriptor], for kind: ClipKind, tabs: [String]? = nil) {
        lock.lock()
        defer { lock.unlock() }
        storage[kind] = descriptors
        if let tabs {
            tabsStorage[kind] = tabs
        }
    }

    public func descriptors(for kind: ClipKind) -> [PropertyDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return storage[kind] ?? []
    }

    public func tabs(for kind: ClipKind) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if let custom = tabsStorage[kind] {
            return custom
        }
        let all = storage[kind] ?? []
        var seen = Set<String>()
        var tabsList: [String] = []
        for d in all {
            if !seen.contains(d.tab) {
                seen.insert(d.tab)
                tabsList.append(d.tab)
            }
        }
        return tabsList.isEmpty ? ["Video"] : tabsList
    }

    public func descriptors(for kind: ClipKind, tab: String) -> [PropertyDescriptor] {
        descriptors(for: kind).filter { $0.tab.caseInsensitiveCompare(tab) == .orderedSame }
    }

    public func defaultProperties(for kind: ClipKind) -> [String: PropertyValue] {
        let descList = descriptors(for: kind)
        var dict: [String: PropertyValue] = [:]
        for desc in descList {
            dict[desc.id] = desc.defaultValue
            if case .position2D(let xID, let yID, _) = desc.control {
                dict[xID] = .number(0.0)
                dict[yID] = .number(0.0)
            }
        }
        return dict
    }
}

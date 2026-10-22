import SwiftUI
import Observation
import Domain

@Observable
@MainActor
public final class TabRegistry {
    private var descriptors: [TabID: any TabDescriptor] = [:]
    public private(set) var tabs: [any TabDescriptor] = []

    public init() {}

    public func register(_ descriptor: any TabDescriptor) {
        descriptors[descriptor.id] = descriptor
        tabs = descriptors.values.sorted { $0.order < $1.order }
    }

    public func descriptor(for id: TabID) -> (any TabDescriptor)? {
        descriptors[id]
    }

    public func sidebarView(for id: TabID) -> AnyView? {
        descriptors[id]?.makeSidebarView()
    }
}

import SwiftUI
import Domain

@MainActor
public protocol TabDescriptor: Sendable, Identifiable {
    var id: TabID { get }
    var title: String { get }
    var iconName: String { get }
    var isSoon: Bool { get }
    var order: Int { get }
    func makeSidebarView() -> AnyView
    func makeSidebarTrailingAccessory() -> AnyView?
}

public extension TabDescriptor {
    var iconName: String {
        "square"
    }

    var isSoon: Bool {
        false
    }

    func makeSidebarTrailingAccessory() -> AnyView? {
        nil
    }
}

import SwiftUI
import Domain

@MainActor
public protocol TabDescriptor: Sendable, Identifiable {
    var id: TabID { get }
    var title: String { get }
    var order: Int { get }
    func makeSidebarView() -> AnyView
    func makeSidebarTrailingAccessory() -> AnyView?
}

public extension TabDescriptor {
    func makeSidebarTrailingAccessory() -> AnyView? {
        nil
    }
}

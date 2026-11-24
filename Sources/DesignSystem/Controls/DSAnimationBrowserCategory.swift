import Foundation

/// Lightweight category descriptor displayed in the left sidebar of `DSAnimationScriptBrowser`.
public struct DSAnimationBrowserCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let count: Int

    public init(id: String, title: String, count: Int) {
        self.id = id
        self.title = title
        self.count = count
    }
}

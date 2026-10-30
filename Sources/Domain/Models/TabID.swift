import Foundation

public struct TabID: Hashable, Sendable, Identifiable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var id: String {
        rawValue
    }

    public var description: String {
        rawValue
    }

    public static let media = TabID(rawValue: "media")
    public static let library = TabID(rawValue: "library")
    public static let audio = TabID(rawValue: "audio")
    public static let text = TabID(rawValue: "text")
    public static let adjustment = TabID(rawValue: "adjustment")
    public static let effect = TabID(rawValue: "effect")
}

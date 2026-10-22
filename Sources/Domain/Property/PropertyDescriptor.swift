import Foundation

/// Describes the UI control kind used to edit a property in the Inspector.
public enum PropertyControlKind: Sendable, Equatable {
    case slider(min: Double, max: Double, step: Double, unit: String? = nil)
    case numberField(min: Double?, max: Double?, step: Double?, unit: String? = nil, prefix: String? = nil)
    case position2D(xID: String = "positionX", yID: String = "positionY", step: Double = 1.0)
    case rotation(min: Double = -360.0, max: Double = 360.0, step: Double = 0.1)
    case toggle
    case textField
    case picker(options: [PickerOption])
}

/// An option item for picker controls.
public struct PickerOption: Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let iconName: String?

    public init(id: String, title: String, iconName: String? = nil) {
        self.id = id
        self.title = title
        self.iconName = iconName
    }
}

/// A declarative condition for conditional property visibility.
public struct PropertyCondition: Sendable, Equatable {
    public let key: String
    public let matchesOneOf: [PropertyValue]

    public init(key: String, matchesOneOf: [PropertyValue]) {
        self.key = key
        self.matchesOneOf = matchesOneOf
    }

    public func isSatisfied(by properties: [String: PropertyValue]) -> Bool {
        guard let current = properties[key] else { return false }
        return matchesOneOf.contains(current)
    }
}

/// Metadata descriptor declaring an editable property on a timeline clip.
/// Complies with R6.1 of AGENTS.md: Inspector builds controls dynamically from descriptors.
public struct PropertyDescriptor: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let tab: String
    public let group: String
    public let control: PropertyControlKind
    public let defaultValue: PropertyValue
    public let condition: PropertyCondition?

    public init(
        id: String,
        title: String,
        tab: String = "General",
        group: String,
        control: PropertyControlKind,
        defaultValue: PropertyValue,
        condition: PropertyCondition? = nil
    ) {
        self.id = id
        self.title = title
        self.tab = tab
        self.group = group
        self.control = control
        self.defaultValue = defaultValue
        self.condition = condition
    }
}

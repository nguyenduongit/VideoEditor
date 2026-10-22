import Foundation

/// Represents a single recorded user or agent action on the timeline.
/// Stores both the forward command and its inverse for persistent undo/redo and time-travel history.
public struct TimelineHistoryRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let title: String
    public let command: TimelineCommand
    public let inverse: TimelineCommand

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        title: String? = nil,
        command: TimelineCommand,
        inverse: TimelineCommand
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title ?? command.defaultTitle
        self.command = command
        self.inverse = inverse
    }
}

extension TimelineCommand {
    public var defaultTitle: String {
        switch self {
        case .addClip:
            return "Add Clip"
        case .removeClip:
            return "Delete Clip"
        case .moveClip:
            return "Move Clip"
        case .trimClip:
            return "Trim Clip"
        case .splitClip:
            return "Split Clip"
        case .updateClipProperties:
            return "Update Properties"
        case .setLayerStatus:
            return "Set Layer Status"
        case .setAspectRatio:
            return "Change Aspect Ratio"
        case .batch:
            return "Batch Action"
        }
    }
}

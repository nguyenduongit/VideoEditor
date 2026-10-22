import Foundation

/// Pure domain representation of a mutation command on the timeline.
/// Conforms to Codable and Sendable, allowing script execution, project undo/redo, and MCP agent remote dispatch.
public enum TimelineCommand: Codable, Sendable, Equatable {
    case addClip(layerID: UUID, clip: ClipScript)
    case removeClip(clipID: UUID)
    case moveClip(clipID: UUID, targetLayerID: UUID, newStartTime: RationalTime)
    case trimClip(clipID: UUID, newStart: RationalTime, newDuration: RationalTime, newSourceStart: RationalTime?)
    case splitClip(clipID: UUID, atTime: RationalTime, newRightClipID: UUID? = nil)
    case updateClipProperties(clipID: UUID, properties: [String: PropertyValue])
    case setLayerStatus(layerID: UUID, isLocked: Bool?, isHidden: Bool?, isMuted: Bool?)
    case setAspectRatio(CanvasAspectRatio)
    case batch(commands: [TimelineCommand])

    private enum CodingKeys: String, CodingKey {
        case action
        case payload
    }

    private enum Action: String, Codable {
        case addClip
        case removeClip
        case moveClip
        case trimClip
        case splitClip
        case updateClipProperties
        case setLayerStatus
        case setAspectRatio
        case batch
    }

    private struct AddClipPayload: Codable {
        let layerID: UUID
        let clip: ClipScript
    }

    private struct RemoveClipPayload: Codable {
        let clipID: UUID
    }

    private struct MoveClipPayload: Codable {
        let clipID: UUID
        let targetLayerID: UUID
        let newStartTime: RationalTime
    }

    private struct TrimClipPayload: Codable {
        let clipID: UUID
        let newStart: RationalTime
        let newDuration: RationalTime
        let newSourceStart: RationalTime?
    }

    private struct SplitClipPayload: Codable {
        let clipID: UUID
        let atTime: RationalTime
        let newRightClipID: UUID?

        init(clipID: UUID, atTime: RationalTime, newRightClipID: UUID? = nil) {
            self.clipID = clipID
            self.atTime = atTime
            self.newRightClipID = newRightClipID
        }

        private enum CodingKeys: String, CodingKey {
            case clipID, atTime, newRightClipID
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.clipID = try container.decode(UUID.self, forKey: .clipID)
            self.atTime = try container.decode(RationalTime.self, forKey: .atTime)
            self.newRightClipID = try container.decodeIfPresent(UUID.self, forKey: .newRightClipID)
        }
    }

    private struct UpdateClipPropertiesPayload: Codable {
        let clipID: UUID
        let properties: [String: PropertyValue]
    }

    private struct LayerStatusPayload: Codable {
        let layerID: UUID
        let isLocked: Bool?
        let isHidden: Bool?
        let isMuted: Bool?
    }

    private struct SetAspectRatioPayload: Codable {
        let aspectRatio: CanvasAspectRatio
    }

    private struct BatchPayload: Codable {
        let commands: [TimelineCommand]
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(Action.self, forKey: .action)
        switch action {
        case .addClip:
            let p = try container.decode(AddClipPayload.self, forKey: .payload)
            self = .addClip(layerID: p.layerID, clip: p.clip)
        case .removeClip:
            let p = try container.decode(RemoveClipPayload.self, forKey: .payload)
            self = .removeClip(clipID: p.clipID)
        case .moveClip:
            let p = try container.decode(MoveClipPayload.self, forKey: .payload)
            self = .moveClip(clipID: p.clipID, targetLayerID: p.targetLayerID, newStartTime: p.newStartTime)
        case .trimClip:
            let p = try container.decode(TrimClipPayload.self, forKey: .payload)
            self = .trimClip(clipID: p.clipID, newStart: p.newStart, newDuration: p.newDuration, newSourceStart: p.newSourceStart)
        case .splitClip:
            let p = try container.decode(SplitClipPayload.self, forKey: .payload)
            self = .splitClip(clipID: p.clipID, atTime: p.atTime, newRightClipID: p.newRightClipID)
        case .updateClipProperties:
            let p = try container.decode(UpdateClipPropertiesPayload.self, forKey: .payload)
            self = .updateClipProperties(clipID: p.clipID, properties: p.properties)
        case .setLayerStatus:
            let p = try container.decode(LayerStatusPayload.self, forKey: .payload)
            self = .setLayerStatus(layerID: p.layerID, isLocked: p.isLocked, isHidden: p.isHidden, isMuted: p.isMuted)
        case .setAspectRatio:
            let p = try container.decode(SetAspectRatioPayload.self, forKey: .payload)
            self = .setAspectRatio(p.aspectRatio)
        case .batch:
            let p = try container.decode(BatchPayload.self, forKey: .payload)
            self = .batch(commands: p.commands)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .addClip(let layerID, let clip):
            try container.encode(Action.addClip, forKey: .action)
            try container.encode(AddClipPayload(layerID: layerID, clip: clip), forKey: .payload)
        case .removeClip(let clipID):
            try container.encode(Action.removeClip, forKey: .action)
            try container.encode(RemoveClipPayload(clipID: clipID), forKey: .payload)
        case .moveClip(let clipID, let targetLayerID, let newStartTime):
            try container.encode(Action.moveClip, forKey: .action)
            try container.encode(MoveClipPayload(clipID: clipID, targetLayerID: targetLayerID, newStartTime: newStartTime), forKey: .payload)
        case .trimClip(let clipID, let newStart, let newDuration, let newSourceStart):
            try container.encode(Action.trimClip, forKey: .action)
            try container.encode(TrimClipPayload(clipID: clipID, newStart: newStart, newDuration: newDuration, newSourceStart: newSourceStart), forKey: .payload)
        case .splitClip(let clipID, let atTime, let newRightClipID):
            try container.encode(Action.splitClip, forKey: .action)
            try container.encode(SplitClipPayload(clipID: clipID, atTime: atTime, newRightClipID: newRightClipID), forKey: .payload)
        case .updateClipProperties(let clipID, let properties):
            try container.encode(Action.updateClipProperties, forKey: .action)
            try container.encode(UpdateClipPropertiesPayload(clipID: clipID, properties: properties), forKey: .payload)
        case .setLayerStatus(let layerID, let isLocked, let isHidden, let isMuted):
            try container.encode(Action.setLayerStatus, forKey: .action)
            try container.encode(LayerStatusPayload(layerID: layerID, isLocked: isLocked, isHidden: isHidden, isMuted: isMuted), forKey: .payload)
        case .setAspectRatio(let aspectRatio):
            try container.encode(Action.setAspectRatio, forKey: .action)
            try container.encode(SetAspectRatioPayload(aspectRatio: aspectRatio), forKey: .payload)
        case .batch(let commands):
            try container.encode(Action.batch, forKey: .action)
            try container.encode(BatchPayload(commands: commands), forKey: .payload)
        }
    }
}

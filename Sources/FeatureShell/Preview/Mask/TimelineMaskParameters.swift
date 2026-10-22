import Foundation
import CoreGraphics
import Domain

/// Supported mask shapes for clip rendering.
public enum MaskShape: String, Sendable, Equatable {
    case none = "none"
    case split = "split"
    case filmstrip = "filmstrip"
    case circle = "circle"
    case rectangle = "rectangle"
}

/// Encapsulates the visual mask parameters configured on a timeline clip.
/// Complies with R4.1 and R6.1 of AGENTS.md.
public struct TimelineMaskParameters: Sendable, Equatable {
    public let shape: MaskShape
    public let invert: Bool
    public let feather: Double
    public let positionX: Double
    public let positionY: Double
    public let rotation: Double
    public let radiusX: Double
    public let radiusY: Double
    public let width: Double
    public let height: Double
    public let cornerRadius: Double
    public let offsetY: Double
    public let filmHeight: Double

    public init(
        shape: MaskShape,
        invert: Bool = false,
        feather: Double = 0.0,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        rotation: Double = 0.0,
        radiusX: Double = 200.0,
        radiusY: Double = 200.0,
        width: Double = 400.0,
        height: Double = 300.0,
        cornerRadius: Double = 0.0,
        offsetY: Double = 0.0,
        filmHeight: Double = 500.0
    ) {
        self.shape = shape
        self.invert = invert
        self.feather = feather > 1.0 ? min(feather / 100.0, 1.0) : max(0.0, feather)
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.radiusX = radiusX
        self.radiusY = radiusY
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.offsetY = offsetY
        self.filmHeight = filmHeight
    }

    public var isMaskActive: Bool {
        shape != .none
    }

    /// Extracts mask parameters from clip's raw property map.
    public static func extract(from properties: [String: PropertyValue]) -> TimelineMaskParameters {
        let typeStr = properties["maskType"]?.asString ?? "none"
        let shape = MaskShape(rawValue: typeStr) ?? .none
        let invert = properties["maskInvert"]?.asBool ?? false
        let rawFeather = properties["maskFeather"]?.asNumber ?? 0.0
        let feather = rawFeather > 1.0 ? min(rawFeather / 100.0, 1.0) : max(0.0, rawFeather)

        switch shape {
        case .none:
            return TimelineMaskParameters(shape: .none)
        case .split:
            let posX = properties["maskPositionX"]?.asNumber ?? 0.0
            let posY = properties["maskPositionY"]?.asNumber ?? 0.0
            let rot = properties["maskRotation"]?.asNumber ?? 0.0
            return TimelineMaskParameters(
                shape: .split, invert: invert, feather: feather,
                positionX: posX, positionY: posY, rotation: rot
            )
        case .filmstrip:
            let offY = properties["maskOffsetY"]?.asNumber ?? 0.0
            let fh = properties["maskFilmHeight"]?.asNumber ?? 500.0
            return TimelineMaskParameters(
                shape: .filmstrip, invert: invert, feather: feather,
                offsetY: offY, filmHeight: fh
            )
        case .circle:
            let posX = properties["maskPositionX"]?.asNumber ?? 0.0
            let posY = properties["maskPositionY"]?.asNumber ?? 0.0
            let rot = properties["maskRotation"]?.asNumber ?? 0.0
            let radX = properties["maskRadiusX"]?.asNumber ?? 200.0
            let radY = properties["maskRadiusY"]?.asNumber ?? 200.0
            return TimelineMaskParameters(
                shape: .circle, invert: invert, feather: feather,
                positionX: posX, positionY: posY, rotation: rot,
                radiusX: radX, radiusY: radY
            )
        case .rectangle:
            let posX = properties["maskPositionX"]?.asNumber ?? 0.0
            let posY = properties["maskPositionY"]?.asNumber ?? 0.0
            let rot = properties["maskRotation"]?.asNumber ?? 0.0
            let w = properties["maskWidth"]?.asNumber ?? 400.0
            let h = properties["maskHeight"]?.asNumber ?? 300.0
            let cr = properties["maskCornerRadius"]?.asNumber ?? 0.0
            return TimelineMaskParameters(
                shape: .rectangle, invert: invert, feather: feather,
                positionX: posX, positionY: posY, rotation: rot,
                width: w, height: h, cornerRadius: cr
            )
        }
    }
}

import Foundation

/// Geometric reveal mask shapes supported by both block-level and per-unit text renderers.
public enum TextMaskShapeMode: String, Codable, Sendable, Equatable, CaseIterable {
    case rect
    case centerSplitX
    case centerSplitY
    case diagonalSlash
    case irisCircle
}

import Foundation

/// Pure-geometric GPU mesh distortion modes preserving 100% of Appearance fill & stroke colors.
public enum TextMeshWarpMode: String, Codable, Hashable, Sendable, CaseIterable {
    case none
    case bend
    case twist
    case waveRibbon
    case lensBulge

    public var shaderIndex: Int {
        switch self {
        case .none: return 0
        case .bend: return 1
        case .twist: return 2
        case .waveRibbon: return 3
        case .lensBulge: return 4
        }
    }
}

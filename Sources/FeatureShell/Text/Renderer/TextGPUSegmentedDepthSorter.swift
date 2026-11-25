import Foundation
import CoreGraphics
import Domain

/// Computes effective 3D Z-depth and stable back-to-front draw order for segmented text units.
internal enum TextGPUSegmentedDepthSorter: Sendable {
    struct DepthEntry {
        let orderIndex: Int
        let tokenIndex: Int
        let evaluated: TextAnimationEvaluator.EvaluationResult
        let curveCenter: CGPoint
        let depthZ: Double
        let depthScale: CGFloat
    }

    static func effectiveDepthZ(
        evaluated: TextAnimationEvaluator.EvaluationResult,
        curveCenter: CGPoint,
        baseConfig: TextConfiguration
    ) -> Double {
        let em = max(16.0, baseConfig.fontSize)
        let relX = Double(curveCenter.x) + evaluated.config.positionX
        let relY = Double(curveCenter.y) - evaluated.config.positionY
        let yawRad = (evaluated.overlay.rotationY * .pi / 180.0) + evaluated.overlay.perspectiveY * 0.95
        let pitchRad = (evaluated.overlay.rotationX * .pi / 180.0) + evaluated.overlay.perspectiveX * 0.95
        let tiltDepth = relX * sin(yawRad) - relY * sin(pitchRad)
        return evaluated.overlay.offsetZEm * em + tiltDepth
    }

    static func perspectiveDepthScale(offsetZEm: Double) -> CGFloat {
        guard abs(offsetZEm) > 0.001 else { return 1.0 }
        let camUnits = 6.5
        let factor = camUnits / max(1.8, camUnits - offsetZEm)
        return CGFloat(max(0.35, min(2.2, factor)))
    }

    static func sortedBackToFront(_ entries: [DepthEntry]) -> [DepthEntry] {
        entries.sorted { lhs, rhs in
            if abs(lhs.depthZ - rhs.depthZ) > 0.01 {
                return lhs.depthZ < rhs.depthZ
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }
}

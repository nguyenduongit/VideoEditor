import Foundation
import CoreGraphics
import Domain

/// Shared 2D pivot calculation ensuring identical anchor behavior across GPU and CPU renderers.
internal enum TextUnitPivotHelper: Sendable {
    static func pivotOffset(for anchor: TextAnchorPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(anchor.x) * (width * 0.5),
            y: CGFloat(anchor.y) * (height * 0.5)
        )
    }
}

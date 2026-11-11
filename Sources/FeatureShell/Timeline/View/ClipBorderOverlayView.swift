import SwiftUI
import Domain
import DesignSystem

public struct ClipBorderOverlayView: View {
    private let isSelected: Bool
    private let isHoveringLeftTrim: Bool
    private let isHoveringRightTrim: Bool

    public init(
        isSelected: Bool,
        isHoveringLeftTrim: Bool,
        isHoveringRightTrim: Bool
    ) {
        self.isSelected = isSelected
        self.isHoveringLeftTrim = isHoveringLeftTrim
        self.isHoveringRightTrim = isHoveringRightTrim
    }

    @ViewBuilder
    public var body: some View {
        if isSelected {
            let baseLineWidth: CGFloat = 1.5
            let baseStrokeColor: Color = Color.white
            let endCapWidth: CGFloat = 3.5
            let leftCapColor: Color = isHoveringLeftTrim ? Color.white : Color.white.opacity(0.85)
            let rightCapColor: Color = isHoveringRightTrim ? Color.white : Color.white.opacity(0.85)

            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(leftCapColor)
                        .frame(width: endCapWidth)
                    Spacer()
                    Rectangle()
                        .fill(rightCapColor)
                        .frame(width: endCapWidth)
                }

                RoundedRectangle(cornerRadius: DSRadius.clip)
                    .stroke(baseStrokeColor, lineWidth: baseLineWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.clip))
            .allowsHitTesting(false)
        }
    }
}


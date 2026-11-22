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
        if isSelected || isHoveringLeftTrim || isHoveringRightTrim {
            let baseLineWidth: CGFloat = isSelected ? 1.5 : 1.0
            let baseStrokeColor: Color = isSelected ? Color.white : Color.white.opacity(0.45)
            let endCapWidth: CGFloat = 3.5
            let leftCapColor: Color = isHoveringLeftTrim ? Color.white : (isSelected ? Color.white.opacity(0.85) : Color.clear)
            let rightCapColor: Color = isHoveringRightTrim ? Color.white : (isSelected ? Color.white.opacity(0.85) : Color.clear)

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


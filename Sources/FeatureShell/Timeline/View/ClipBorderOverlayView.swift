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

    public var body: some View {
        let baseLineWidth: CGFloat = isSelected ? 1.5 : 1.0
        let baseStrokeColor: Color = isSelected ? Color.white : Color.white.opacity(0.25)
        let endCapWidth: CGFloat = isSelected ? 3.5 : 2.5
        let leftCapColor: Color = (isSelected || isHoveringLeftTrim) ? Color.white : Color.white.opacity(0.65)
        let rightCapColor: Color = (isSelected || isHoveringRightTrim) ? Color.white : Color.white.opacity(0.65)

        return ZStack {
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(baseStrokeColor, lineWidth: baseLineWidth)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(leftCapColor)
                    .frame(width: endCapWidth)
                Spacer()
                RoundedRectangle(cornerRadius: 1)
                    .fill(rightCapColor)
                    .frame(width: endCapWidth)
            }
        }
        .allowsHitTesting(false)
    }
}


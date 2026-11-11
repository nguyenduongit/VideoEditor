import SwiftUI
import Domain
import DesignSystem

/// Component hiển thị khối overlay chuyển cảnh màu xanh lơ (Cyan) trên Timeline track.
/// Phủ trực tiếp lên mối nối giữa 2 video clip, căn tâm đối xứng tuyệt đối tại vết cắt.
/// Tuân thủ AGENTS.md (Cấp 1 Control/Molecule, File <= 300 dòng, View body <= 40 dòng).
public struct TimelineTransitionOverlayView: View {
    private let transition: CutTransition
    private let width: CGFloat
    private let height: CGFloat
    private let isSelected: Bool
    private let onSelect: () -> Void

    public init(
        transition: CutTransition,
        width: CGFloat,
        height: CGFloat,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.transition = transition
        self.width = max(14.0, width)
        self.height = max(10.0, height)
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            ZStack {
                backgroundShape
                centerSeamDivider
                centerBadgeView
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: DSRadius.small)
            .fill(DSColors.toggleCyan.opacity(isSelected ? 0.72 : 0.50))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(
                        isSelected ? Color.white : DSColors.toggleCyan.opacity(0.85),
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
            )
            .shadow(
                color: isSelected ? Color.black.opacity(0.40) : Color.clear,
                radius: 3,
                x: 0,
                y: 1
            )
    }

    private var centerSeamDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.75))
            .frame(width: 1.0, height: height)
    }

    private var centerBadgeView: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.40))
                .frame(width: 18, height: 18)

            Image(systemName: "hourglass")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }
}


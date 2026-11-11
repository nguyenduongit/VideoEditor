import SwiftUI
import Domain
import DesignSystem

/// Bảng Inspector tinh gọn cho hiệu ứng Chuyển cảnh (`CutTransition`) giữa 2 clip:
/// Chỉ hiển thị Tên hiệu ứng và duy nhất Slider Thời lượng (Duration) tăng giảm realtime.
/// Tuân thủ AGENTS.md (Cấp 3 Screen/Inspector View, File <= 300 dòng, View body <= 40 dòng).
public struct TransitionInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            if let transition = viewModel.selectedTransition {
                headerSection(transition)
                durationSection(transition)
            } else {
                emptyView
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private func headerSection(_ transition: CutTransition) -> some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .fill(DSColors.toggleCyan.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "hourglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DSColors.toggleCyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transition.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                Text("Hiệu ứng chuyển cảnh · Căn giữa vết cắt")
                    .font(.system(size: 10))
                    .foregroundStyle(DSColors.textSecondary)
            }
            Spacer()
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func durationSection(_ transition: CutTransition) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("THỜI LƯỢNG")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Thời gian",
                value: Binding(
                    get: { transition.duration.seconds },
                    set: { viewModel.updateTransitionDuration($0, commit: false) }
                ),
                range: 0.1...viewModel.maxAllowedTransitionDuration,
                step: 0.05,
                defaultValue: 0.5,
                unit: "s",
                onEditingChanged: { editing in
                    viewModel.onTransitionSliderEditingChanged(editing)
                }
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var emptyView: some View {
        VStack(spacing: DSSpacing.sm) {
            Spacer(minLength: 40)
            Image(systemName: "hourglass")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.45))
            Text("Chọn một điểm nối chuyển cảnh trên Timeline")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}

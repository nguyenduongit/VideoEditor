import SwiftUI
import Domain
import DesignSystem

public struct ExportVideoOptionsView: View {
    @Bindable var viewModel: ExportViewModel

    public init(viewModel: ExportViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "CẤU HÌNH VIDEO"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            settingRow(title: String(localized: "Độ phân giải")) {
                DSDropdown(
                    selection: $viewModel.resolution,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: String(localized: "Tốc độ khung hình")) {
                DSDropdown(
                    selection: $viewModel.frameRate,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: String(localized: "Chuẩn mã hóa")) {
                DSDropdown(
                    selection: $viewModel.codec,
                    titleKeyPath: \.rawValue,
                    width: 170
                )
            }
        }
        .padding(DSSpacing.sm)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
    }

    private func settingRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textPrimary)
            Spacer()
            content()
        }
    }
}


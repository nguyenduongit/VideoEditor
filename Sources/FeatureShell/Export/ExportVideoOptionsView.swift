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
            Text(String(localized: "VIDEO SETTINGS"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            settingRow(title: String(localized: "Resolution")) {
                DSDropdown(
                    selection: $viewModel.resolution,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: String(localized: "Frame Rate")) {
                DSDropdown(
                    selection: $viewModel.frameRate,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: String(localized: "Codec")) {
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


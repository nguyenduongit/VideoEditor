import SwiftUI
import Domain
import DesignSystem

public struct ExportAudioOptionsView: View {
    @Bindable var viewModel: ExportViewModel

    public init(viewModel: ExportViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "AUDIO SETTINGS"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            settingRow(title: String(localized: "Format")) {
                DSDropdown(
                    selection: $viewModel.audioFormat,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: String(localized: "Channels")) {
                Text(String(localized: "Stereo (2 channels)"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }

            settingRow(title: String(localized: "Sample Rate")) {
                Text("48.000 Hz")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
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


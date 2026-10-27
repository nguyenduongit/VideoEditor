import SwiftUI
import Domain
import DesignSystem

/// Hộp thoại tùy chỉnh thông số và theo dõi tiến trình Xuất Video MP4.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct ExportDialogView: View {
    @Bindable private var viewModel: ExportViewModel
    private let timelineViewModel: TimelineViewModel

    public init(viewModel: ExportViewModel, timelineViewModel: TimelineViewModel) {
        self.viewModel = viewModel
        self.timelineViewModel = timelineViewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            headerBar
            Divider().background(DSColors.blockBorder)

            Group {
                switch viewModel.status {
                case .idle, .cancelled:
                    settingsContent
                case .exporting:
                    exportingContent
                case .completed:
                    completedContent
                case .failed:
                    failedContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DSSpacing.lg)

            Divider().background(DSColors.blockBorder)
            footerBar
        }
        .frame(width: 460, height: 420)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    // MARK: - Header & Footer

    private var headerBar: some View {
        HStack {
            Image(systemName: "film.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.accent)
            Text("Xuất Video MP4")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)
            Spacer()
            Button(action: { viewModel.closeDialog() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isExporting)
        }
        .padding(.horizontal, DSSpacing.md)
        .frame(height: 38)
        .background(DSColors.windowBackground)
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            if !viewModel.isExporting {
                Button("Đóng") {
                    viewModel.closeDialog()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DSColors.textSecondary)
                .padding(.horizontal, DSSpacing.md)
            }

            if case .idle = viewModel.status {
                DSActionButton(title: "Chọn nơi lưu & Xuất...", icon: "arrow.down.to.line") {
                    viewModel.promptSaveAndStartExport(timelineViewModel: timelineViewModel)
                }
            } else if case .cancelled = viewModel.status {
                DSActionButton(title: "Xuất lại", icon: "arrow.clockwise") {
                    viewModel.promptSaveAndStartExport(timelineViewModel: timelineViewModel)
                }
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .frame(height: 44)
        .background(DSColors.windowBackground)
    }

    // MARK: - Subviews

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            optionsSection
            fileInfoSection
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("CẤU HÌNH XUẤT")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            settingRow(title: "Độ phân giải") {
                DSDropdown(
                    selection: $viewModel.resolution,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: "Tốc độ khung hình") {
                DSDropdown(
                    selection: $viewModel.frameRate,
                    titleKeyPath: \.title,
                    width: 170
                )
            }

            settingRow(title: "Chuẩn mã hóa") {
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

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("THÔNG TIN DỰ ÁN")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            infoRow(label: "Tỉ lệ khung hình", value: timelineViewModel.aspectRatio.title)
            infoRow(label: "Kích thước điểm ảnh", value: viewModel.renderDimensionsText(for: timelineViewModel.aspectRatio))
            infoRow(label: "Thời lượng tổng", value: viewModel.formattedDuration(duration: timelineViewModel.totalDuration))
            infoRow(
                label: "Dung lượng ước tính",
                value: viewModel.estimatedFileSize(
                    duration: timelineViewModel.totalDuration,
                    aspectRatio: timelineViewModel.aspectRatio
                )
            )
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

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textPrimary)
        }
    }

    private var exportingContent: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("Đang xuất video...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)

            VStack(spacing: DSSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DSColors.windowBackground)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DSColors.accent)
                            .frame(width: geo.size.width * CGFloat(viewModel.currentProgress))
                    }
                }
                .frame(height: 6)

                Text("\(Int(viewModel.currentProgress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.horizontal, DSSpacing.lg)

            Button("Hủy xuất") {
                viewModel.cancelExport()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.red.opacity(0.85))
            .font(.system(size: 11, weight: .medium))
            Spacer()
        }
    }

    private var completedContent: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color.green)
            Text("Xuất video thành công!")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)

            if let url = viewModel.outputURL {
                Text(url.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(1)

                Button("Mở trong Finder") {
                    viewModel.openInFinder()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DSColors.accent)
                .font(.system(size: 12, weight: .medium))
            }
            Spacer()
        }
    }

    private var failedContent: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.red)
            Text("Xuất video thất bại")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.md)
            }
            Spacer()
        }
    }
}

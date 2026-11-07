import SwiftUI
import Domain
import DesignSystem

/// Hộp thoại tùy chỉnh thông số và theo dõi tiến trình Xuất Video/Audio.
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
        .frame(width: 460, height: 440)
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
            Image(systemName: viewModel.mediaType == .video ? "film.fill" : "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.accent)
            Text(viewModel.mediaType == .video ? String(localized: "Xuất Video MP4") : String(localized: "Xuất Audio Only"))
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
                Button(String(localized: "Đóng")) {
                    viewModel.closeDialog()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DSColors.textSecondary)
                .padding(.horizontal, DSSpacing.md)
            }

            if case .idle = viewModel.status {
                let title = viewModel.mediaType == .video
                    ? String(localized: "Chọn nơi lưu & Xuất Video...")
                    : String(localized: "Chọn nơi lưu & Xuất Audio...")
                DSActionButton(title: title, icon: "arrow.down.to.line") {
                    viewModel.promptSaveAndStartExport(timelineViewModel: timelineViewModel)
                }
            } else if case .cancelled = viewModel.status {
                DSActionButton(title: String(localized: "Xuất lại"), icon: "arrow.clockwise") {
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
            mediaTypeSwitcher
            if viewModel.mediaType == .video {
                ExportVideoOptionsView(viewModel: viewModel)
            } else {
                ExportAudioOptionsView(viewModel: viewModel)
            }
            fileInfoSection
        }
    }

    private var mediaTypeSwitcher: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(ExportMediaType.allCases) { type in
                Button(action: { viewModel.mediaType = type }) {
                    HStack(spacing: 6) {
                        Image(systemName: type == .video ? "film" : "waveform")
                            .font(.system(size: 11, weight: .semibold))
                        Text(type.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(viewModel.mediaType == type ? DSColors.accent : DSColors.windowBackground)
                    .foregroundStyle(viewModel.mediaType == type ? Color.white : DSColors.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(String(localized: "THÔNG TIN DỰ ÁN"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            if viewModel.mediaType == .video {
                infoRow(label: String(localized: "Tỉ lệ khung hình"), value: timelineViewModel.aspectRatio.title)
                infoRow(label: String(localized: "Kích thước điểm ảnh"), value: viewModel.renderDimensionsText(for: timelineViewModel.aspectRatio))
            } else {
                infoRow(label: String(localized: "Định dạng xuất"), value: viewModel.audioFormat.title)
                infoRow(label: String(localized: "Cấu hình kênh"), value: "Stereo (2 kênh) • 48 kHz")
            }

            infoRow(label: String(localized: "Thời lượng tổng"), value: viewModel.formattedDuration(duration: timelineViewModel.totalDuration))
            infoRow(
                label: String(localized: "Dung lượng ước tính"),
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
            Text(viewModel.mediaType == .video ? String(localized: "Đang xuất video...") : String(localized: "Đang xuất audio..."))
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

            Button(String(localized: "Hủy xuất")) {
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
            Text(viewModel.mediaType == .video ? String(localized: "Xuất video thành công!") : String(localized: "Xuất audio thành công!"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)

            if let url = viewModel.outputURL {
                Text(url.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(1)

                Button(String(localized: "Mở trong Finder")) {
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
            Text(viewModel.mediaType == .video ? String(localized: "Xuất video thất bại") : String(localized: "Xuất audio thất bại"))
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

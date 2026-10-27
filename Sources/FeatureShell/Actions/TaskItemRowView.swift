import SwiftUI
import Domain
import DesignSystem

/// Thẻ hiển thị một tác vụ thành phần trong Action (không còn checklist, có icon trạng thái tiến trình).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng).
public struct TaskItemRowView: View {
    public let task: WorkflowTaskItem
    public let stepNumber: Int
    public let state: TaskExecutionState
    @Bindable var viewModel: ActionsPanelViewModel

    public init(
        task: WorkflowTaskItem,
        stepNumber: Int = 1,
        state: TaskExecutionState = .idle,
        viewModel: ActionsPanelViewModel
    ) {
        self.task = task
        self.stepNumber = stepNumber
        self.state = state
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            mainTaskRow

            if task.id == "addTitle" && viewModel.isTitlePadExpanded {
                titleConfigurationPad
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(state == .running ? 0.05 : 0.02))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .strokeBorder(state == .running ? DSColors.accent.opacity(0.6) : DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var mainTaskRow: some View {
        HStack(spacing: 10) {
            statusLeadingIcon
                .frame(width: 18, height: 18)

            Image(systemName: task.icon)
                .font(.system(size: 13.5))
                .foregroundStyle(taskAccentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)

                Text(task.description)
                    .font(.system(size: 10))
                    .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            if task.id == "addTitle" {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isTitlePadExpanded.toggle()
                    }
                }) {
                    Image(systemName: viewModel.isTitlePadExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(DSColors.textSecondary)
                        .padding(5)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Mở bảng cấu hình nội dung và preset tiêu đề")
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var statusLeadingIcon: some View {
        switch state {
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.green)
        case .idle:
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 18, height: 18)
                Text("\(stepNumber)")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(DSColors.textSecondary)
            }
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.red)
        }
    }

    private var titleConfigurationPad: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .background(DSColors.blockBorder)

            HStack(spacing: 8) {
                Text(String(localized: "Preset"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(width: 52, alignment: .leading)

                DSDropdown(
                    selectedTitle: viewModel.selectedPresetName,
                    options: viewModel.availableTextPresets.map { DSDropdownOption(id: $0.id, title: $0.name) },
                    onSelect: { presetID in
                        viewModel.titlePresetID = presetID
                    }
                )
            }

            HStack(spacing: 8) {
                Text(String(localized: "Tiêu đề"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(width: 52, alignment: .leading)

                TextField(String(localized: "Nhập tiêu đề video..."), text: $viewModel.titleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(DSColors.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(DSColors.inputBorder, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.bottom, 10)
    }

    private var taskAccentColor: Color {
        switch task.id {
        case "syncAudio": return Color(red: 0.13, green: 0.83, blue: 0.93)
        case "autoColor": return Color(red: 0.18, green: 0.83, blue: 0.75)
        case "aspect916": return Color(red: 0.22, green: 0.74, blue: 0.97)
        case "addTitle": return Color(red: 0.35, green: 0.65, blue: 0.98)
        case "visionFraming": return Color(red: 0.02, green: 0.71, blue: 0.83)
        default: return Color.accentColor
        }
    }
}

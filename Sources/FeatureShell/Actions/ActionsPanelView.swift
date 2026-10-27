import SwiftUI
import Domain
import DesignSystem

/// Giao diện Sidebar Tác vụ: Dropdown chọn Action, nút tạo mới (+) bên phải, danh sách thẻ task theo thứ tự và nút Thực thi dưới cùng.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R3.4 (tách Subview).
public struct ActionsPanelView: View {
    @Bindable var viewModel: ActionsPanelViewModel
    @State private var isActionPickerPresented: Bool = false

    public init(viewModel: ActionsPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            actionDropdownRow
                .padding(.top, DSSpacing.xs)
            Divider()
                .background(DSColors.blockBorder)
                .padding(.top, 4)

            tasksScrollView

            bottomExecuteArea
        }
        .sheet(isPresented: $viewModel.isAddActionModalPresented) {
            CreateActionModalView(
                isPresented: $viewModel.isAddActionModalPresented,
                onSave: { name, icon, taskIDs in
                    viewModel.createNewAction(name: name, icon: icon, taskIDs: taskIDs)
                }
            )
        }
    }

    // MARK: - Action Selector

    private var actionDropdownRow: some View {
        HStack(spacing: 8) {
            actionPickerButton

            Button(action: {
                viewModel.isAddActionModalPresented = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .background(DSColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Tạo mới Action tùy chỉnh và lưu lên Supabase")
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, 4)
    }

    private var actionPickerButton: some View {
        HStack(spacing: 2) {
            Button(action: { isActionPickerPresented.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.currentAction?.icon ?? "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DSColors.accent)

                    Text(viewModel.currentAction?.name ?? "Chưa có Action (Bấm + để tạo)")
                        .font(.system(size: 12))
                        .foregroundStyle(viewModel.currentAction != nil ? DSColors.textPrimary : DSColors.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 2)
                }
                .padding(.leading, 8)
                .padding(.trailing, 2)
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DSStepperButton(
                onIncrement: { viewModel.cycleAction(forward: false) },
                onDecrement: { viewModel.cycleAction(forward: true) }
            )
            .padding(.trailing, 2)
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
        .popover(isPresented: $isActionPickerPresented, arrowEdge: .bottom) {
            ActionPickerPopoverView(
                selectedActionID: viewModel.selectedActionID,
                actions: viewModel.actions,
                onSelect: { action in
                    viewModel.selectAction(action)
                    isActionPickerPresented = false
                },
                onDismiss: { isActionPickerPresented = false }
            )
        }
    }

    // MARK: - Task Cards List

    private var tasksScrollView: some View {
        ScrollView {
            VStack(spacing: 8) {
                let currentTasks = viewModel.currentActionTasks
                if currentTasks.isEmpty {
                    emptyActionStateView
                } else {
                    ForEach(Array(currentTasks.enumerated()), id: \.element.id) { index, task in
                        TaskItemRowView(
                            task: task,
                            stepNumber: index + 1,
                            state: viewModel.taskStates[task.id] ?? .idle,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, 8)
        }
    }

    private var emptyActionStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.5))
            Text(viewModel.actions.isEmpty ? "Chưa có Action nào" : "Action này chưa có tác vụ nào")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Text(viewModel.actions.isEmpty ? "Bấm nút \"+\" ở góc trên để tạo Action mới." : "Hãy thêm tác vụ vào Action.")
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Bottom Execution Area

    private var bottomExecuteArea: some View {
        VStack(spacing: 8) {
            executeButton
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.top, DSSpacing.xs)
        .padding(.bottom, DSSpacing.md)
        .background(DSColors.windowBackground)
    }

    private var executeButton: some View {
        Button(action: { viewModel.executeSelectedTasks() }) {
            HStack(spacing: 8) {
                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Đang thực thi...")
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Thực thi \(viewModel.currentAction?.name ?? "Action")")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(viewModel.currentActionTasks.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing || viewModel.currentActionTasks.isEmpty)
    }
}

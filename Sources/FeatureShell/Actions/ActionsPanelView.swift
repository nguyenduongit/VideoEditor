import SwiftUI
import Domain
import DesignSystem

/// Giao diện Sidebar Tác vụ: Dropdown chọn Action, nút tạo mới (+) bên phải, danh sách thẻ task theo thứ tự và nút Thực thi dưới cùng.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R3.4 (tách Subview).
public struct ActionsPanelView: View {
    @Bindable var viewModel: ActionsPanelViewModel
    @State private var isDeleteActionAlertPresented: Bool = false

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
        .alert("Delete Action", isPresented: $isDeleteActionAlertPresented) {
            Button("Delete", role: .destructive) {
                if let id = viewModel.currentAction?.id {
                    viewModel.deleteAction(id: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete Action \"\(viewModel.currentAction?.name ?? "")\" from Supabase?")
        }
    }

    // MARK: - Action Selector

    private var actionDropdownRow: some View {
        HStack(spacing: 8) {
            DSDropdown(
                selectedTitle: viewModel.currentAction?.name ?? "No Actions (Click + to create)",
                leadingIcon: viewModel.currentAction?.icon ?? "play.fill",
                leadingIconColor: DSColors.accent,
                options: viewModel.actions.map { DSDropdownOption(id: $0.id, title: $0.name, iconName: $0.icon) },
                onSelect: { actionID in
                    if let action = viewModel.actions.first(where: { $0.id == actionID }) {
                        viewModel.selectAction(action)
                    }
                }
            )

            Button(action: {
                viewModel.isAddActionModalPresented = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 26, height: 26)
                    .background(DSColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Create a new custom Action and save to Supabase")

            if let current = viewModel.currentAction, !current.isSystem {
                Button(action: { isDeleteActionAlertPresented = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.95))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Delete selected Action from Supabase")
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, 4)
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
            Text(viewModel.actions.isEmpty ? "No Actions Yet" : "This Action has no tasks")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Text(viewModel.actions.isEmpty ? "Click the \"+\" button above to create a new Action." : "Add tasks to this Action.")
                .font(.system(size: 10))
                .foregroundStyle(DSColors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Bottom Execution Area

    private var bottomExecuteArea: some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.yellow)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(DSColors.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
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
                    Text(String(localized: "Running..."))
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(localized: "Run \(viewModel.currentAction?.name ?? "Action")"))
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

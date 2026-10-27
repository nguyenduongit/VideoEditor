import SwiftUI
import Domain
import DesignSystem

/// Giao diện tạo Action mới: Đặt tên, chọn icon, chọn các tác vụ và sắp xếp thứ tự thực thi trước khi lưu lên Supabase.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R3.4 (tách Subview).
public struct CreateActionModalView: View {
    @Binding public var isPresented: Bool
    public let onSave: (String, String, [String]) -> Void

    @State private var name: String = ""
    @State private var selectedIcon: String = "play.fill"
    @State private var orderedTaskIDs: [String] = ["syncAudio", "autoColor", "aspect916", "addTitle", "visionFraming"]

    private let availableIcons = [
        "play.fill", "bolt.fill", "film.fill", "sparkles",
        "star.fill", "music.note", "wand.and.stars", "arrow.triangle.2.circlepath"
    ]

    public init(
        isPresented: Binding<Bool>,
        onSave: @escaping (String, String, [String]) -> Void
    ) {
        self._isPresented = isPresented
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            headerRow
            nameAndIconSection
            Divider().opacity(0.15)
            orderedTasksSection
            Divider().opacity(0.15)
            footerActionButtons
        }
        .padding(DSSpacing.md)
        .frame(width: 360, height: 480)
        .background(DSColors.blockBackground)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Image(systemName: "plus.square.fill")
                .foregroundStyle(DSColors.accent)
                .font(.system(size: 14))

            Text("Tạo Action Mới")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DSColors.textPrimary)

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var nameAndIconSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Nhập tên Action (vd: Dựng TikTok 9:16)...", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(DSColors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))

            HStack(spacing: 6) {
                ForEach(availableIcons, id: \.self) { icon in
                    let isSelected = selectedIcon == icon
                    Button(action: { selectedIcon = icon }) {
                        Image(systemName: icon)
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? Color.white : DSColors.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(isSelected ? DSColors.accent : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var orderedTasksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Thứ tự các bước thực thi (\(orderedTaskIDs.count) tác vụ):")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
            }

            ScrollView {
                VStack(spacing: 4) {
                    if orderedTaskIDs.isEmpty {
                        Text("Chưa chọn tác vụ nào. Hãy thêm từ danh sách bên dưới.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(orderedTaskIDs.enumerated()), id: \.element) { index, taskID in
                            if let task = WorkflowTaskItem.find(by: taskID) {
                                orderedTaskRow(task: task, index: index)
                            }
                        }
                    }

                    availableUnselectedTasksSection
                }
            }
        }
    }

    private func orderedTaskRow(task: WorkflowTaskItem, index: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(DSColors.accent)
                .frame(width: 14)

            Image(systemName: task.icon)
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 14)

            Text(task.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Nút di chuyển Lên
            Button(action: { moveTask(from: index, to: index - 1) }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(index > 0 ? DSColors.textSecondary : DSColors.textSecondary.opacity(0.2))
                    .padding(3)
            }
            .buttonStyle(.plain)
            .disabled(index == 0)

            // Nút di chuyển Xuống
            Button(action: { moveTask(from: index, to: index + 1) }) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(index < orderedTaskIDs.count - 1 ? DSColors.textSecondary : DSColors.textSecondary.opacity(0.2))
                    .padding(3)
            }
            .buttonStyle(.plain)
            .disabled(index >= orderedTaskIDs.count - 1)

            // Nút xóa khỏi Action
            Button(action: { orderedTaskIDs.remove(at: index) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var availableUnselectedTasksSection: some View {
        let unselected = WorkflowTaskItem.allTasks.filter { !orderedTaskIDs.contains($0.id) }
        return Group {
            if !unselected.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("+ Thêm tác vụ khác vào quy trình:")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                        .padding(.top, 6)

                    ForEach(unselected) { task in
                        Button(action: { orderedTaskIDs.append(task.id) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DSColors.accent)
                                Image(systemName: task.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(DSColors.textSecondary)
                                Text(task.name)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(DSColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func moveTask(from source: Int, to destination: Int) {
        guard source >= 0, source < orderedTaskIDs.count,
              destination >= 0, destination < orderedTaskIDs.count else { return }
        let item = orderedTaskIDs.remove(at: source)
        orderedTaskIDs.insert(item, at: destination)
    }

    private var footerActionButtons: some View {
        HStack(spacing: DSSpacing.sm) {
            Button("Hủy") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(DSColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Spacer()

            Button("Lưu Action") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalName = trimmed.isEmpty ? "Action Mới" : trimmed
                onSave(finalName, selectedIcon, orderedTaskIDs)
                isPresented = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(orderedTaskIDs.isEmpty ? DSColors.textSecondary.opacity(0.3) : DSColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .disabled(orderedTaskIDs.isEmpty)
        }
    }
}

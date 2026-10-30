import Foundation
import Domain
import os

private let logger = Logger(subsystem: "com.videoeditor", category: "ActionsPanelViewModel")

extension ActionsPanelViewModel {
    public func createNewAction(name: String, icon: String, taskIDs: [String]) {
        let newAction = CustomAction(
            id: UUID().uuidString,
            name: name,
            icon: icon,
            taskIDs: taskIDs,
            titleText: titleText,
            titlePresetID: titlePresetID,
            createdAt: Date(),
            isSystem: false
        )
        actions.append(newAction)
        selectedActionID = newAction.id
        selectedTaskIDs = Set(taskIDs)
        Task {
            do {
                try await dependencies.actionRepositories.actionRepository?.saveAction(newAction)
            } catch {
                logger.error("Failed to save action to repository: \(error.localizedDescription)")
            }
        }
        statusMessage = "Đã lưu Action mới: \(name)"
    }

    public func saveCurrentAsNewAction(name: String) {
        let orderedIDs = tasks.filter { selectedTaskIDs.contains($0.id) }.map(\.id)
        createNewAction(name: name, icon: "play.fill", taskIDs: orderedIDs.isEmpty ? (currentAction?.taskIDs ?? []) : orderedIDs)
    }

    public func deleteAction(id: String) {
        actions.removeAll { $0.id == id }
        if selectedActionID == id {
            selectedActionID = actions.first?.id
            if let first = actions.first {
                selectedTaskIDs = Set(first.taskIDs)
            }
        }
        Task {
            do {
                try await dependencies.actionRepositories.actionRepository?.deleteAction(id: id)
            } catch {
                logger.error("Failed to delete action from repository: \(error.localizedDescription)")
            }
        }
    }

    public func updateTitlePreset(id: String) {
        titlePresetID = id
        guard let currentID = selectedActionID,
              let idx = actions.firstIndex(where: { $0.id == currentID }) else { return }
        actions[idx].titlePresetID = id
        let updated = actions[idx]
        Task {
            try? await dependencies.actionRepositories.actionRepository?.saveAction(updated)
        }
    }

    public func updateTitleText(_ text: String) {
        titleText = text
        guard let currentID = selectedActionID,
              let idx = actions.firstIndex(where: { $0.id == currentID }) else { return }
        actions[idx].titleText = text
        let updated = actions[idx]
        Task {
            try? await dependencies.actionRepositories.actionRepository?.saveAction(updated)
        }
    }
}

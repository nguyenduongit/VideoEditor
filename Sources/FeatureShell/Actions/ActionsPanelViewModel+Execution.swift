import Foundation
import Domain

extension ActionsPanelViewModel {
    public func executeSelectedTasks() {
        guard !isProcessing, !selectedTaskIDs.isEmpty else { return }
        prepareDispatcher()
        guard let dispatcher else {
            errorMessage = "Chưa kết nối được với Timeline."
            return
        }

        isProcessing = true
        taskStates = [:]
        errorMessage = nil
        let orderedTasks = tasks.filter { selectedTaskIDs.contains($0.id) }
        statusMessage = "Đang thực thi \(orderedTasks.count) tác vụ..."
        let startTime = CFAbsoluteTimeGetCurrent()

        Task {
            var completedCount = 0
            for task in orderedTasks {
                self.taskStates[task.id] = .running
                do {
                    try await executeSingleTask(id: task.id, dispatcher: dispatcher)
                    self.taskStates[task.id] = .completed
                    completedCount += 1
                } catch {
                    self.taskStates[task.id] = .failed
                    self.errorMessage = error.localizedDescription
                }
            }
            await seekPlayheadToStart(dispatcher: dispatcher)
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            self.statusMessage = String(format: "✓ Đã hoàn thành %d/%d tác vụ (%.2fs)", completedCount, orderedTasks.count, elapsed)
            self.isProcessing = false
        }
    }

    public func runTaskItem(_ task: WorkflowTaskItem) { selectedTaskIDs = [task.id]; executeSelectedTasks() }
    public func runActionItem(_ action: CustomAction) { selectAction(action); executeSelectedTasks() }

    private func seekPlayheadToStart(dispatcher: MCPTimelineToolDispatcher) async {
        _ = try? await dispatcher.handleToolCallAsync(toolName: "timeline_edit_clip", argumentsJSON: "{\"operation\": \"seek\", \"atTimeSeconds\": 0.0}")
        self.timelineViewModel?.seek(to: .zero)
    }

    private func executeSingleTask(id: String, dispatcher: MCPTimelineToolDispatcher) async throws {
        switch id {
        case "syncAudio":
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_sync_audio",
                argumentsJSON: "{\"muteVideo\": true, \"trimExcessTail\": true}"
            )
        case "autoColor":
            let colorJSON = try await computeDynamicAutoColorJSON(dispatcher: dispatcher)
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_apply_template",
                argumentsJSON: colorJSON
            )
        case "aspect916":
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_edit_clip",
                argumentsJSON: "{\"operation\": \"setAspectRatio\", \"aspectRatio\": \"9:16\"}"
            )
        case "addTitle":
            let content = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tiêu đề video" : titleText
            let resolvedID = availableTextPresets.first(where: {
                $0.id.caseInsensitiveCompare(titlePresetID) == .orderedSame ||
                $0.name.caseInsensitiveCompare(titlePresetID) == .orderedSame
            })?.id ?? (availableTextPresets.first?.id ?? titlePresetID)

            var dict: [String: Any] = [
                "kind": "text",
                "customText": content,
                "position": "top",
                "startTimeSeconds": 0.0,
                "durationSeconds": 5.0
            ]
            if !resolvedID.isEmpty { dict["templateId"] = resolvedID }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let jsonString = String(data: data, encoding: .utf8) {
                _ = try await dispatcher.handleToolCallAsync(
                    toolName: "timeline_apply_template",
                    argumentsJSON: jsonString
                )
            }
        case "visionFraming":
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_ai_vision_framing",
                argumentsJSON: "{\"centerSubject\": true, \"enableAutoPan\": true, \"targetSubjectHeightRatio\": 0.33, \"enableLegStretch\": true, \"legStretchRatio\": 1.12}"
            )
        default:
            break
        }
    }
}

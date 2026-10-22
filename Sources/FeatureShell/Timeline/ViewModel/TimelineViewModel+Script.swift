import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func setAspectRatio(_ ratio: CanvasAspectRatio) {
        guard ratio != aspectRatio else { return }
        if let executor = commandExecutor, !isApplyingCommand {
            executor.execute(.setAspectRatio(ratio))
            return
        }
        aspectRatio = ratio
        onAspectRatioChanged?(ratio)
    }

    public func exportScript(title: String = "Untitled Project") -> ProjectScript {
        ProjectScript(
            title: title,
            fps: TimeRational.defaultFPS,
            aspectRatio: aspectRatio,
            timelineLayers: layers,
            history: commandExecutor?.history ?? [],
            historyIndex: commandExecutor?.historyIndex ?? 0
        )
    }

    public func loadScript(_ script: ProjectScript) {
        self.aspectRatio = script.aspectRatio
        self.layers = script.toTimelineLayers()
        self.selectedClipIDs.removeAll()
        self.commandExecutor?.loadHistory(records: script.history, currentIndex: script.historyIndex)
        resetZoom()
        onAspectRatioChanged?(aspectRatio)
    }

    @discardableResult
    public func jumpToHistory(targetIndex: Int) -> Bool {
        commandExecutor?.jumpToHistory(targetIndex: targetIndex) ?? false
    }
}

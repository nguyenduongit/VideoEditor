import Foundation
import Domain

extension TimelineCommandExecutor {
    public func clearHistory() {
        history.removeAll()
        historyIndex = 0
        viewModel?.updateUndoRedoState()
    }

    public func loadHistory(records: [TimelineHistoryRecord], currentIndex: Int) {
        self.history = records
        self.historyIndex = max(0, min(records.count, currentIndex))
        viewModel?.updateUndoRedoState()
    }

    @discardableResult
    public func undo() -> Bool {
        guard historyIndex > 0 else { return false }
        return jumpToHistory(targetIndex: historyIndex - 1)
    }

    @discardableResult
    public func redo() -> Bool {
        guard historyIndex < history.count else { return false }
        return jumpToHistory(targetIndex: historyIndex + 1)
    }

    @discardableResult
    public func jumpToHistory(targetIndex: Int) -> Bool {
        guard let viewModel else { return false }
        guard targetIndex >= 0, targetIndex <= history.count, targetIndex != historyIndex else {
            return false
        }

        if targetIndex < historyIndex {
            while historyIndex > targetIndex {
                let record = history[historyIndex - 1]
                guard apply(command: record.inverse, on: viewModel) != nil else { break }
                historyIndex -= 1
            }
        } else {
            while historyIndex < targetIndex {
                let record = history[historyIndex]
                guard apply(command: record.command, on: viewModel) != nil else { break }
                historyIndex += 1
            }
        }

        viewModel.onClipsTrimmed?()
        viewModel.updateUndoRedoState()
        return true
    }
}

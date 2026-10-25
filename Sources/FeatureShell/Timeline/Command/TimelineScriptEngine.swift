import Foundation
import Domain

public struct ScriptExecutionResult: Codable, Sendable, Equatable {
    public let isSuccess: Bool
    public let executedCommandsCount: Int
    public let errorMessage: String?

    public init(isSuccess: Bool, executedCommandsCount: Int, errorMessage: String? = nil) {
        self.isSuccess = isSuccess
        self.executedCommandsCount = executedCommandsCount
        self.errorMessage = errorMessage
    }
}

/// Headless scripting coordinator for the timeline.
/// Accepts declarative JSON scripts or typed commands and drives the TimelineViewModel.
/// Serves as the direct execution target for MCP AI agents and automated workflows.
@MainActor
public final class TimelineScriptEngine {
    private let viewModel: TimelineViewModel
    public var currentViewModel: TimelineViewModel { viewModel }
    public let commandExecutor: TimelineCommandExecutor

    public init(
        viewModel: TimelineViewModel,
        commandExecutor: TimelineCommandExecutor? = nil
    ) {
        self.viewModel = viewModel
        let executor = commandExecutor ?? viewModel.commandExecutor ?? TimelineCommandExecutor(viewModel: viewModel)
        self.commandExecutor = executor
        if viewModel.commandExecutor !== executor {
            viewModel.commandExecutor = executor
        }
    }

    public func executeCommands(_ commands: [TimelineCommand]) -> ScriptExecutionResult {
        var count = 0
        for command in commands {
            guard commandExecutor.execute(command) else {
                return ScriptExecutionResult(
                    isSuccess: false,
                    executedCommandsCount: count,
                    errorMessage: "Failed executing command at index \(count)"
                )
            }
            count += 1
        }
        return ScriptExecutionResult(isSuccess: true, executedCommandsCount: count)
    }

    public func executeScriptJSON(_ jsonString: String) throws -> ScriptExecutionResult {
        guard let data = jsonString.data(using: .utf8) else {
            return ScriptExecutionResult(isSuccess: false, executedCommandsCount: 0, errorMessage: "Invalid UTF-8 string")
        }
        let commands = try JSONDecoder().decode([TimelineCommand].self, from: data)
        return executeCommands(commands)
    }

    public func loadProjectJSON(_ jsonString: String) throws {
        let project = try ProjectScript.from(jsonString: jsonString)
        viewModel.loadScript(project)
        commandExecutor.clearHistory()
    }

    public func exportProjectJSON(title: String = "Untitled Project", prettyPrinted: Bool = true) throws -> String {
        let project = viewModel.exportScript(title: title)
        return try project.toJSONString(prettyPrinted: prettyPrinted)
    }

    public func currentProjectScript(title: String = "Untitled Project") -> ProjectScript {
        viewModel.exportScript(title: title)
    }
}

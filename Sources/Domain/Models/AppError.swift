import Foundation

public enum AppError: LocalizedError, Sendable, Equatable {
    case invalidParameter(String)
    case resourceNotFound(String)
    case executionFailed(String)
    case transportError(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .resourceNotFound(let message):
            return "Resource not found: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .transportError(let message):
            return "Transport error: \(message)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

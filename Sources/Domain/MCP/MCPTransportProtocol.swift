import Foundation

public protocol MCPServerDelegate: AnyObject, Sendable {
    func handleJSONRPCMessage(_ message: String) async -> String?
}

public protocol MCPServerTransport: AnyObject, Sendable {
    var port: UInt16 { get }
    var isRunning: Bool { get }
    var delegate: MCPServerDelegate? { get set }

    func start() throws
    func stop()
}

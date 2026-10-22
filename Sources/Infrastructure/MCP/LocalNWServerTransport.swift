import Foundation
import Network
import os
import Domain

public final class LocalNWServerTransport: @unchecked Sendable, MCPServerTransport {
    private let logger = Logger(subsystem: "com.videoeditor.mcp", category: "Transport")
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.videoeditor.mcp.queue", qos: .userInitiated)

    public let port: UInt16
    public private(set) var isRunning: Bool = false
    public weak var delegate: MCPServerDelegate?

    public init(port: UInt16 = 4088) {
        self.port = port
    }

    public func start() throws {
        guard !isRunning else { return }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw AppError.unknown
        }

        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .loopback

        let listener = try NWListener(using: parameters, on: nwPort)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isRunning = true
                self.logger.info("MCP Local Server listening on port \(self.port)")
            case .failed(let error):
                self.isRunning = false
                self.logger.error("MCP Local Server failed with error: \(error.localizedDescription)")
            case .cancelled:
                self.isRunning = false
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.readNextChunk(from: connection)
            }
        }
        connection.start(queue: queue)
    }

    private func readNextChunk(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            if let content, !content.isEmpty {
                self.processIncomingData(content, on: connection)
            }

            if isComplete {
                connection.cancel()
            } else if error == nil {
                self.readNextChunk(from: connection)
            }
        }
    }

    private func processIncomingData(_ data: Data, on connection: NWConnection) {
        let rawString = String(decoding: data, as: UTF8.self)
        let isHTTPRequest = rawString.hasPrefix("POST ") || rawString.hasPrefix("GET ")

        let jsonPayload: String
        if isHTTPRequest {
            jsonPayload = extractHTTPBody(from: rawString)
        } else {
            jsonPayload = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !jsonPayload.isEmpty else {
            if rawString.hasPrefix("GET ") {
                sendHTTPResponse("{\"status\":\"ok\",\"service\":\"VideoEditor MCP\"}", on: connection)
            }
            return
        }

        Task {
            guard let delegate = self.delegate else { return }
            let responseString = await delegate.handleJSONRPCMessage(jsonPayload)

            guard let responseString else { return }
            if isHTTPRequest {
                self.sendHTTPResponse(responseString, on: connection)
            } else {
                let outData = Data((responseString + "\n").utf8)
                connection.send(content: outData, completion: .contentProcessed({ _ in }))
            }
        }
    }

    private func extractHTTPBody(from httpString: String) -> String {
        guard let range = httpString.range(of: "\r\n\r\n") else {
            if let altRange = httpString.range(of: "\n\n") {
                return String(httpString[altRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }
        return String(httpString[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendHTTPResponse(_ body: String, on connection: NWConnection) {
        let bodyData = Data(body.utf8)
        let headers = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: application/json; charset=utf-8\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Access-Control-Allow-Origin: *\r\n"
            + "Connection: close\r\n\r\n"

        var responseData = Data(headers.utf8)
        responseData.append(bodyData)
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}

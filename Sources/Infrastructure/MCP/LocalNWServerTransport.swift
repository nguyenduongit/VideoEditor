import Foundation
import Network
import os
import Domain

/// Bọc `NWListener` từ Apple `Network.framework` phục vụ AI Agent nội bộ qua cổng loopback `4088`.
/// Hỗ trợ gom gói TCP đa phân mảnh theo `Content-Length` (không đứt gói JSON `> 64KB` khi gửi SVG / MSL Shader / ProjectScript),
/// tách dòng `\n` cho raw TCP JSON-RPC, và không mở header CORS `*`.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R8.3 (Thread-safe qua serial queue).
public final class LocalNWServerTransport: @unchecked Sendable, MCPServerTransport {
    private static let maxBufferBytes = 16 * 1024 * 1024

    private let logger = Logger(subsystem: "com.videoeditor.mcp", category: "Transport")
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.videoeditor.mcp.queue", qos: .userInitiated)
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]

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
        queue.async { [weak self] in
            self?.receiveBuffers.removeAll()
        }
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    /// Tách một gói HTTP hoàn chỉnh dựa trên `Content-Length` từ bộ đệm tích lũy TCP.
    /// Trả về `nil` nếu dữ liệu TCP chưa nhận đủ số byte khai báo trong `Content-Length`.
    public static func extractCompleteHTTPMessage(from buffer: inout Data) -> (isGET: Bool, body: String)? {
        let crlfSep = Data([13, 10, 13, 10]) // "\r\n\r\n"
        let lfSep = Data([10, 10])           // "\n\n"
        guard let sepRange = buffer.range(of: crlfSep) ?? buffer.range(of: lfSep) else {
            return nil
        }

        let headerString = String(decoding: buffer[..<sepRange.lowerBound], as: UTF8.self)
        let isGET = headerString.hasPrefix("GET ")
        var contentLength = 0
        for line in headerString.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("content-length:") {
                let rawVal = trimmed.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = max(0, Int(rawVal) ?? 0)
                break
            }
        }

        let totalExpected = sepRange.upperBound + contentLength
        guard buffer.count >= totalExpected else {
            return nil
        }

        let bodyData = buffer.subdata(in: sepRange.upperBound..<totalExpected)
        buffer.removeSubrange(0..<totalExpected)
        let body = String(decoding: bodyData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (isGET: isGET, body: body)
    }

    // MARK: - Private Connection Framing

    private func handleNewConnection(_ connection: NWConnection) {
        let connID = ObjectIdentifier(connection)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.readNextChunk(from: connection)
            case .failed, .cancelled:
                self.receiveBuffers.removeValue(forKey: connID)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func readNextChunk(from connection: NWConnection) {
        let connID = ObjectIdentifier(connection)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 131_072) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if let content, !content.isEmpty {
                var buf = self.receiveBuffers[connID, default: Data()]
                if buf.count + content.count > Self.maxBufferBytes {
                    self.logger.error("MCP payload vượt quá giới hạn 16MB, đóng kết nối.")
                    self.receiveBuffers.removeValue(forKey: connID)
                    connection.cancel()
                    return
                }
                buf.append(content)
                self.receiveBuffers[connID] = buf
                self.drainBufferedMessages(for: connection, isEOF: isComplete)
            } else if isComplete {
                self.drainBufferedMessages(for: connection, isEOF: true)
            }

            if isComplete {
                self.receiveBuffers.removeValue(forKey: connID)
            } else if error == nil {
                self.readNextChunk(from: connection)
            }
        }
    }

    private func drainBufferedMessages(for connection: NWConnection, isEOF: Bool) {
        let connID = ObjectIdentifier(connection)
        guard var buffer = receiveBuffers[connID], !buffer.isEmpty else { return }

        let prefixStr = String(decoding: buffer.prefix(16), as: UTF8.self)
        let looksLikeHTTP = prefixStr.hasPrefix("POST ") || prefixStr.hasPrefix("GET ") || prefixStr.hasPrefix("HEAD ")
        if looksLikeHTTP {
            guard let parsed = Self.extractCompleteHTTPMessage(from: &buffer) else { return }
            receiveBuffers[connID] = buffer
            if parsed.isGET || parsed.body.isEmpty {
                sendHTTPResponse("{\"status\":\"ok\",\"service\":\"VideoEditor MCP\"}", on: connection)
            } else {
                dispatchJSONRPC(parsed.body, isHTTP: true, on: connection)
            }
            return
        }

        while let newlineIdx = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: 0..<newlineIdx)
            buffer.removeSubrange(0...newlineIdx)
            let line = String(decoding: lineData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                dispatchJSONRPC(line, isHTTP: false, on: connection)
            }
        }
        if isEOF, !buffer.isEmpty {
            let trailing = String(decoding: buffer, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeAll()
            if !trailing.isEmpty {
                dispatchJSONRPC(trailing, isHTTP: false, on: connection)
            }
        }
        receiveBuffers[connID] = buffer
    }

    private func dispatchJSONRPC(_ payload: String, isHTTP: Bool, on connection: NWConnection) {
        Task {
            guard let delegate = self.delegate else { return }
            guard let responseString = await delegate.handleJSONRPCMessage(payload) else { return }
            if isHTTP {
                self.sendHTTPResponse(responseString, on: connection)
            } else {
                let outData = Data((responseString + "\n").utf8)
                connection.send(content: outData, completion: .contentProcessed({ _ in }))
            }
        }
    }

    private func sendHTTPResponse(_ body: String, on connection: NWConnection) {
        let bodyData = Data(body.utf8)
        let headers = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: application/json; charset=utf-8\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Connection: close\r\n\r\n"

        var responseData = Data(headers.utf8)
        responseData.append(bodyData)
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}

import Foundation

public enum JSONRPCID: Codable, Sendable, Hashable, Equatable {
    case string(String)
    case int(Int)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let num):
            try container.encode(num)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct MCPErrorResponse: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: String?

    public init(code: Int, message: String, data: String? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public static let parseError = MCPErrorResponse(code: -32700, message: "Parse error")
    public static let invalidRequest = MCPErrorResponse(code: -32600, message: "Invalid Request")
    public static let methodNotFound = MCPErrorResponse(code: -32601, message: "Method not found")
    public static let invalidParams = MCPErrorResponse(code: -32602, message: "Invalid params")
    public static let internalError = MCPErrorResponse(code: -32603, message: "Internal error")
}

public struct MCPToolDescriptor: Codable, Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: String

    public init(name: String, description: String, inputSchema: String) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

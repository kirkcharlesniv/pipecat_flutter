import Foundation

public struct LLMFunctionCallData: Codable {
    public let functionName: String
    public let toolCallID: String
    public let args: Value

    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case toolCallID = "tool_call_id"
        case args
    }

    public init(functionName: String, toolCallID: String, args: Value) {
        self.functionName = functionName
        self.toolCallID = toolCallID
        self.args = args
    }
}

public typealias FunctionCallCallback = (LLMFunctionCallData, @escaping (Value) async -> Void) async -> Void

/// Payload for `llm-function-call-started`. Fields may be omitted by the server
/// based on its configured function-call report level.
public struct LLMFunctionCallStartedData: Codable {
    public let functionName: String?

    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
    }

    public init(functionName: String?) {
        self.functionName = functionName
    }
}

/// Payload for `llm-function-call-in-progress`. Always carries the
/// `toolCallID`. `functionName` and `args` may be omitted by the server based
/// on its configured function-call report level.
public struct LLMFunctionCallInProgressData: Codable {
    public let toolCallID: String
    public let functionName: String?
    public let args: Value?

    enum CodingKeys: String, CodingKey {
        case toolCallID = "tool_call_id"
        case functionName = "function_name"
        case args = "arguments"
    }

    public init(toolCallID: String, functionName: String?, args: Value?) {
        self.toolCallID = toolCallID
        self.functionName = functionName
        self.args = args
    }
}

/// Payload for `llm-function-call-stopped`. Always carries the `toolCallID`
/// and the `cancelled` flag. `functionName` and `result` may be omitted by
/// the server based on its configured function-call report level.
public struct LLMFunctionCallStoppedData: Codable {
    public let toolCallID: String
    public let cancelled: Bool
    public let functionName: String?
    public let result: Value?

    enum CodingKeys: String, CodingKey {
        case toolCallID = "tool_call_id"
        case cancelled
        case functionName = "function_name"
        case result
    }

    public init(toolCallID: String, cancelled: Bool, functionName: String?, result: Value?) {
        self.toolCallID = toolCallID
        self.cancelled = cancelled
        self.functionName = functionName
        self.result = result
    }
}

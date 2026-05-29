package ai.pipecat.client.types

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

fun interface LLMFunctionCallHandler {
    fun handleFunctionCall(
        data: LLMFunctionCallData,
        onResult: (Value) -> Unit
    )
}

@Serializable
data class LLMFunctionCallData(
    @SerialName("function_name")
    val functionName: String,
    @SerialName("tool_call_id")
    val toolCallID: String,
    val args: JsonElement
)

@Serializable
data class LLMFunctionCallResult(
    @SerialName("function_name")
    val functionName: String,
    @SerialName("tool_call_id")
    val toolCallID: String,
    val arguments: JsonElement,
    val result: JsonElement
)

/** Payload for `llm-function-call-started`. Fields may be omitted by the server. */
@Serializable
data class LLMFunctionCallStartedData(
    @SerialName("function_name")
    val functionName: String? = null,
)

/** Payload for `llm-function-call-in-progress`. */
@Serializable
data class LLMFunctionCallInProgressData(
    @SerialName("tool_call_id")
    val toolCallID: String,
    @SerialName("function_name")
    val functionName: String? = null,
    val arguments: JsonElement? = null,
)

/** Payload for `llm-function-call-stopped`. */
@Serializable
data class LLMFunctionCallStoppedData(
    @SerialName("tool_call_id")
    val toolCallID: String,
    val cancelled: Boolean,
    @SerialName("function_name")
    val functionName: String? = null,
    val result: JsonElement? = null,
)
package com.kcniverba

import ai.pipecat.client.types.LLMFunctionCallInProgressData
import ai.pipecat.client.types.LLMFunctionCallStartedData
import ai.pipecat.client.types.LLMFunctionCallStoppedData
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

private val json = Json { ignoreUnknownKeys = true }

class FunctionCallLifecycleTest {

    // ---- LLMFunctionCallStartedData ------------------------------------------

    @Test
    fun started_deserializesWithFunctionName() {
        val data = json.decodeFromString(
            LLMFunctionCallStartedData.serializer(),
            """{"function_name":"get_weather"}""",
        )
        assertEquals("get_weather", data.functionName)
    }

    @Test
    fun started_deserializesWithoutFunctionName() {
        val data = json.decodeFromString(
            LLMFunctionCallStartedData.serializer(),
            """{}""",
        )
        assertNull(data.functionName)
    }

    // ---- LLMFunctionCallInProgressData ----------------------------------------

    @Test
    fun inProgress_deserializesFullPayload() {
        val data = json.decodeFromString(
            LLMFunctionCallInProgressData.serializer(),
            """{"tool_call_id":"tc-1","function_name":"get_weather","arguments":{"city":"Manila"}}""",
        )
        assertEquals("tc-1", data.toolCallID)
        assertEquals("get_weather", data.functionName)
        val args = data.arguments
        assertTrue(args != null && args != JsonNull)
        assertEquals("""{"city":"Manila"}""", args.toString())
    }

    @Test
    fun inProgress_deserializesWithoutOptionalFields() {
        val data = json.decodeFromString(
            LLMFunctionCallInProgressData.serializer(),
            """{"tool_call_id":"tc-2"}""",
        )
        assertEquals("tc-2", data.toolCallID)
        assertNull(data.functionName)
        assertNull(data.arguments)
    }

    // ---- LLMFunctionCallStoppedData ------------------------------------------

    @Test
    fun stopped_deserializesNotCancelled() {
        val data = json.decodeFromString(
            LLMFunctionCallStoppedData.serializer(),
            """{"tool_call_id":"tc-3","cancelled":false,"function_name":"get_weather","result":{"temp":30}}""",
        )
        assertEquals("tc-3", data.toolCallID)
        assertFalse(data.cancelled)
        assertEquals("get_weather", data.functionName)
        val result = data.result
        assertTrue(result != null && result != JsonNull)
        assertEquals("""{"temp":30}""", result.toString())
    }

    @Test
    fun stopped_deserializesCancelledNoResult() {
        val data = json.decodeFromString(
            LLMFunctionCallStoppedData.serializer(),
            """{"tool_call_id":"tc-4","cancelled":true}""",
        )
        assertEquals("tc-4", data.toolCallID)
        assertTrue(data.cancelled)
        assertNull(data.functionName)
        assertNull(data.result)
    }

}

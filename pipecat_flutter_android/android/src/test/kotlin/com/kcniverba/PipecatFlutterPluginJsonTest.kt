package com.kcniverba

import ai.pipecat.client.types.Value
import kotlin.test.Test
import kotlin.test.assertEquals

class PipecatFlutterPluginJsonTest {
    @Test
    fun valueToCanonicalJson_serializesFunctionArgumentsAsJson() {
        val plugin = PipecatFlutterPlugin()
        val method = PipecatFlutterPlugin::class.java.getDeclaredMethod(
            "valueToCanonicalJson",
            Value::class.java,
        )
        method.isAccessible = true

        val args = Value.Object(
            mapOf(
                "optionId" to Value.Str("goal"),
                "meta" to Value.Object(mapOf("source" to Value.Str("voice"))),
            ),
        )
        val json = method.invoke(plugin, args) as String?

        assertEquals("""{"meta":{"source":"voice"},"optionId":"goal"}""", json)
    }
}

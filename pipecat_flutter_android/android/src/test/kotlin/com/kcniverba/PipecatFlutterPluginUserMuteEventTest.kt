package com.kcniverba

import ai.pipecat.client.types.Value
import com.kcniverba.pipecat_flutter_android.UserMuteEvent
import com.kcniverba.pipecat_flutter_android.UserMuteState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class PipecatFlutterPluginUserMuteEventTest {
    @Test
    fun parseUserMuteEventFromValue_mapsStartedStatus() {
        val plugin = PipecatFlutterPlugin()
        val method = PipecatFlutterPlugin::class.java.getDeclaredMethod(
            "parseUserMuteEventFromValue",
            Value::class.java,
        )
        method.isAccessible = true

        val payload = Value.Object(
            mapOf(
                "compat" to Value.Object(
                    mapOf("bridge" to Value.Str("rtvi_user_mute_v1")),
                ),
                "user_mute" to Value.Object(
                    mapOf("status" to Value.Str("started")),
                ),
            ),
        )

        val event = method.invoke(plugin, payload) as UserMuteEvent?

        assertEquals(UserMuteState.STARTED, event?.state)
    }

    @Test
    fun parseUserMuteEventFromValue_ignoresWrongBridge() {
        val plugin = PipecatFlutterPlugin()
        val method = PipecatFlutterPlugin::class.java.getDeclaredMethod(
            "parseUserMuteEventFromValue",
            Value::class.java,
        )
        method.isAccessible = true

        val payload = Value.Object(
            mapOf(
                "compat" to Value.Object(
                    mapOf("bridge" to Value.Str("unknown_bridge")),
                ),
                "user_mute" to Value.Object(
                    mapOf("status" to Value.Str("started")),
                ),
            ),
        )

        val event = method.invoke(plugin, payload)

        assertNull(event)
    }
}

package com.kcniverba

import com.kcniverba.pipecat_flutter_android.*

class TimelineEventHandlerImpl : TimelineEventsStreamHandler() {
    private var eventSink: PigeonEventSink<TimelineEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<TimelineEvent>) {
        this.eventSink = sink
    }

    override fun onCancel(p0: Any?) {
        this.eventSink = null
    }

    fun sendEvent(event: TimelineEvent) {
        eventSink?.success(event)
    }
}

class LocalAudioLevelHandlerImpl : LocalAudioLevelStreamHandler() {
    private var sink: PigeonEventSink<AudioLevel>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<AudioLevel>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendLevel(level: Double) {
        sink?.success(AudioLevel(level = level))
    }
}

class RemoteAudioLevelHandlerImpl : RemoteAudioLevelStreamHandler() {
    private var sink: PigeonEventSink<AudioLevel>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<AudioLevel>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendLevel(level: Double) {
        sink?.success(AudioLevel(level = level))
    }
}

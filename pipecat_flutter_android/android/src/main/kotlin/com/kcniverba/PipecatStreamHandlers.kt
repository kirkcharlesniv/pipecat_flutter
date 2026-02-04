package com.kcniverba

import com.kcniverba.pipecat_flutter_android.*

class PipecatEventStreamHandlerImpl : EventsStreamHandler() {
    private var eventSink: PigeonEventSink<PipecatEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<PipecatEvent>) {
        this.eventSink = sink
    }

    override fun onCancel(p0: Any?) {
        this.eventSink = null
    }

    fun sendEvent(event: PipecatEvent) {
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

class BotOutputHandlerImpl : BotOutputStreamHandler() {
    private var sink: PigeonEventSink<BotOutputEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<BotOutputEvent>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendEvent(event: BotOutputEvent) {
        sink?.success(event)
    }
}

class UserTranscriptionHandlerImpl : UserTranscriptionsStreamHandler() {
    private var sink: PigeonEventSink<UserTranscriptionEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<UserTranscriptionEvent>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendEvent(event: UserTranscriptionEvent) {
        sink?.success(event)
    }
}

class ConnectionStateHandlerImpl : ConnectionStateEventsStreamHandler() {
    private var sink: PigeonEventSink<ConnectionStateEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<ConnectionStateEvent>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendEvent(event: ConnectionStateEvent) {
        sink?.success(event)
    }
}

class SpeakingEventHandlerImpl : SpeakingEventsStreamHandler() {
    private var sink: PigeonEventSink<SpeakingEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<SpeakingEvent>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendEvent(event: SpeakingEvent) {
        sink?.success(event)
    }
}

class InputStatusUpdatedHandlerImpl : InputStatusEventsStreamHandler() {
    private var sink: PigeonEventSink<InputStatusUpdatedEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<InputStatusUpdatedEvent>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        this.sink = null
    }

    fun sendEvent(event: InputStatusUpdatedEvent) {
        sink?.success(event)
    }
}

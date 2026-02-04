package com.kcniverba

import android.content.Context
import android.os.Handler
import android.os.Looper

import io.flutter.embedding.engine.plugins.FlutterPlugin

import com.kcniverba.pipecat_flutter_android.*

import ai.pipecat.client.PipecatClient
import ai.pipecat.client.PipecatClientOptions
import ai.pipecat.client.PipecatEventCallbacks
import ai.pipecat.client.daily.DailyTransport
import ai.pipecat.client.daily.DailyTransportConnectParams
import ai.pipecat.client.transport.MsgServerToClient
import ai.pipecat.client.types.BotOutputData
import ai.pipecat.client.result.Result as PipecatResult
import ai.pipecat.client.types.TransportState
import ai.pipecat.client.types.Transcript
import ai.pipecat.client.types.Participant
import co.daily.model.MeetingToken
import co.daily.model.RemoteInputsEnabledUpdate
import co.daily.model.RemoteParticipantUpdate

class PipecatFlutterPlugin : FlutterPlugin, PipecatHostApi {
    private var client: PipecatClient<DailyTransport, DailyTransportConnectParams>? = null
    private var transport: DailyTransport? = null
    private var applicationContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventStreamHandler: PipecatEventStreamHandlerImpl? = null
    private var localAudioHandler: LocalAudioLevelHandlerImpl? = null
    private var remoteAudioHandler: RemoteAudioLevelHandlerImpl? = null
    private var botOutputHandler: BotOutputHandlerImpl? = null
    private var userTranscriptionHandler: UserTranscriptionHandlerImpl? = null
    private var connectionStateHandler: ConnectionStateHandlerImpl? = null
    private var speakingEventHandler: SpeakingEventHandlerImpl? = null
    private var inputStatusUpdatedHandler: InputStatusUpdatedHandlerImpl? = null

    private var isBotAudioMuted: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        val messenger = flutterPluginBinding.binaryMessenger

        PipecatHostApi.setUp(messenger, this)

        eventStreamHandler = PipecatEventStreamHandlerImpl().also {
            EventsStreamHandler.register(messenger, it)
        }
        localAudioHandler = LocalAudioLevelHandlerImpl().also {
            LocalAudioLevelStreamHandler.register(messenger, it)
        }
        remoteAudioHandler = RemoteAudioLevelHandlerImpl().also {
            RemoteAudioLevelStreamHandler.register(messenger, it)
        }
        botOutputHandler = BotOutputHandlerImpl().also {
            BotOutputStreamHandler.register(messenger, it)
        }
        userTranscriptionHandler = UserTranscriptionHandlerImpl().also {
            UserTranscriptionsStreamHandler.register(messenger, it)
        }
        connectionStateHandler = ConnectionStateHandlerImpl().also {
            ConnectionStateEventsStreamHandler.register(messenger, it)
        }
        speakingEventHandler = SpeakingEventHandlerImpl().also {
            SpeakingEventsStreamHandler.register(messenger, it)
        }
        inputStatusUpdatedHandler = InputStatusUpdatedHandlerImpl().also {
            InputStatusEventsStreamHandler.register(messenger, it)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PipecatHostApi.setUp(binding.binaryMessenger, null)
        client?.release()
        client = null
        transport = null
        applicationContext = null
    }

    // -- PipecatHostApi --

    override fun startAndConnect(parameters: StartBotParams, callback: (Result<Unit>) -> Unit) {
        if (client != null) {
            callback(Result.failure(FlutterError(
                code = "ALREADY_CONNECTED",
                message = "Client already exists. Disconnect first."
            )))
            return
        }

        val context = applicationContext ?: run {
            callback(Result.failure(FlutterError(
                code = "NO_CONTEXT",
                message = "Application context not available"
            )))
            return
        }

        val newTransport = DailyTransport(context)
        transport = newTransport

        val options = PipecatClientOptions(
            callbacks = createCallbacks(),
            enableMic = parameters.shouldEnableMicrophone,
            enableCam = parameters.shouldEnableCamera
        )

        val newClient = PipecatClient(newTransport, options)
        client = newClient

        val connectParams = DailyTransportConnectParams(
            dailyRoom = parameters.url,
            dailyToken = parameters.token?.let { MeetingToken(it) }
        )

        newClient.connect(connectParams).withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> {
                        updateInputState()
                        callback(Result.success(Unit))
                    }
                    is PipecatResult.Err -> {
                        callback(Result.failure(FlutterError(
                            code = "CONNECT_ERROR",
                            message = result.error.toString()
                        )))
                    }
                }
            }
        }
    }

    override fun disconnect(callback: (Result<Unit>) -> Unit) {
        val currentClient = client ?: run {
            callback(Result.success(Unit))
            return
        }

        currentClient.disconnect().withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> {
                        currentClient.release()
                        client = null
                        transport = null
                        callback(Result.success(Unit))
                    }
                    is PipecatResult.Err -> {
                        callback(Result.failure(FlutterError(
                            code = "DISCONNECT_ERROR",
                            message = result.error.toString()
                        )))
                    }
                }
            }
        }
    }

    override fun toggleMicrophone(isEnabled: Boolean, callback: (Result<Unit>) -> Unit) {
        val currentClient = client ?: run {
            callback(Result.failure(FlutterError(
                code = "NO_CLIENT",
                message = "Client not available"
            )))
            return
        }

        currentClient.enableMic(isEnabled).withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> {
                        updateInputState()
                        callback(Result.success(Unit))
                    }
                    is PipecatResult.Err -> {
                        callback(Result.failure(FlutterError(
                            code = "MIC_ERROR",
                            message = result.error.toString()
                        )))
                    }
                }
            }
        }
    }

    override fun toggleCamera(isEnabled: Boolean, callback: (Result<Unit>) -> Unit) {
        val currentClient = client ?: run {
            callback(Result.failure(FlutterError(
                code = "NO_CLIENT",
                message = "Client not available"
            )))
            return
        }

        currentClient.enableCam(isEnabled).withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> {
                        updateInputState()
                        callback(Result.success(Unit))
                    }
                    is PipecatResult.Err -> {
                        callback(Result.failure(FlutterError(
                            code = "CAMERA_ERROR",
                            message = result.error.toString()
                        )))
                    }
                }
            }
        }
    }

    override fun muteBotAudio(isMuted: Boolean, callback: (Result<Unit>) -> Unit) {
        val dailyTransport = transport ?: run {
            callback(Result.failure(FlutterError(
                code = "NO_CLIENT",
                message = "Client or transport not available"
            )))
            return
        }

        try {
            val callClient = dailyTransport.callClient
                ?: throw Exception("CallClient not available")

            val remoteParticipants = callClient.participants().all.values
                .filter { !it.info.isLocal }

            for (participant in remoteParticipants) {
                callClient.updateRemoteParticipants(
                    mapOf(
                        participant.id to RemoteParticipantUpdate(
                            inputsEnabled = RemoteInputsEnabledUpdate(
                                microphone = !isMuted
                            )
                        )
                    )
                )
            }

            this.isBotAudioMuted = isMuted
            inputStatusUpdatedHandler?.sendEvent(
                InputStatusUpdatedEvent(
                    isCurrentMicrophoneEnabled = client?.isMicEnabled ?: false,
                    isCurrentCameraEnabled = client?.isCamEnabled ?: false,
                    isBotAudioMuted = isMuted
                )
            )
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError(
                code = "MUTE_ERROR",
                message = e.localizedMessage ?: e.toString()
            )))
        }
    }

    // -- Helpers --

    private fun updateInputState() {
        val currentClient = client ?: return

        inputStatusUpdatedHandler?.sendEvent(
            InputStatusUpdatedEvent(
                isCurrentMicrophoneEnabled = currentClient.isMicEnabled,
                isCurrentCameraEnabled = currentClient.isCamEnabled,
                isBotAudioMuted = isBotAudioMuted
            )
        )
    }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    // -- PipecatEventCallbacks --

    private fun createCallbacks(): PipecatEventCallbacks {
        return object : PipecatEventCallbacks() {

            override fun onConnected() {
                runOnMain {
                    connectionStateHandler?.sendEvent(
                        ConnectionStateEvent(state = ConnectionState.CONNECTED)
                    )
                    updateInputState()
                }
            }

            override fun onDisconnected() {
                runOnMain {
                    connectionStateHandler?.sendEvent(
                        ConnectionStateEvent(state = ConnectionState.DISCONNECTED)
                    )
                }
            }

            override fun onTransportStateChanged(state: TransportState) {
                runOnMain {
                    val connectionState = when (state) {
                        TransportState.Initializing,
                        TransportState.Initialized,
                        TransportState.Connecting,
                        TransportState.Authorizing,
                        TransportState.Authorized -> ConnectionState.CONNECTING
                        TransportState.Ready,
                        TransportState.Connected -> ConnectionState.CONNECTED
                        TransportState.Disconnected,
                        TransportState.Error -> ConnectionState.DISCONNECTED
                    }
                    connectionStateHandler?.sendEvent(
                        ConnectionStateEvent(state = connectionState)
                    )
                    updateInputState()
                }
            }

            override fun onBackendError(message: String) {
                runOnMain {
                    eventStreamHandler?.sendEvent(BackendErrorEvent(message = message))
                }
            }

            override fun onUserStartedSpeaking() {
                runOnMain {
                    speakingEventHandler?.sendEvent(
                        SpeakingEvent(state = SpeakingState.USER_STARTED_SPEAKING)
                    )
                }
            }

            override fun onUserStoppedSpeaking() {
                runOnMain {
                    speakingEventHandler?.sendEvent(
                        SpeakingEvent(state = SpeakingState.USER_STOPPED_SPEAKING)
                    )
                }
            }

            override fun onBotStartedSpeaking() {
                runOnMain {
                    speakingEventHandler?.sendEvent(
                        SpeakingEvent(state = SpeakingState.BOT_STARTED_SPEAKING)
                    )
                }
            }

            override fun onBotStoppedSpeaking() {
                runOnMain {
                    speakingEventHandler?.sendEvent(
                        SpeakingEvent(state = SpeakingState.BOT_STOPPED_SPEAKING)
                    )
                }
            }

            override fun onBotOutput(data: BotOutputData) {
                runOnMain {
                    botOutputHandler?.sendEvent(
                        BotOutputEvent(
                            text = data.text,
                            isSpoken = data.spoken,
                            aggregatedBy = data.aggregatedBy
                        )
                    )
                }
            }

            override fun onUserTranscript(data: Transcript) {
                runOnMain {
                    userTranscriptionHandler?.sendEvent(
                        UserTranscriptionEvent(
                            text = data.text,
                            isFinal = data.final,
                            timestamp = data.timestamp ?: "",
                            userId = data.userId ?: ""
                        )
                    )
                }
            }

            override fun onBotLLMText(data: MsgServerToClient.Data.BotLLMTextData) {
                runOnMain {
                    eventStreamHandler?.sendEvent(BotLLMText(text = data.text))
                }
            }

            override fun onBotTTSText(data: MsgServerToClient.Data.BotTTSTextData) {
                runOnMain {
                    eventStreamHandler?.sendEvent(BotTTSText(text = data.text))
                }
            }

            override fun onBotLLMStarted() {
                runOnMain {
                    eventStreamHandler?.sendEvent(
                        ServerInsightEvent(type = InsightType.BOT_LLM_STARTED)
                    )
                }
            }

            override fun onBotLLMStopped() {
                runOnMain {
                    eventStreamHandler?.sendEvent(
                        ServerInsightEvent(type = InsightType.BOT_LLM_STOPPED)
                    )
                }
            }

            override fun onBotTTSStarted() {
                runOnMain {
                    eventStreamHandler?.sendEvent(
                        ServerInsightEvent(type = InsightType.BOT_TTS_STARTED)
                    )
                }
            }

            override fun onBotTTSStopped() {
                runOnMain {
                    eventStreamHandler?.sendEvent(
                        ServerInsightEvent(type = InsightType.BOT_TTS_STOPPED)
                    )
                }
            }

            override fun onInputsUpdated(camera: Boolean, mic: Boolean) {
                runOnMain {
                    inputStatusUpdatedHandler?.sendEvent(
                        InputStatusUpdatedEvent(
                            isCurrentMicrophoneEnabled = mic,
                            isCurrentCameraEnabled = camera,
                            isBotAudioMuted = isBotAudioMuted
                        )
                    )
                }
            }

            override fun onUserAudioLevel(level: Float) {
                runOnMain {
                    localAudioHandler?.sendLevel(level.toDouble())
                }
            }

            override fun onRemoteAudioLevel(level: Float, participant: Participant) {
                runOnMain {
                    remoteAudioHandler?.sendLevel(level.toDouble())
                }
            }
        }
    }
}

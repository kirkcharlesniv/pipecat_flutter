package com.kcniverba

import ai.pipecat.client.PipecatClient
import ai.pipecat.client.PipecatClientOptions
import ai.pipecat.client.PipecatEventCallbacks
import ai.pipecat.client.daily.DailyTransport
import ai.pipecat.client.daily.DailyTransportConnectParams
import ai.pipecat.client.result.Result as PipecatResult
import ai.pipecat.client.result.RTVIError
import ai.pipecat.client.transport.MsgClientToServer
import ai.pipecat.client.transport.MsgServerToClient
import ai.pipecat.client.types.BotOutputData
import ai.pipecat.client.types.BotReadyData
import ai.pipecat.client.types.LLMFunctionCallData
import ai.pipecat.client.types.LLMFunctionCallResult
import ai.pipecat.client.types.Participant
import ai.pipecat.client.types.PipecatMetrics
import ai.pipecat.client.types.PipecatMetricsData
import ai.pipecat.client.types.SendTextOptions
import ai.pipecat.client.types.TransportState
import ai.pipecat.client.types.Transcript
import ai.pipecat.client.types.Value
import android.content.Context
import android.os.Handler
import android.os.Looper
import co.daily.CallClientListener
import co.daily.model.MeetingToken
import co.daily.model.ParticipantId as DailyParticipantId
import co.daily.model.RequestListener
import co.daily.settings.InputSettings
import co.daily.settings.PublishingSettings
import co.daily.settings.subscription.AudioSubscriptionSettingsUpdate
import co.daily.settings.subscription.MediaSubscriptionSettingsUpdate
import co.daily.settings.subscription.Subscribed
import co.daily.settings.subscription.SubscriptionSettings
import co.daily.settings.subscription.SubscriptionSettingsUpdate
import co.daily.settings.subscription.SubscriptionState
import co.daily.settings.subscription.Unsubscribed
import com.kcniverba.pipecat_flutter_android.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.decodeFromJsonElement
import java.lang.reflect.Modifier

class PipecatFlutterPlugin : FlutterPlugin, PipecatHostApi {
    companion object {
        private const val USER_MUTE_COMPAT_BRIDGE = "rtvi_user_mute_v1"
    }

    private var client: PipecatClient<DailyTransport, DailyTransportConnectParams>? = null
    private var transport: DailyTransport? = null
    private var applicationContext: Context? = null
    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

    private var timelineHandler: TimelineEventHandlerImpl? = null
    private var localAudioHandler: LocalAudioLevelHandlerImpl? = null
    private var remoteAudioHandler: RemoteAudioLevelHandlerImpl? = null

    private var isBotAudioMuted: Boolean = false
    private var botDailyParticipantId: DailyParticipantId? = null
    private var dailyCallClientListener: CallClientListener? = null
    private val localMicController: LocalMicStateController by lazy {
        createLocalMicController()
    }

    private var activeSessionEpoch: Long = 0
    private var sequenceCounter: Long = 0
    private var disconnectedEpoch: Long = -1
    private var lastConnectionState: ConnectionState? = null
    private var lastSpeakingState: SpeakingState? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val messenger = binding.binaryMessenger

        PipecatHostApi.setUp(messenger, this)

        timelineHandler = TimelineEventHandlerImpl().also {
            TimelineEventsStreamHandler.register(messenger, it)
        }
        localAudioHandler = LocalAudioLevelHandlerImpl().also {
            LocalAudioLevelStreamHandler.register(messenger, it)
        }
        remoteAudioHandler = RemoteAudioLevelHandlerImpl().also {
            RemoteAudioLevelStreamHandler.register(messenger, it)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PipecatHostApi.setUp(binding.binaryMessenger, null)
        cleanupClient(release = true)
        applicationContext = null
    }

    override fun startAndConnect(parameters: StartBotParams, callback: (Result<Unit>) -> Unit) {
        if (client != null) {
            callback(
                Result.failure(
                    FlutterError(
                        code = "ALREADY_CONNECTED",
                        message = "Client already exists. Disconnect first.",
                    )
                )
            )
            return
        }

        val context = applicationContext ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_CONTEXT",
                        message = "Application context not available",
                    )
                )
            )
            return
        }

        val sessionEpoch = beginNewSessionEpoch()
        resetLocalMicController(parameters.shouldEnableMicrophone)
        emitTimelineEvent(
            event = ConnectionStateEvent(state = ConnectionState.CONNECTING),
            sessionEpoch = sessionEpoch,
        )

        val newTransport = DailyTransport(context)
        val options = PipecatClientOptions(
            callbacks = createCallbacks(sessionEpoch),
            enableMic = parameters.shouldEnableMicrophone,
            enableCam = parameters.shouldEnableCamera,
        )
        val newClient = PipecatClient(newTransport, options)

        transport = newTransport
        client = newClient

        val listener = createCallClientListener(sessionEpoch)
        dailyCallClientListener = listener
        newTransport.callClient?.addListener(listener)

        val connectParams = DailyTransportConnectParams(
            dailyRoom = parameters.url,
            dailyToken = parameters.token?.let { MeetingToken(it) },
        )
        observeCurrentLocalMicSnapshot()

        val proceedConnect = {
            newClient.connect(connectParams).withCallback { result ->
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) {
                        return@runOnMain
                    }

                    when (result) {
                        is PipecatResult.Ok -> {
                            observeCurrentLocalMicSnapshot()
                            updateInputState(sessionEpoch)
                            callback(Result.success(Unit))
                        }

                        is PipecatResult.Err -> {
                            cleanupFailedConnect(sessionEpoch)
                            callback(
                                Result.failure(
                                    FlutterError(
                                        code = "CONNECT_ERROR",
                                        message = result.error.toString(),
                                    )
                                )
                            )
                        }
                    }
                }
            }
        }

        if (parameters.shouldEnableMicrophone) {
            proceedConnect()
        } else {
            localMicController.updateDesiredEnabled(false) { result ->
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) {
                        return@runOnMain
                    }

                    result.fold(
                        onSuccess = {
                            proceedConnect()
                        },
                        onFailure = { error ->
                            cleanupFailedConnect(sessionEpoch)
                            callback(Result.failure(mapLocalMicError(error)))
                        },
                    )
                }
            }
        }
    }

    override fun disconnect(callback: (Result<Unit>) -> Unit) {
        val sessionEpoch = activeSessionEpoch
        val currentClient = client
        if (currentClient == null) {
            isBotAudioMuted = false
            botDailyParticipantId = null
            resetLocalMicController()
            if (sessionEpoch > 0) {
                emitDisconnectedIfNeeded(sessionEpoch)
            }
            callback(Result.success(Unit))
            return
        }

        currentClient.disconnect().withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> {
                        if (client === currentClient) {
                            cleanupClient(release = true)
                        }
                        isBotAudioMuted = false
                        emitDisconnectedIfNeeded(sessionEpoch)
                        callback(Result.success(Unit))
                    }

                    is PipecatResult.Err -> {
                        if (client === currentClient) {
                            cleanupClient(release = true)
                        }
                        isBotAudioMuted = false
                        emitDisconnectedIfNeeded(sessionEpoch)
                        callback(
                            Result.failure(
                                FlutterError(
                                    code = "DISCONNECT_ERROR",
                                    message = result.error.toString(),
                                )
                            )
                        )
                    }
                }
            }
        }
    }

    override fun toggleMicrophone(isEnabled: Boolean, callback: (Result<Unit>) -> Unit) {
        transport?.callClient ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_CLIENT",
                        message = "Client not available",
                    )
                )
            )
            return
        }

        val epoch = activeSessionEpoch
        runOnMain {
            if (!isEnabled) {
                emitMutedLocalAudioState(epoch)
            }
            localMicController.updateDesiredEnabled(isEnabled) { result ->
                runOnMain {
                    if (!isCurrentEpoch(epoch)) {
                        return@runOnMain
                    }
                    updateInputState(epoch)
                    result.fold(
                        onSuccess = {
                            callback(Result.success(Unit))
                        },
                        onFailure = { error ->
                            callback(Result.failure(mapLocalMicError(error)))
                        },
                    )
                }
            }
        }
    }

    override fun toggleCamera(isEnabled: Boolean, callback: (Result<Unit>) -> Unit) {
        val currentClient = client ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_CLIENT",
                        message = "Client not available",
                    )
                )
            )
            return
        }

        val epoch = activeSessionEpoch
        currentClient.enableCam(isEnabled).withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> {
                        updateInputState(epoch)
                        callback(Result.success(Unit))
                    }

                    is PipecatResult.Err -> {
                        callback(
                            Result.failure(
                                FlutterError(
                                    code = "CAMERA_ERROR",
                                    message = result.error.toString(),
                                )
                            )
                        )
                    }
                }
            }
        }
    }

    override fun muteBotAudio(isMuted: Boolean, callback: (Result<Unit>) -> Unit) {
        runOnMain {
            val callClient = transport?.callClient ?: run {
                callback(
                    Result.failure(
                        FlutterError(
                            code = "NO_CLIENT",
                            message = "Client or transport not available",
                        )
                    )
                )
                return@runOnMain
            }

            val botId = botDailyParticipantId ?: run {
                callback(
                    Result.failure(
                        FlutterError(
                            code = "BOT_NOT_CONNECTED",
                            message = "Bot participant not connected",
                        )
                    )
                )
                return@runOnMain
            }

            val epoch = activeSessionEpoch
            callClient.updateSubscriptionsForParticipants(
                mapOf(
                    botId to SubscriptionSettingsUpdate(
                        media = MediaSubscriptionSettingsUpdate(
                            microphone = AudioSubscriptionSettingsUpdate(
                                subscriptionState = if (isMuted) Unsubscribed() else Subscribed()
                            )
                        )
                    )
                ),
                RequestListener { result ->
                    runOnMain {
                        if (result.isError) {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        code = "MUTE_ERROR",
                                        message = result.error?.toString() ?: "Unknown error",
                                    )
                                )
                            )
                        } else {
                            isBotAudioMuted = isMuted
                            updateInputState(epoch)
                            callback(Result.success(Unit))
                        }
                    }
                }
            )
        }
    }

    override fun sendText(parameters: SendTextParams, callback: (Result<Unit>) -> Unit) {
        val currentClient = client ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_CLIENT",
                        message = "Client not available",
                    )
                )
            )
            return
        }

        currentClient.sendText(
            parameters.content,
            SendTextOptions(
                runImmediately = parameters.runImmediately,
                audioResponse = parameters.audioResponse,
            )
        ).withCallback { result ->
            runOnMain {
                when (result) {
                    is PipecatResult.Ok -> callback(Result.success(Unit))
                    is PipecatResult.Err -> {
                        callback(
                            Result.failure(
                                FlutterError(
                                    code = "SEND_TEXT_ERROR",
                                    message = result.error.toString(),
                                )
                            )
                        )
                    }
                }
            }
        }
    }

    override fun sendLlmFunctionCallResult(
        parameters: SendLlmFunctionCallResultParams,
        callback: (Result<Unit>) -> Unit
    ) {
        val dailyTransport = transport ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_TRANSPORT",
                        message = "Transport not available",
                    )
                )
            )
            return
        }

        val arguments = parseJsonElement(parameters.argumentsJson)
        val result = parseJsonElement(parameters.resultJson)

        val message = MsgClientToServer.LlmFunctionCallResult(
            msgId = java.util.UUID.randomUUID().toString(),
            data = LLMFunctionCallResult(
                functionName = parameters.functionName,
                toolCallID = parameters.toolCallId,
                arguments = arguments,
                result = result,
            )
        )

        dailyTransport.sendMessage(message).withCallback { sendResult ->
            runOnMain {
                when (sendResult) {
                    is PipecatResult.Ok -> callback(Result.success(Unit))
                    is PipecatResult.Err -> {
                        callback(
                            Result.failure(
                                FlutterError(
                                    code = "SEND_FUNCTION_RESULT_ERROR",
                                    message = sendResult.error.toString(),
                                )
                            )
                        )
                    }
                }
            }
        }
    }

    override fun sendClientMessage(
        parameters: SendClientMessageParams,
        callback: (Result<Unit>) -> Unit
    ) {
        val dailyTransport = transport ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_TRANSPORT",
                        message = "Transport not available",
                    )
                )
            )
            return
        }

        val data = parseJsonElement(parameters.dataJson)
        val message = MsgClientToServer.ClientMessage(
            id = java.util.UUID.randomUUID().toString(),
            msgType = parameters.msgType,
            data = data,
        )

        dailyTransport.sendMessage(message).withCallback { sendResult ->
            runOnMain {
                when (sendResult) {
                    is PipecatResult.Ok -> callback(Result.success(Unit))
                    is PipecatResult.Err -> {
                        callback(
                            Result.failure(
                                FlutterError(
                                    code = "SEND_CLIENT_MESSAGE_ERROR",
                                    message = sendResult.error.toString(),
                                )
                            )
                        )
                    }
                }
            }
        }
    }

    override fun sendClientRequest(
        parameters: SendClientRequestParams,
        callback: (Result<SendClientRequestResult>) -> Unit
    ) {
        val currentClient = client ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        code = "NO_CLIENT",
                        message = "Client not available",
                    )
                )
            )
            return
        }

        val requestData = parseJsonValue(parameters.dataJson)
        currentClient.sendClientRequest(
            parameters.msgType,
            requestData,
        ).withCallback { requestResult ->
            runOnMain {
                when (requestResult) {
                    is PipecatResult.Ok -> {
                        val responseData = requestResult.value
                        val responseJson = Json.encodeToString(
                            JsonElement.serializer(),
                            responseData.data,
                        )
                        callback(
                            Result.success(
                                SendClientRequestResult(
                                    msgType = responseData.msgType,
                                    dataJson = responseJson,
                                )
                            )
                        )
                    }

                    is PipecatResult.Err -> {
                        callback(
                            Result.failure(
                                mapClientRequestError(requestResult.error)
                            )
                        )
                    }
                }
            }
        }
    }

    private fun beginNewSessionEpoch(): Long {
        activeSessionEpoch += 1
        sequenceCounter = 0
        disconnectedEpoch = -1
        lastConnectionState = null
        lastSpeakingState = null
        botDailyParticipantId = null
        return activeSessionEpoch
    }

    private fun isCurrentEpoch(sessionEpoch: Long): Boolean {
        return sessionEpoch > 0 && sessionEpoch == activeSessionEpoch
    }

    private fun cleanupFailedConnect(sessionEpoch: Long) {
        if (!isCurrentEpoch(sessionEpoch)) return

        val staleClient = client
        val staleTransport = transport
        client = null
        transport = null
        isBotAudioMuted = false
        botDailyParticipantId = null
        resetLocalMicController()
        dailyCallClientListener?.let { listener ->
            staleTransport?.callClient?.removeListener(listener)
            dailyCallClientListener = null
        }
        emitDisconnectedIfNeeded(sessionEpoch)

        // Delay release() to let native threads finish after a connection failure.
        // Calling release() immediately can cause a SIGSEGV in libdaily-android-sdk.so
        // when its worker thread accesses freed memory.
        if (staleClient != null) {
            mainHandler.postDelayed({
                try {
                    staleClient.release()
                } catch (_: Exception) {}
            }, 5000)
        }
    }

    private fun cleanupClient(release: Boolean) {
        val existing = client
        val existingTransport = transport
        client = null
        transport = null
        botDailyParticipantId = null
        resetLocalMicController()
        dailyCallClientListener?.let { listener ->
            existingTransport?.callClient?.removeListener(listener)
            dailyCallClientListener = null
        }
        if (release && existing != null) {
            try {
                existing.release()
            } catch (_: Exception) {
                // Swallow — native resources may already be invalid after connection failure
            }
        }
    }

    private fun emitDisconnectedIfNeeded(sessionEpoch: Long) {
        if (sessionEpoch <= 0) return
        if (disconnectedEpoch == sessionEpoch) return

        emitTimelineEvent(
            event = ConnectionStateEvent(state = ConnectionState.DISCONNECTED),
            sessionEpoch = sessionEpoch,
        )
    }

    private fun emitTimelineEvent(event: PipecatEvent, sessionEpoch: Long) {
        if (sessionEpoch <= 0 || sessionEpoch != activeSessionEpoch) {
            return
        }

        if (event is ConnectionStateEvent) {
            if (lastConnectionState == event.state) {
                return
            }
            lastConnectionState = event.state
            if (event.state == ConnectionState.DISCONNECTED) {
                disconnectedEpoch = sessionEpoch
                lastSpeakingState = null
            }
        }

        if (event is SpeakingEvent) {
            if (lastSpeakingState == event.state) {
                return
            }
            lastSpeakingState = event.state
        }

        sequenceCounter += 1
        timelineHandler?.sendEvent(
            TimelineEvent(
                sequence = sequenceCounter,
                sessionEpoch = sessionEpoch,
                emittedAtMs = System.currentTimeMillis(),
                event = event,
            )
        )
    }

    private fun updateInputState(sessionEpoch: Long) {
        val currentClient = client ?: return
        val dailyClient = transport?.callClient
        val isMicEnabled = localMicController.currentMicEnabled(currentClient.isMicEnabled)
        val isCameraEnabled = runCatching {
            dailyClient?.inputs()?.camera?.isEnabled
        }.getOrNull() ?: currentClient.isCamEnabled

        emitTimelineEvent(
            event = InputStatusUpdatedEvent(
                isCurrentMicrophoneEnabled = isMicEnabled,
                isCurrentCameraEnabled = isCameraEnabled,
                isBotAudioMuted = isBotAudioMuted,
            ),
            sessionEpoch = sessionEpoch,
        )
    }

    private fun getLocalMicSnapshot(): LocalMicSnapshot? {
        val callClient = transport?.callClient ?: return null
        return runCatching {
            LocalMicSnapshot(
                inputEnabled = callClient.inputs().microphone.isEnabled,
                publishingEnabled = callClient.publishing().microphone.isPublishing,
            )
        }.getOrNull()
    }

    private fun createLocalMicController(): LocalMicStateController {
        return LocalMicStateController(
            delegate = object : LocalMicStateControllerDelegate {
                override fun issueSetInputEnabled(
                    enabled: Boolean,
                    completion: (Result<Unit>) -> Unit,
                ) {
                    val callClient = transport?.callClient
                    if (callClient == null) {
                        completion(
                            Result.failure(
                                FlutterError(
                                    code = "NO_CLIENT",
                                    message = "Client not available",
                                )
                            )
                        )
                        return
                    }

                    callClient.setInputsEnabled(
                        microphone = enabled,
                        listener = RequestListener { result ->
                            val mapped = if (result.isError) {
                                Result.failure<Unit>(
                                    FlutterError(
                                        code = "MIC_ERROR",
                                        message = result.error?.toString() ?: "Unknown error",
                                    )
                                )
                            } else {
                                Result.success(Unit)
                            }
                            runOnMain {
                                completion(mapped)
                            }
                        },
                    )
                }

                override fun issueSetPublishingEnabled(
                    enabled: Boolean,
                    completion: (Result<Unit>) -> Unit,
                ) {
                    val callClient = transport?.callClient
                    if (callClient == null) {
                        completion(
                            Result.failure(
                                FlutterError(
                                    code = "NO_CLIENT",
                                    message = "Client not available",
                                )
                            )
                        )
                        return
                    }

                    callClient.setIsPublishing(
                        microphone = enabled,
                        listener = RequestListener { result ->
                            val mapped = if (result.isError) {
                                Result.failure<Unit>(
                                    FlutterError(
                                        code = "MIC_ERROR",
                                        message = result.error?.toString() ?: "Unknown error",
                                    )
                                )
                            } else {
                                Result.success(Unit)
                            }
                            runOnMain {
                                completion(mapped)
                            }
                        },
                    )
                }

                override fun readSnapshot(): LocalMicSnapshot? {
                    return getLocalMicSnapshot()
                }

                override fun schedule(delayMs: Long, action: () -> Unit): LocalMicScheduledTask {
                    val runnable = Runnable {
                        runOnMain(action)
                    }
                    mainHandler.postDelayed(runnable, delayMs)
                    return LocalMicScheduledTask {
                        mainHandler.removeCallbacks(runnable)
                    }
                }
            },
        )
    }

    private fun resetLocalMicController(desiredEnabled: Boolean = true) {
        localMicController.reset(desiredEnabled = desiredEnabled)
    }

    private fun observeCurrentLocalMicSnapshot() {
        val snapshot = getLocalMicSnapshot() ?: return
        localMicController.observeSnapshot(snapshot)
    }

    private fun mapLocalMicError(error: Throwable): FlutterError {
        return if (error is LocalMicStateControllerError) {
            FlutterError(
                code = error.code,
                message = error.message,
            )
        } else if (error is FlutterError) {
            error
        } else {
            FlutterError(
                code = "MIC_ERROR",
                message = error.message ?: error.toString(),
            )
        }
    }

    private fun isLocalMicSendingAudio(): Boolean {
        return localMicController.isSendingAudio
    }

    private fun emitMutedLocalAudioState(sessionEpoch: Long) {
        if (!isCurrentEpoch(sessionEpoch)) return
        localAudioHandler?.sendLevel(0.0)
        if (lastSpeakingState == SpeakingState.USER_STARTED_SPEAKING) {
            emitTimelineEvent(
                event = SpeakingEvent(state = SpeakingState.USER_STOPPED_SPEAKING),
                sessionEpoch = sessionEpoch,
            )
        }
    }

    private fun emitMutedMicTranscriptDiagnosticIfNeeded(
        transcript: Transcript,
        sessionEpoch: Long,
    ) {
        if (isLocalMicSendingAudio()) return

        emitTimelineEvent(
            event = ServerMessageEvent(
                rawJson = toCanonicalJson(
                    linkedMapOf(
                        "type" to "local_mic_muted_transcript_detected",
                        "source" to "daily_android",
                        "mic_desired_enabled" to localMicController.desiredEnabled,
                        "mic_input_enabled" to localMicController.observedSnapshot?.inputEnabled,
                        "mic_publishing_enabled" to localMicController.observedSnapshot?.publishingEnabled,
                        "is_final" to transcript.final,
                        "text" to transcript.text,
                    )
                ),
            ),
            sessionEpoch = sessionEpoch,
        )
    }

    private fun createCallClientListener(sessionEpoch: Long): CallClientListener {
        return object : CallClientListener {
            override fun onInputsUpdated(inputSettings: InputSettings) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    observeCurrentLocalMicSnapshot()
                    updateInputState(activeSessionEpoch)
                }
            }

            override fun onPublishingUpdated(publishingSettings: PublishingSettings) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    observeCurrentLocalMicSnapshot()
                    updateInputState(activeSessionEpoch)
                }
            }

            override fun onSubscriptionsUpdated(subscriptions: Map<DailyParticipantId, SubscriptionSettings>) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    val botId = botDailyParticipantId ?: return@runOnMain
                    val micState = subscriptions[botId]?.media?.microphone?.subscriptionState
                        ?: return@runOnMain
                    val isNowMuted = micState == SubscriptionState.unsubscribed
                    if (isNowMuted != isBotAudioMuted) {
                        isBotAudioMuted = isNowMuted
                        updateInputState(activeSessionEpoch)
                    }
                }
            }
        }
    }

    private fun mapTransportState(state: TransportState): ConnectionState {
        return when (state) {
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
    }

    private fun mapMetrics(samples: List<PipecatMetricsData>?): List<PipecatMetricSample>? {
        return samples?.map { PipecatMetricSample(processor = it.processor, value = it.value) }
    }

    private fun metricsRawJson(data: PipecatMetrics): String {
        val payload = mutableMapOf<String, Any?>()
        val processing = data.processing
        if (processing != null) {
            payload["processing"] = processing.map {
                mapOf(
                    "processor" to it.processor,
                    "value" to it.value,
                )
            }
        }
        val ttfb = data.ttfb
        if (ttfb != null) {
            payload["ttfb"] = ttfb.map {
                mapOf(
                    "processor" to it.processor,
                    "value" to it.value,
                )
            }
        }
        return toCanonicalJson(payload)
    }

    private fun valueToCanonicalJson(value: Value?): String? {
        if (value == null || value is Value.Null) return null
        return toCanonicalJson(valueToPlainObject(value))
    }

    private fun emitTransportDiagnosticIfNeeded(
        state: TransportState,
        sessionEpoch: Long,
    ) {
        val stage = state.name.lowercase()
        if (stage != "connected" && stage != "ready") return

        val dailyTransport = transport ?: return
        val callClient = dailyTransport.callClient ?: return

        val payload = linkedMapOf<String, Any?>(
            "type" to "transport.diagnostic",
            "source" to "daily_android",
            "stage" to stage,
            "transport_state" to stage,
            "captured_at_ms" to System.currentTimeMillis(),
        )

        invokeGetter(callClient, "getCallState")?.let {
            payload["call_state"] = reflectionValueToPlainObject(it)
        }
        invokeGetter(callClient, "getParticipantCounts")?.let {
            payload["participant_counts"] = reflectionValueToPlainObject(it)
        }
        invokeGetter(callClient, "getNetworkStatistics", "getNetworkStats")?.let {
            payload["network"] = reflectionValueToPlainObject(it)
        }
        invokeGetter(callClient, "getIceConfig")?.let {
            payload["ice_config"] = reflectionValueToPlainObject(it)
        }
        invokeGetter(callClient, "getMeetingSession")?.let {
            payload["meeting_session"] = reflectionValueToPlainObject(it)
        }

        emitTimelineEvent(
            event = ServerMessageEvent(rawJson = toCanonicalJson(payload)),
            sessionEpoch = sessionEpoch,
        )
    }

    private fun invokeGetter(target: Any, vararg methodNames: String): Any? {
        for (methodName in methodNames) {
            val method = target.javaClass.methods.firstOrNull {
                it.name == methodName && it.parameterCount == 0
            } ?: continue
            val result = runCatching { method.invoke(target) }.getOrNull()
            if (result != null) {
                return result
            }
        }
        return null
    }

    private fun reflectionValueToPlainObject(value: Any?, depth: Int = 0): Any? {
        if (value == null) return null
        if (depth >= 3) return value.toString()

        return when (value) {
            is String,
            is Boolean,
            is Int,
            is Long,
            is Short,
            is Byte
            -> value

            is Float -> if (value.isFinite()) value else null
            is Double -> if (value.isFinite()) value else null
            is Enum<*> -> value.name.lowercase()
            is Map<*, *> -> buildMap<String, Any?> {
                value.forEach { (key, nestedValue) ->
                    val normalizedKey = key?.toString() ?: return@forEach
                    val serialized = reflectionValueToPlainObject(
                        nestedValue,
                        depth + 1,
                    )
                    if (serialized != null) {
                        put(normalizedKey, serialized)
                    }
                }
            }

            is Iterable<*> -> value.mapNotNull {
                reflectionValueToPlainObject(it, depth + 1)
            }

            else -> {
                val serialized = linkedMapOf<String, Any?>()
                val getters = value.javaClass.methods
                    .filter { method ->
                        Modifier.isPublic(method.modifiers) &&
                            method.parameterCount == 0 &&
                            method.returnType != Void.TYPE &&
                            (method.name.startsWith("get") || method.name.startsWith("is")) &&
                            method.name != "getClass"
                    }
                    .sortedBy { it.name }

                for (getter in getters) {
                    val nested = runCatching { getter.invoke(value) }.getOrNull()
                    val serializedValue = reflectionValueToPlainObject(
                        nested,
                        depth + 1,
                    ) ?: continue
                    serialized[getterNameToKey(getter.name)] = serializedValue
                }

                if (serialized.isEmpty()) value.toString() else serialized
            }
        }
    }

    private fun getterNameToKey(name: String): String {
        val raw = when {
            name.startsWith("get") -> name.removePrefix("get")
            name.startsWith("is") -> name.removePrefix("is")
            else -> name
        }
        if (raw.isEmpty()) return name
        return raw.replaceFirstChar { it.lowercase() }
    }

    private fun valueToPlainObject(value: Value): Any? {
        return when (value) {
            is Value.Null -> null
            is Value.Str -> value.value
            is Value.Bool -> value.value
            is Value.Number -> value.value
            is Value.Array -> value.value.map { valueToPlainObject(it) }
            is Value.Object -> value.value.mapValues { valueToPlainObject(it.value) }
        }
    }

    private fun toCanonicalJson(value: Any?): String {
        return when (value) {
            null -> "null"
            is String -> jsonQuoted(value)
            is Boolean -> if (value) "true" else "false"
            is Int, is Long, is Short, is Byte -> value.toString()
            is Float -> {
                if (!value.isFinite()) "null" else value.toString()
            }

            is Double -> {
                if (!value.isFinite()) "null" else value.toString()
            }

            is List<*> -> value.joinToString(
                separator = ",",
                prefix = "[",
                postfix = "]",
            ) { entry -> toCanonicalJson(entry) }

            is Map<*, *> -> {
                val keys = value.keys.mapNotNull { it as? String }.sorted()
                keys.joinToString(
                    separator = ",",
                    prefix = "{",
                    postfix = "}",
                ) { key ->
                    "${jsonQuoted(key)}:${toCanonicalJson(value[key])}"
                }
            }

            else -> jsonQuoted(value.toString())
        }
    }

    private fun jsonQuoted(value: String): String {
        val escaped = StringBuilder(value.length + 2)
        escaped.append('"')
        value.forEach { character ->
            when (character) {
                '\\' -> escaped.append("\\\\")
                '"' -> escaped.append("\\\"")
                '\b' -> escaped.append("\\b")
                '\u000c' -> escaped.append("\\f")
                '\n' -> escaped.append("\\n")
                '\r' -> escaped.append("\\r")
                '\t' -> escaped.append("\\t")
                else -> {
                    if (character.code < 0x20) {
                        escaped.append("\\u")
                        escaped.append(character.code.toString(16).padStart(4, '0'))
                    } else {
                        escaped.append(character)
                    }
                }
            }
        }
        escaped.append('"')
        return escaped.toString()
    }

    private fun parseJsonElement(rawJson: String?): JsonElement {
        if (rawJson == null) return JsonNull
        val trimmed = rawJson.trim()
        if (trimmed.isEmpty()) return JsonNull
        return try {
            Json.parseToJsonElement(trimmed)
        } catch (_: Exception) {
            JsonNull
        }
    }

    private fun parseJsonValue(rawJson: String?): Value {
        val element = parseJsonElement(rawJson)
        return try {
            Json.decodeFromJsonElement<Value>(element)
        } catch (_: Exception) {
            Value.Null
        }
    }

    private fun mapClientRequestError(error: RTVIError): FlutterError {
        return when (error) {
            RTVIError.Timeout -> FlutterError(
                code = "SEND_CLIENT_REQUEST_TIMEOUT",
                message = error.toString(),
            )

            is RTVIError.ErrorResponse -> FlutterError(
                code = "SEND_CLIENT_REQUEST_ERROR_RESPONSE",
                message = error.message,
            )

            else -> FlutterError(
                code = "SEND_CLIENT_REQUEST_ERROR",
                message = error.toString(),
            )
        }
    }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    private fun createCallbacks(sessionEpoch: Long): PipecatEventCallbacks {
        return object : PipecatEventCallbacks() {
            override fun onConnected() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = ConnectionStateEvent(state = ConnectionState.CONNECTED),
                        sessionEpoch = sessionEpoch,
                    )
                    observeCurrentLocalMicSnapshot()
                    updateInputState(sessionEpoch)
                }
            }

            override fun onDisconnected() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitDisconnectedIfNeeded(sessionEpoch)
                }
            }

            override fun onTransportStateChanged(state: TransportState) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain

                    val mapped = mapTransportState(state)
                    if (mapped == ConnectionState.DISCONNECTED) {
                        emitDisconnectedIfNeeded(sessionEpoch)
                    } else {
                        emitTimelineEvent(
                            event = ConnectionStateEvent(state = mapped),
                            sessionEpoch = sessionEpoch,
                        )
                    }
                    observeCurrentLocalMicSnapshot()
                    updateInputState(sessionEpoch)

                    // Emit raw sub-state so Dart can record fine-grained timing and
                    // show granular progress messages without pigeon API changes.
                    val subStateJson = """{"type":"transport.sub_state","state":"${state.name}"}"""
                    emitTimelineEvent(
                        event = ServerMessageEvent(rawJson = subStateJson),
                        sessionEpoch = sessionEpoch,
                    )
                    emitTransportDiagnosticIfNeeded(
                        state = state,
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBackendError(message: String) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = BackendErrorEvent(message = message),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotConnected(participant: Participant) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    botDailyParticipantId = transport?.callClient
                        ?.participants()?.all?.entries
                        ?.firstOrNull { !it.value.info.isLocal }?.key
                    emitTimelineEvent(
                        event = BotConnectionEvent(
                            state = BotConnectionState.CONNECTED,
                            participantId = participant.id.id,
                            participantName = participant.name,
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotReady(data: BotReadyData) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = BotReadyEvent(
                            version = data.version,
                            aboutJson = valueToCanonicalJson(data.about),
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotDisconnected(participant: Participant) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    botDailyParticipantId = null
                    isBotAudioMuted = false
                    emitTimelineEvent(
                        event = BotConnectionEvent(
                            state = BotConnectionState.DISCONNECTED,
                            participantId = participant.id.id,
                            participantName = participant.name,
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onMetrics(data: PipecatMetrics) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = MetricsEvent(
                            processing = mapMetrics(data.processing),
                            ttfb = mapMetrics(data.ttfb),
                            rawJson = metricsRawJson(data),
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onServerMessage(data: Value) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    val userMuteEvent = parseUserMuteEventFromValue(data)
                    emitTimelineEvent(
                        event = ServerMessageEvent(
                            rawJson = valueToCanonicalJson(data) ?: "null",
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                    if (userMuteEvent != null) {
                        emitTimelineEvent(
                            event = userMuteEvent,
                            sessionEpoch = sessionEpoch,
                        )
                    }
                }
            }

            override fun onUserStartedSpeaking() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    if (!isLocalMicSendingAudio()) {
                        emitMutedLocalAudioState(sessionEpoch)
                        return@runOnMain
                    }
                    emitTimelineEvent(
                        event = SpeakingEvent(state = SpeakingState.USER_STARTED_SPEAKING),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onUserStoppedSpeaking() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    if (!isLocalMicSendingAudio()) {
                        emitMutedLocalAudioState(sessionEpoch)
                        return@runOnMain
                    }
                    emitTimelineEvent(
                        event = SpeakingEvent(state = SpeakingState.USER_STOPPED_SPEAKING),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotStartedSpeaking() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = SpeakingEvent(state = SpeakingState.BOT_STARTED_SPEAKING),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotStoppedSpeaking() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = SpeakingEvent(state = SpeakingState.BOT_STOPPED_SPEAKING),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotOutput(data: BotOutputData) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = BotOutputEvent(
                            text = data.text,
                            isSpoken = data.spoken,
                            aggregatedBy = data.aggregatedBy,
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onUserTranscript(data: Transcript) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = UserTranscriptionEvent(
                            text = data.text,
                            isFinal = data.final,
                            timestamp = data.timestamp ?: "",
                            userId = data.userId ?: "",
                        ),
                        sessionEpoch = sessionEpoch,
                    )
                    emitMutedMicTranscriptDiagnosticIfNeeded(
                        transcript = data,
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotLLMText(data: MsgServerToClient.Data.BotLLMTextData) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = BotLLMText(text = data.text),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotTTSText(data: MsgServerToClient.Data.BotTTSTextData) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = BotTTSText(text = data.text),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onLLMFunctionCall(functionCallData: LLMFunctionCallData) {
                // Deprecated wire path (`llm-function-call`). Modern pipecat
                // servers emit the three lifecycle messages
                // (`llm-function-call-started/-in-progress/-stopped`); the
                // Android SDK does not yet decode them natively, so for now
                // Android clients receive tool calls via the Dart-side
                // server-message compat-bridge synthesizer in
                // pipecat_flutter. Patching pipecat-client-android to mirror
                // the iOS fork is a tracked followup.
            }

            override fun onBotLLMStarted() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = ServerInsightEvent(type = InsightType.BOT_LLM_STARTED),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotLLMStopped() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = ServerInsightEvent(type = InsightType.BOT_LLM_STOPPED),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotTTSStarted() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = ServerInsightEvent(type = InsightType.BOT_TTS_STARTED),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onBotTTSStopped() {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    emitTimelineEvent(
                        event = ServerInsightEvent(type = InsightType.BOT_TTS_STOPPED),
                        sessionEpoch = sessionEpoch,
                    )
                }
            }

            override fun onInputsUpdated(camera: Boolean, mic: Boolean) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    updateInputState(sessionEpoch)
                }
            }

            override fun onUserAudioLevel(level: Float) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    if (isLocalMicSendingAudio()) {
                        localAudioHandler?.sendLevel(level.toDouble())
                    } else {
                        emitMutedLocalAudioState(sessionEpoch)
                    }
                }
            }

            override fun onRemoteAudioLevel(level: Float, participant: Participant) {
                runOnMain {
                    if (!isCurrentEpoch(sessionEpoch)) return@runOnMain
                    remoteAudioHandler?.sendLevel(level.toDouble())
                }
            }
        }
    }

    private fun parseUserMuteEventFromValue(data: Value): UserMuteEvent? {
        val root = data as? Value.Object ?: return null
        val rootMap = root.value

        val compatObj = rootMap["compat"] as? Value.Object ?: return null
        val compatBridge = (compatObj.value["bridge"] as? Value.Str)?.value ?: return null
        if (compatBridge != USER_MUTE_COMPAT_BRIDGE) {
            return null
        }

        val userMuteObj = rootMap["user_mute"] as? Value.Object
            ?: rootMap["userMute"] as? Value.Object
            ?: return null

        val status = ((userMuteObj.value["status"] as? Value.Str)?.value ?: "")
            .trim()
            .lowercase()
        val state = when (status) {
            "started" -> UserMuteState.STARTED
            "stopped" -> UserMuteState.STOPPED
            else -> return null
        }

        return UserMuteEvent(state = state)
    }
}

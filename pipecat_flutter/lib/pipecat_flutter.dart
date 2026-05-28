import 'dart:async';
import 'dart:convert';

import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';
export 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

/// Maximum number of recently-bridged tool-call ids we remember for dedupe.
const int _bridgedToolCallIdCacheCap = 128;

/// Public-facing facade for the Pipecat Flutter plugin.
class PipecatFlutter {
  PipecatFlutter._();

  /// The single shared instance of [PipecatFlutter] used throughout the app.
  static final PipecatFlutter instance = PipecatFlutter._();

  /// Convenience accessor for the current platform implementation (Android/iOS).
  PipecatFlutterPlatform get _platform => PipecatFlutterPlatform.instance;

  /// Canonical ordered timeline stream for all session events.
  Stream<TimelineEvent> get timelineEvents => _platform.timelineEventStream;

  /// Stream of unwrapped event payloads from [timelineEvents]. For each
  /// [ServerMessageEvent] this stream additionally emits a synthesized
  /// function-call lifecycle event when the payload matches a recognized
  /// envelope shape (the compat bridge or a tunneled modern frame). The
  /// original [ServerMessageEvent] is always still emitted unchanged.
  ///
  /// Each subscription gets its own dedupe state (tracked in a closure-
  /// captured set) so that multiple concurrent consumers — for example the
  /// three `llmFunctionCall*Events` filtered streams — each independently
  /// suppress the compat-bridge fallback when a native modern event has
  /// already covered the same `tool_call_id`.
  Stream<PipecatEvent> get events {
    final bridgedIds = <String>{};
    final bridgedOrder = <String>[];
    return timelineEvents.asyncExpand(
      (timelineEvent) =>
          _expandTimelineEvent(timelineEvent, bridgedIds, bridgedOrder),
    );
  }

  // ---- Filtered streams for convenience

  /// Stream containing only connection state change events (e.g., connected/disconnected).
  Stream<ConnectionStateEvent> get connectionStateEvents =>
      events.whereType<ConnectionStateEvent>();

  /// Stream containing only speaking state events (e.g., user/bot started/stopped speaking).
  Stream<SpeakingEvent> get speakingEvents => events.whereType<SpeakingEvent>();

  /// Stream containing only user transcription events
  /// (speech-to-text results from the user).
  Stream<UserTranscriptionEvent> get userTranscriptionEvents =>
      events.whereType<UserTranscriptionEvent>();

  /// Stream containing only user mute state events emitted by the server.
  Stream<UserMuteEvent> get userMuteEvents => events.whereType<UserMuteEvent>();

  /// Stream containing only LLM text events produced by the bot
  /// (model-generated text).
  Stream<BotLLMText> get botLlmTextEvents => events.whereType<BotLLMText>();

  /// Stream containing only TTS text events produced by the bot
  /// (text being spoken/synthesized).
  Stream<BotTTSText> get botTtsTextEvents => events.whereType<BotTTSText>();

  /// Stream containing only bot output events
  /// (generic bot output signals beyond pure text).
  Stream<BotOutputEvent> get botOutputEvents =>
      events.whereType<BotOutputEvent>();

  /// Stream containing only server insight events
  /// (when the LLM started and stopped).
  Stream<ServerInsightEvent> get serverInsightEvents =>
      events.whereType<ServerInsightEvent>();

  /// Stream containing only backend error events
  /// (errors originating from the platform/backend).
  Stream<BackendErrorEvent> get errorEvents =>
      events.whereType<BackendErrorEvent>();

  /// Stream containing only backend error events
  /// (errors originating from the platform/backend).
  Stream<InputStatusUpdatedEvent> get inputStatusEvents =>
      events.whereType<InputStatusUpdatedEvent>();

  /// Stream containing only bot-ready handshake events.
  Stream<BotReadyEvent> get botReadyEvents => events.whereType<BotReadyEvent>();

  /// Stream containing only raw server-message events.
  Stream<ServerMessageEvent> get serverMessageEvents =>
      events.whereType<ServerMessageEvent>();

  /// Stream containing only metrics events.
  Stream<MetricsEvent> get metricsEvents => events.whereType<MetricsEvent>();

  /// Stream containing bot connect/disconnect lifecycle events.
  Stream<BotConnectionEvent> get botConnectionEvents =>
      events.whereType<BotConnectionEvent>();

  /// Stream of `llm-function-call-started` lifecycle events.
  ///
  /// Fires when the LLM has decided to call a function but the arguments
  /// have not yet been delivered. Usually paired with
  /// [llmFunctionCallInProgressEvents] and [llmFunctionCallStoppedEvents].
  Stream<LlmFunctionCallStartedEvent> get llmFunctionCallStartedEvents =>
      events.whereType<LlmFunctionCallStartedEvent>();

  /// Stream of `llm-function-call-in-progress` lifecycle events.
  ///
  /// This is the event app code should listen to in order to actually execute
  /// a tool call — it carries the function name, tool call id, and arguments.
  /// Also fires (synthesized) when the bot emits a compat-bridge server
  /// message envelope, so this stream works against both modern and legacy
  /// pipecat runners.
  Stream<LlmFunctionCallInProgressEvent> get llmFunctionCallInProgressEvents =>
      events.whereType<LlmFunctionCallInProgressEvent>();

  /// Stream of `llm-function-call-stopped` lifecycle events.
  ///
  /// Fires when the LLM function call has finished or been cancelled.
  Stream<LlmFunctionCallStoppedEvent> get llmFunctionCallStoppedEvents =>
      events.whereType<LlmFunctionCallStoppedEvent>();

  /// Expands a single timeline event into one or more [PipecatEvent]s:
  /// always the original payload, plus any synthesized function-call
  /// lifecycle event when the payload is a recognized server-message
  /// envelope. Native modern events arrive via the platform stream directly
  /// and are still passed through unchanged; this method only synthesizes
  /// *additional* events for server-message-tunneled payloads.
  Stream<PipecatEvent> _expandTimelineEvent(
    TimelineEvent timelineEvent,
    Set<String> bridgedIds,
    List<String> bridgedOrder,
  ) {
    final original = timelineEvent.event;
    final synthesized = _synthesizeFromEvent(
      original,
      bridgedIds,
      bridgedOrder,
    );
    if (synthesized == null) {
      return Stream<PipecatEvent>.value(original);
    }
    return Stream<PipecatEvent>.fromIterable([original, synthesized]);
  }

  /// Records that we've emitted an in-progress event for [toolCallId] so the
  /// compat-bridge synthesizer won't double-fire if the native modern event
  /// already covered it. Dedupe state is per-subscription (passed in) so
  /// concurrent consumers of [events] don't starve each other.
  void _rememberBridgedInProgress(
    String toolCallId,
    Set<String> bridgedIds,
    List<String> bridgedOrder,
  ) {
    if (bridgedIds.add(toolCallId)) {
      bridgedOrder.add(toolCallId);
      if (bridgedOrder.length > _bridgedToolCallIdCacheCap) {
        final evicted = bridgedOrder.removeAt(0);
        bridgedIds.remove(evicted);
      }
    }
  }

  /// Returns a synthesized function-call lifecycle event if [event] is a
  /// [ServerMessageEvent] whose payload matches a recognized envelope, or
  /// `null` otherwise. Also records native [LlmFunctionCallInProgressEvent]
  /// emissions so the compat-bridge fallback can dedupe against them.
  PipecatEvent? _synthesizeFromEvent(
    PipecatEvent event,
    Set<String> bridgedIds,
    List<String> bridgedOrder,
  ) {
    if (event is LlmFunctionCallInProgressEvent) {
      _rememberBridgedInProgress(event.toolCallId, bridgedIds, bridgedOrder);
      return null;
    }
    if (event is! ServerMessageEvent) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(event.rawJson);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    // Modern lifecycle messages tunneled via server-message:
    //   { "type": "llm-function-call-(started|in-progress|stopped)",
    //     "data": { … } }
    final type = decoded['type'];
    if (type is String) {
      final data = decoded['data'];
      final dataMap = data is Map<String, Object?> ? data : null;
      switch (type) {
        case 'llm-function-call-started':
          return LlmFunctionCallStartedEvent(
            functionName: _asString(dataMap?['function_name']),
          );
        case 'llm-function-call-in-progress':
          final toolCallId = _asString(dataMap?['tool_call_id']);
          if (toolCallId == null) return null;
          if (bridgedIds.contains(toolCallId)) return null;
          _rememberBridgedInProgress(toolCallId, bridgedIds, bridgedOrder);
          final args = dataMap?['arguments'];
          return LlmFunctionCallInProgressEvent(
            toolCallId: toolCallId,
            functionName: _asString(dataMap?['function_name']),
            argumentsJson: args == null ? null : jsonEncode(args),
          );
        case 'llm-function-call-stopped':
          final toolCallId = _asString(dataMap?['tool_call_id']);
          if (toolCallId == null) return null;
          final cancelled = dataMap?['cancelled'];
          final result = dataMap?['result'];
          return LlmFunctionCallStoppedEvent(
            toolCallId: toolCallId,
            cancelled: cancelled is bool && cancelled,
            functionName: _asString(dataMap?['function_name']),
            resultJson: result == null ? null : jsonEncode(result),
          );
      }
    }

    // Compat bridge v1 envelope from the bot runner:
    //   { "compat": { "bridge": "rtvi_tool_call_server_message_v1", … },
    //     "tool_call": { "id": "...", "function_name": "...",
    //                    "arguments": { … } } }
    final compat = decoded['compat'];
    final toolCall = decoded['tool_call'];
    if (compat is Map<String, Object?> &&
        compat['bridge'] == 'rtvi_tool_call_server_message_v1' &&
        toolCall is Map<String, Object?>) {
      final toolCallId = _asString(toolCall['id']);
      if (toolCallId == null) return null;
      if (bridgedIds.contains(toolCallId)) return null;
      _rememberBridgedInProgress(toolCallId, bridgedIds, bridgedOrder);
      final args = toolCall['arguments'];
      return LlmFunctionCallInProgressEvent(
        toolCallId: toolCallId,
        functionName: _asString(toolCall['function_name']),
        argumentsJson: args == null ? null : jsonEncode(args),
      );
    }

    return null;
  }

  static String? _asString(Object? value) =>
      value is String ? value : null;

  /// Start and connect to bot
  ///
  /// - [url]: API endpoint to connect to
  /// - [token]: Optional auth token (not prefixed with "Bearer ")
  /// - [enableMicrophone]: Enable microphone on start (default: true)
  /// - [enableCamera]: Enable camera on start (default: false)
  /// - [headers]: Additional HTTP headers
  /// - [connectPath]: API path (default: '/connect')
  /// - [timeoutMs]: Connection timeout in milliseconds
  Future<void> startAndConnect({
    required String url,
    String? token,
    bool enableMicrophone = true,
    bool enableCamera = false,
    Map<String, String>? headers,
    String connectPath = '/connect',
    int? timeoutMs,
  }) {
    return _platform.startAndConnect(
      StartBotParams(
        url: url,
        token: token,
        shouldEnableMicrophone: enableMicrophone,
        shouldEnableCamera: enableCamera,
        headers: headers,
        connectPath: connectPath,
        timeoutInMilliseconds: timeoutMs,
      ),
    );
  }

  /// Disconnect from session
  ///
  /// Disconnects from the current Pipecat session and
  /// releases underlying resources.
  Future<void> disconnect() {
    return _platform.disconnect();
  }

  /// Toggle the local microphone input and publishing state.
  ///
  /// Enables or disables local microphone capture and outbound publishing
  /// for the current session. Pass `isEnabled: true` to start sending user
  /// audio; `false` to stop capture/publishing.
  Future<void> toggleMicrophone({required bool isEnabled}) {
    return _platform.toggleMicrophone(isEnabled: isEnabled);
  }

  /// Toggle camera
  ///
  /// Enables or disables camera capture for the current session.
  /// Pass `isEnabled: true` to start sending video; `false` to stop.
  Future<void> toggleCamera({required bool isEnabled}) {
    return _platform.toggleCamera(isEnabled: isEnabled);
  }

  /// Mutes bot speaker output by changing the local Daily subscription.
  Future<void> muteBotMicrophone({required bool isMuted}) {
    return _platform.muteBotMicrophone(isMuted: isMuted);
  }

  /// Send typed text input directly to the bot.
  Future<void> sendText({
    required String content,
    bool? runImmediately,
    bool? audioResponse,
  }) {
    return _platform.sendText(
      content: content,
      runImmediately: runImmediately,
      audioResponse: audioResponse,
    );
  }

  /// Send LLM function call result using RTVI `llm-function-call-result`.
  Future<void> sendLlmFunctionCallResult({
    required String functionName,
    required String toolCallId,
    required String argumentsJson,
    required String resultJson,
  }) {
    return _platform.sendLlmFunctionCallResult(
      functionName: functionName,
      toolCallId: toolCallId,
      argumentsJson: argumentsJson,
      resultJson: resultJson,
    );
  }

  /// Send a custom RTVI `client-message`.
  Future<void> sendClientMessage({
    required String msgType,
    required String dataJson,
  }) {
    return _platform.sendClientMessage(
      msgType: msgType,
      dataJson: dataJson,
    );
  }

  /// Send a custom RTVI `client-message` request and await `server-response`.
  Future<SendClientRequestResult> sendClientRequest({
    required String msgType,
    required String dataJson,
  }) {
    return _platform.sendClientRequest(
      msgType: msgType,
      dataJson: dataJson,
    );
  }

  /// Local user's microphone level (0.0 - 1.0).
  ///
  /// Emits `0.0` while the local microphone is muted.
  Stream<double> get localAudioLevel =>
      _platform.localAudioLevelStream.map((e) => e.level);

  /// Remote participant's (bot) audio level (0.0 - 1.0)
  /// Updates at ~50-100ms intervals when connected
  Stream<double> get remoteAudioLevel =>
      _platform.remoteAudioLevelStream.map((e) => e.level);
}

/// Extension that adds a typed filtering helper to all streams.
/// Mimic the Rx-style `whereType<T>()` to keep the API call-sites concise.
extension _StreamWhereType on Stream<dynamic> {
  /// Filters the stream to only values that are instances of [T],
  /// then casts the stream to [Stream<T>].
  Stream<T> whereType<T>() => where((e) => e is T).cast<T>();
}

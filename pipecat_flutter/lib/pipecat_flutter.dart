import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';
export 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

/// Public-facing facade for the Pipecat Flutter plugin.
class PipecatFlutter {
  PipecatFlutter._();

  /// The single shared instance of [PipecatFlutter] used throughout the app.
  static final PipecatFlutter instance = PipecatFlutter._();

  /// Convenience accessor for the current platform implementation (Android/iOS).
  PipecatFlutterPlatform get _platform => PipecatFlutterPlatform.instance;

  /// Canonical ordered timeline stream for all session events.
  Stream<TimelineEvent> get timelineEvents => _platform.timelineEventStream;

  /// Stream of unwrapped event payloads from [timelineEvents].
  Stream<PipecatEvent> get events => timelineEvents.map((e) => e.event);

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

  /// Toggle microphone
  ///
  /// Enables or disables microphone capture for the current session.
  /// Pass `isEnabled: true` to start sending audio; `false` to stop.
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

  /// Mutes speaker output
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

  /// Local user's microphone level (0.0 - 1.0)
  /// Updates at ~50-100ms intervals when connected
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

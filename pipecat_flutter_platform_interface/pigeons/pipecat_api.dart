import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'com.kcniverba.pipecat_flutter',
    dartOut: 'lib/src/generated/pipecat_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        '../pipecat_flutter_android/android/src/main/kotlin/com/kcniverba/pipecat_flutter_android/PipecatApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.kcniverba.pipecat_flutter_android',
    ),
    swiftOut:
        '../pipecat_flutter_ios/ios/pipecat_flutter_ios/Sources/pipecat_flutter_ios/PipecatApi.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
/// Parameters for starting the bot and connecting
///
/// Used to connect to your transport (for example: a Daily room)
class StartBotParams {
  const StartBotParams({
    required this.url,
    this.token,
    this.shouldEnableMicrophone = true,
    this.shouldEnableCamera = false,
    this.headers,
    this.connectPath = '/connect',
    this.timeoutInMilliseconds,
  });

  /// API endpoint to connect to
  final String url;

  /// Optional auth token
  ///
  /// The package does not prepend "Bearer " to your token, ensure that
  /// it has the proper value first before adding it.
  final String? token;

  /// Should enable microphone when starting a call
  final bool shouldEnableMicrophone;

  /// Should enable camera when starting a call
  final bool shouldEnableCamera;

  /// Additional headers
  final Map<String, String>? headers;

  /// Defaults to `/connect`
  final String connectPath;

  /// Defaults to 30000 natively
  final int? timeoutInMilliseconds;
}

/// Parameters for sending text input to the bot.
class SendTextParams {
  const SendTextParams({
    required this.content,
    this.runImmediately,
    this.audioResponse,
  });

  /// Text content to send.
  final String content;

  /// Whether the bot should run this input immediately.
  final bool? runImmediately;

  /// Whether the bot should respond with audio.
  final bool? audioResponse;
}

/// Parameters for sending LLM function call result using RTVI standard message.
class SendLlmFunctionCallResultParams {
  const SendLlmFunctionCallResultParams({
    required this.functionName,
    required this.toolCallId,
    required this.argumentsJson,
    required this.resultJson,
  });

  /// Function name from the original LLM function call.
  final String functionName;

  /// Tool call identifier from the original LLM function call.
  final String toolCallId;

  /// JSON-serialized arguments from the original function call.
  final String argumentsJson;

  /// JSON-serialized function result payload.
  final String resultJson;
}

/// Parameters for sending a custom RTVI client-message payload.
class SendClientMessageParams {
  const SendClientMessageParams({
    required this.msgType,
    required this.dataJson,
  });

  /// Custom client message type.
  final String msgType;

  /// JSON-serialized payload for the custom message.
  final String dataJson;
}

/// Parameters for sending a request-style RTVI client-message payload.
class SendClientRequestParams {
  const SendClientRequestParams({
    required this.msgType,
    required this.dataJson,
  });

  /// Custom client request message type.
  final String msgType;

  /// JSON-serialized payload for the request.
  final String dataJson;
}

/// Result payload returned by server-response for a client request.
class SendClientRequestResult {
  const SendClientRequestResult({
    required this.msgType,
    required this.dataJson,
  });

  /// Message type echoed from server response `data.t`.
  final String msgType;

  /// JSON-serialized response payload from server response `data.d`.
  final String dataJson;
}

@HostApi()
abstract class PipecatHostApi {
  /// Starts the session and connects to your transport
  @async
  void startAndConnect(StartBotParams parameters);

  /// Acts as a dispose too
  @async
  void disconnect();

  /// Toggle local microphone input capture and outbound publishing.
  @async
  void toggleMicrophone({
    required bool isEnabled,
  });

  /// Toggle your camera
  @async
  void toggleCamera({
    required bool isEnabled,
  });

  /// Toggle bot audio by changing the local remote-audio subscription.
  @async
  void muteBotAudio({
    required bool isMuted,
  });

  /// Send typed text input to the bot.
  @async
  void sendText(SendTextParams parameters);

  /// Send LLM function call result to the bot following RTVI message schema.
  @async
  void sendLlmFunctionCallResult(SendLlmFunctionCallResultParams parameters);

  /// Send a custom RTVI client-message payload to the bot.
  @async
  void sendClientMessage(SendClientMessageParams parameters);

  /// Send a custom RTVI client-message request and await server-response.
  @async
  SendClientRequestResult sendClientRequest(SendClientRequestParams parameters);
}

// ==== EVENTS
/// Events that the client receives on a session.
sealed class PipecatEvent {}

enum ConnectionState {
  connecting,
  connected,
  disconnected,
}

/// Emitted when there's a change in the connection state.
final class ConnectionStateEvent extends PipecatEvent {
  ConnectionStateEvent({required this.state});

  final ConnectionState state;
}

/// Emitted when there's a problem connecting or during
/// the call session.
final class BackendErrorEvent extends PipecatEvent {
  BackendErrorEvent({required this.message});

  final String message;
}

/// Real-time transcription of user speech,
/// including both partial and final results.
final class UserTranscriptionEvent extends PipecatEvent {
  UserTranscriptionEvent({
    required this.text,
    required this.isFinal,
    required this.timestamp,
    required this.userId,
  });

  final String text;
  final bool isFinal;
  final String timestamp;
  final String userId;
}

/// The best-effort representation of the bot's output text, including both
/// spoken and unspoken text.
final class BotOutputEvent extends PipecatEvent {
  BotOutputEvent({
    required this.text,
    required this.isSpoken,
    required this.aggregatedBy,
  });

  /// The output text from the bot.
  final String text;

  /// Indicates if this text was spoken by the bot.
  final bool isSpoken;

  /// Indicates how the text was aggregated.
  final String aggregatedBy;
}

enum SpeakingState {
  /// Emitted when the user begins speaking
  userStartedSpeaking,

  /// Emitted when the user stops speaking
  userStoppedSpeaking,

  /// Emitted when the bot begins speaking
  botStartedSpeaking,

  /// Emitted when the bot stops speaking
  botStoppedSpeaking,
}

final class SpeakingEvent extends PipecatEvent {
  SpeakingEvent({required this.state});

  final SpeakingState state;
}

enum UserMuteState {
  started,
  stopped,
}

final class UserMuteEvent extends PipecatEvent {
  UserMuteEvent({required this.state});

  final UserMuteState state;
}

// ---- Server-Specific Insights

enum InsightType {
  botLlmStarted,
  botLlmStopped,
  botTtsStarted,
  botTtsStopped,
}

final class ServerInsightEvent extends PipecatEvent {
  ServerInsightEvent({required this.type});

  final InsightType type;
}

/// Aggregated user input text that is sent to the LLM.
final class UserLLMText extends PipecatEvent {
  UserLLMText({required this.text});

  final String text;
}

/// Individual tokens streamed from the LLM as they are generated.
final class BotLLMText extends PipecatEvent {
  BotLLMText({required this.text});

  final String text;
}

/// The per-token text output of the text-to-speech (TTS) service
/// (what the TTS actually says).
final class BotTTSText extends PipecatEvent {
  BotTTSText({required this.text});

  final String text;
}

/// Emitted when the LLM has decided to call a function (no args yet).
///
/// Corresponds to the modern pipecat RTVI message `llm-function-call-started`.
final class LlmFunctionCallStartedEvent extends PipecatEvent {
  LlmFunctionCallStartedEvent({this.functionName});

  /// May be omitted by the server based on its function-call report level.
  final String? functionName;
}

/// Emitted when the LLM function call is in flight with full call data.
///
/// Corresponds to the modern pipecat RTVI message
/// `llm-function-call-in-progress`. This is the event new app code should
/// listen to in order to actually execute the tool.
final class LlmFunctionCallInProgressEvent extends PipecatEvent {
  LlmFunctionCallInProgressEvent({
    required this.toolCallId,
    this.functionName,
    this.argumentsJson,
  });

  final String toolCallId;

  /// May be omitted by the server based on its function-call report level.
  final String? functionName;

  /// Deterministically-serialized JSON arguments payload, or null if the
  /// server omitted arguments based on its report level.
  final String? argumentsJson;
}

/// Emitted when the LLM function call has finished or been cancelled.
///
/// Corresponds to the modern pipecat RTVI message `llm-function-call-stopped`.
final class LlmFunctionCallStoppedEvent extends PipecatEvent {
  LlmFunctionCallStoppedEvent({
    required this.toolCallId,
    required this.cancelled,
    this.functionName,
    this.resultJson,
  });

  final String toolCallId;
  final bool cancelled;

  /// May be omitted by the server based on its function-call report level.
  final String? functionName;

  /// Deterministically-serialized JSON result payload, or null if the call was
  /// cancelled or the server omitted the result based on its report level.
  final String? resultJson;
}

final class InputStatusUpdatedEvent extends PipecatEvent {
  InputStatusUpdatedEvent({
    required this.isCurrentMicrophoneEnabled,
    required this.isCurrentCameraEnabled,
    required this.isBotAudioMuted,
  });

  final bool isCurrentMicrophoneEnabled;
  final bool isCurrentCameraEnabled;
  final bool isBotAudioMuted;
}

enum BotConnectionState { connected, disconnected }

final class BotConnectionEvent extends PipecatEvent {
  BotConnectionEvent({
    required this.state,
    required this.participantId,
    this.participantName,
  });

  final BotConnectionState state;
  final String participantId;
  final String? participantName;
}

final class BotReadyEvent extends PipecatEvent {
  BotReadyEvent({required this.version, this.aboutJson});

  final String version;
  final String? aboutJson;
}

final class ServerMessageEvent extends PipecatEvent {
  ServerMessageEvent({required this.rawJson});

  /// Deterministically-serialized JSON payload from RTVI server-message data.
  final String rawJson;
}

final class PipecatMetricSample {
  PipecatMetricSample({required this.processor, required this.value});

  final String processor;
  final double value;
}

final class MetricsEvent extends PipecatEvent {
  MetricsEvent({this.processing, this.ttfb, this.rawJson});

  final List<PipecatMetricSample>? processing;
  final List<PipecatMetricSample>? ttfb;

  /// Deterministically-serialized full metrics payload.
  final String? rawJson;
}

final class TimelineEvent {
  TimelineEvent({
    required this.sequence,
    required this.sessionEpoch,
    required this.emittedAtMs,
    required this.event,
  });

  final int sequence;
  final int sessionEpoch;
  final int emittedAtMs;
  final PipecatEvent event;
}

/// Audio level data for visualizers.
/// Sent at high frequency (~50-100ms intervals).
class AudioLevel {
  AudioLevel({required this.level});

  /// Normalized audio level from 0.0 (silent) to 1.0 (loud)
  final double level;
}

@EventChannelApi()
abstract class PipecatEventStreamApi {
  /// Canonical ordered timeline of session events.
  TimelineEvent timelineEvents();

  /// Local user's microphone audio level (0.0 - 1.0).
  /// High frequency (~50-100ms), use for visualizers.
  /// Native implementations emit 0.0 while the local microphone is muted.
  AudioLevel localAudioLevel();

  /// Remote participant's (bot) audio level (0.0 - 1.0)
  /// High frequency (~50-100ms), use for visualizers.
  AudioLevel remoteAudioLevel();
}

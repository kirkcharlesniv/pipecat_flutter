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

@HostApi()
abstract class PipecatHostApi {
  /// Starts the session and connects to your transport
  @async
  void startAndConnect(StartBotParams parameters);

  /// Acts as a dispose too
  @async
  void disconnect();

  /// Toggle your microphone
  @async
  void toggleMicrophone({
    required bool isEnabled,
  });

  /// Toggle your camera
  @async
  void toggleCamera({
    required bool isEnabled,
  });

  @async
  void muteBotAudio({
    required bool isMuted,
  });

  /// Send typed text input to the bot.
  @async
  void sendText(SendTextParams parameters);
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

  /// Local user's microphone audio level (0.0 - 1.0)
  /// High frequency (~50-100ms), use for visualizers.
  AudioLevel localAudioLevel();

  /// Remote participant's (bot) audio level (0.0 - 1.0)
  /// High frequency (~50-100ms), use for visualizers.
  AudioLevel remoteAudioLevel();
}

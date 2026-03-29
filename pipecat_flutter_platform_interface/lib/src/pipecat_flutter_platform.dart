// pipecat_flutter_platform_interface/lib/src/pipecat_flutter_platform.dart
import 'package:pipecat_flutter_platform_interface/src/generated/pipecat_api.g.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// {@template pipecat_flutter_platform}
/// Handles communication to native SDKs
/// {@endtemplate}
abstract class PipecatFlutterPlatform extends PlatformInterface {
  /// {@macro pipecat_flutter_platform}
  PipecatFlutterPlatform() : super(token: _token);

  static final Object _token = Object();
  static PipecatFlutterPlatform _instance = _DefaultPipecatFlutterPlatform();

  /// Get the instance of this singleton
  static PipecatFlutterPlatform get instance => _instance;

  /// Sets instance of this singleton
  static set instance(PipecatFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Canonical ordered timeline stream from native runtime.
  Stream<TimelineEvent> get timelineEventStream;

  /// Local user's microphone level (0.0 - 1.0)
  Stream<AudioLevel> get localAudioLevelStream;

  /// Remote participant's (bot) audio level (0.0 - 1.0)
  Stream<AudioLevel> get remoteAudioLevelStream;

  /// Initializes the client, and starts to connect to the room
  Future<void> startAndConnect(StartBotParams params);

  /// Disconnects to the room
  Future<void> disconnect();

  /// Toggles your microphone on or off
  Future<void> toggleMicrophone({required bool isEnabled});

  /// Toggles your camera on or off
  Future<void> toggleCamera({required bool isEnabled});

  /// Unsubscribes to the microphone stream of the bot
  Future<void> muteBotMicrophone({required bool isMuted});

  /// Send text input directly to the bot.
  Future<void> sendText({
    required String content,
    bool? runImmediately,
    bool? audioResponse,
  });

  /// Send an LLM function call result directly using RTVI standard message.
  Future<void> sendLlmFunctionCallResult({
    required String functionName,
    required String toolCallId,
    required String argumentsJson,
    required String resultJson,
  });

  /// Send a custom RTVI client-message payload.
  Future<void> sendClientMessage({
    required String msgType,
    required String dataJson,
  });

  /// Send a custom RTVI client-message request and await server-response.
  Future<SendClientRequestResult> sendClientRequest({
    required String msgType,
    required String dataJson,
  });
}

/// Default implementation using Pigeon-generated code
class _DefaultPipecatFlutterPlatform extends PipecatFlutterPlatform {
  @override
  Stream<TimelineEvent> get timelineEventStream {
    throw UnimplementedError(
      'timelineEventStream has not been implemented for this platform.',
    );
  }

  @override
  Future<void> startAndConnect(StartBotParams params) {
    throw UnimplementedError(
      'startAndConnect has not been implemented for this platform.',
    );
  }

  @override
  Future<void> disconnect() {
    throw UnimplementedError(
      'disconnect has not been implemented for this platform.',
    );
  }

  @override
  Future<void> toggleMicrophone({required bool isEnabled}) {
    throw UnimplementedError(
      'toggleMicrophone has not been implemented for this platform.',
    );
  }

  @override
  Future<void> toggleCamera({required bool isEnabled}) {
    throw UnimplementedError(
      'toggleCamera has not been implemented for this platform.',
    );
  }

  @override
  Future<void> muteBotMicrophone({required bool isMuted}) =>
      throw UnimplementedError(
        'muteBotMicrophone has not been implemented for this platform.',
      );

  @override
  Future<void> sendText({
    required String content,
    bool? runImmediately,
    bool? audioResponse,
  }) => throw UnimplementedError(
    'sendText has not been implemented for this platform.',
  );

  @override
  Future<void> sendLlmFunctionCallResult({
    required String functionName,
    required String toolCallId,
    required String argumentsJson,
    required String resultJson,
  }) => throw UnimplementedError(
    'sendLlmFunctionCallResult has not been implemented for this platform.',
  );

  @override
  Future<void> sendClientMessage({
    required String msgType,
    required String dataJson,
  }) => throw UnimplementedError(
    'sendClientMessage has not been implemented for this platform.',
  );

  @override
  Future<SendClientRequestResult> sendClientRequest({
    required String msgType,
    required String dataJson,
  }) => throw UnimplementedError(
    'sendClientRequest has not been implemented for this platform.',
  );

  @override
  Stream<AudioLevel> get localAudioLevelStream => throw UnimplementedError(
    'localAudioLevelStream has not been implemented for this platform.',
  );

  @override
  Stream<AudioLevel> get remoteAudioLevelStream => throw UnimplementedError(
    'remoteAudioLevelStream has not been implemented for this platform.',
  );
}

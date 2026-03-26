import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

/// The iOS implementation of [PipecatFlutterPlatform].
class PipecatFlutterIOS extends PipecatFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pipecat_flutter_ios');

  final _hostApi = PipecatHostApi();

  Stream<TimelineEvent>? _timelineStream;
  Stream<AudioLevel>? _localAudioStream;
  Stream<AudioLevel>? _remoteAudioStream;

  /// Registers this class as the default instance of [PipecatFlutterPlatform]
  static void registerWith() {
    PipecatFlutterPlatform.instance = PipecatFlutterIOS();
  }

  @override
  Future<void> startAndConnect(StartBotParams params) {
    return _hostApi.startAndConnect(params);
  }

  @override
  Future<void> disconnect() {
    return _hostApi.disconnect();
  }

  @override
  Future<void> toggleCamera({required bool isEnabled}) {
    return _hostApi.toggleCamera(isEnabled: isEnabled);
  }

  @override
  Future<void> toggleMicrophone({required bool isEnabled}) {
    return _hostApi.toggleMicrophone(isEnabled: isEnabled);
  }

  @override
  Future<void> muteBotMicrophone({required bool isMuted}) {
    return _hostApi.muteBotAudio(isMuted: isMuted);
  }

  @override
  Future<void> sendText({
    required String content,
    bool? runImmediately,
    bool? audioResponse,
  }) {
    return _hostApi.sendText(
      SendTextParams(
        content: content,
        runImmediately: runImmediately,
        audioResponse: audioResponse,
      ),
    );
  }

  @override
  Future<void> sendLlmFunctionCallResult({
    required String functionName,
    required String toolCallId,
    required String argumentsJson,
    required String resultJson,
  }) {
    return _hostApi.sendLlmFunctionCallResult(
      SendLlmFunctionCallResultParams(
        functionName: functionName,
        toolCallId: toolCallId,
        argumentsJson: argumentsJson,
        resultJson: resultJson,
      ),
    );
  }

  @override
  Future<void> sendClientMessage({
    required String msgType,
    required String dataJson,
  }) {
    return _hostApi.sendClientMessage(
      SendClientMessageParams(
        msgType: msgType,
        dataJson: dataJson,
      ),
    );
  }

  @override
  Stream<TimelineEvent> get timelineEventStream {
    _timelineStream ??= timelineEvents();
    return _timelineStream!;
  }

  @override
  Stream<AudioLevel> get localAudioLevelStream {
    _localAudioStream ??= localAudioLevel();
    return _localAudioStream!;
  }

  @override
  Stream<AudioLevel> get remoteAudioLevelStream {
    _remoteAudioStream ??= remoteAudioLevel();
    return _remoteAudioStream!;
  }
}

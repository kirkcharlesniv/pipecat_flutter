import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

/// The Android implementation of [PipecatFlutterPlatform].
class PipecatFlutterAndroid extends PipecatFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pipecat_flutter_android');

  final _hostApi = PipecatHostApi();

  Stream<PipecatEvent>? _eventStream;
  Stream<AudioLevel>? _localAudioStream;
  Stream<AudioLevel>? _remoteAudioStream;
  Stream<BotOutputEvent>? _botOutputStream;
  Stream<UserTranscriptionEvent>? _userTranscriptionStream;
  Stream<ConnectionStateEvent>? _connectionStateEventStream;
  Stream<SpeakingEvent>? _speakingEventStream;

  /// Registers this class as the default instance of [PipecatFlutterPlatform]
  static void registerWith() {
    PipecatFlutterPlatform.instance = PipecatFlutterAndroid();
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
  Stream<PipecatEvent> get eventStream {
    _eventStream ??= events();
    return _eventStream!;
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

  @override
  Stream<BotOutputEvent> get botOutputStream {
    _botOutputStream ??= botOutput();
    return _botOutputStream!;
  }

  @override
  Stream<UserTranscriptionEvent> get userTranscriptionStream {
    _userTranscriptionStream ??= userTranscriptions();
    return _userTranscriptionStream!;
  }

  @override
  Stream<ConnectionStateEvent> get connectionStateEventStream {
    _connectionStateEventStream ??= connectionStateEvents();
    return _connectionStateEventStream!;
  }

  @override
  Stream<SpeakingEvent> get speakingEventStream {
    _speakingEventStream ??= speakingEvents();
    return _speakingEventStream!;
  }
}

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
}

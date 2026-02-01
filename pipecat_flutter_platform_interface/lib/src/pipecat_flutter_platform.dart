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

  /// Use the Pigeon-generated events() function
  Stream<PipecatEvent> get eventStream;

  /// Initializes the client, and starts to connect to the room
  Future<void> startAndConnect(StartBotParams params);

  /// Disconnects to the room
  Future<void> disconnect();

  /// Toggles your microphone on or off
  Future<void> toggleMicrophone({required bool isEnabled});

  /// Toggles your camera on or off
  Future<void> toggleCamera({required bool isEnabled});
}

/// Default implementation using Pigeon-generated code
class _DefaultPipecatFlutterPlatform extends PipecatFlutterPlatform {
  @override
  Stream<PipecatEvent> get eventStream {
    throw UnimplementedError(
      'eventStream has not been implemented for this platform.',
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
}

import 'package:pipecat_flutter_platform_interface/src/generated/pipecat_api.g.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// {@template pipecat_flutter_platform}
/// The interface that implementations of pipecat_flutter must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `PipecatFlutter`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
/// this interface will be broken by newly added [PipecatFlutterPlatform] methods.
/// {@endtemplate}
abstract class PipecatFlutterPlatform extends PlatformInterface {
  /// {@macro pipecat_flutter_platform}
  PipecatFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static PipecatFlutterPlatform? _instance;

  /// The default instance of [PipecatFlutterPlatform] to use.
  ///
  /// Defaults to throwing an [UnimplementedError].
  static PipecatFlutterPlatform get instance {
    final instance = _instance;

    if (instance == null) {
      throw UnimplementedError(
        'No platform implementation was registered. '
        'Make sure to include pipecat_flutter_android and/or pipecat_flutter_ios '
        'in your pubspec.yaml dependencies.',
      );
    }

    return instance;
  }

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [PipecatFlutterPlatform] when they register themselves.
  static set instance(PipecatFlutterPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Starts the session and connects to your transport
  Future<void> startAndConnect(StartBotParams params) {
    throw UnimplementedError('startBotAndConnect() has not been implemented.');
  }

  /// Acts as a dispose too
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Toggle your microphone
  Future<void> toggleMicrophone({
    required bool isEnabled,
  }) {
    throw UnimplementedError('toggleMicrophone() has not been implemented.');
  }

  /// Toggle your camera
  Future<void> toggleCamera({
    required bool isEnabled,
  }) {
    throw UnimplementedError('toggleCamera() has not been implemented.');
  }
}

import 'package:pipecat_flutter_platform_interface/src/method_channel_pipecat_flutter.dart';
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

  static PipecatFlutterPlatform _instance = MethodChannelPipecatFlutter();

  /// The default instance of [PipecatFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelPipecatFlutter].
  static PipecatFlutterPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [PipecatFlutterPlatform] when they register themselves.
  static set instance(PipecatFlutterPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Return the current platform name.
  Future<String?> getPlatformName();
}

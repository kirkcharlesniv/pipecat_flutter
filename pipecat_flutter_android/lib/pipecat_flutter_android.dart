import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

/// The Android implementation of [PipecatFlutterPlatform].
class PipecatFlutterAndroid extends PipecatFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pipecat_flutter_android');

  /// Registers this class as the default instance of [PipecatFlutterPlatform]
  static void registerWith() {
    PipecatFlutterPlatform.instance = PipecatFlutterAndroid();
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}

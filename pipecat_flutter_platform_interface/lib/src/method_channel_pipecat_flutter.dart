import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

/// An implementation of [PipecatFlutterPlatform] that uses method channels.
class MethodChannelPipecatFlutter extends PipecatFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pipecat_flutter');

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecat_flutter_android/pipecat_flutter_android.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PipecatFlutterAndroid', () {
    const kPlatformName = 'Android';
    late PipecatFlutterAndroid pipecatFlutter;
    late List<MethodCall> log;

    setUp(() async {
      pipecatFlutter = PipecatFlutterAndroid();

      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pipecatFlutter.methodChannel, (methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getPlatformName':
            return kPlatformName;
          default:
            return null;
        }
      });
    });

    test('can be registered', () {
      PipecatFlutterAndroid.registerWith();
      expect(PipecatFlutterPlatform.instance, isA<PipecatFlutterAndroid>());
    });

    test('getPlatformName returns correct name', () async {
      final name = await pipecatFlutter.getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(name, equals(kPlatformName));
    });
  });
}

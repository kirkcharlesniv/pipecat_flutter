import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecat_flutter_ios/pipecat_flutter_ios.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PipecatFlutterIOS', () {
    const kPlatformName = 'iOS';
    late PipecatFlutterIOS pipecatFlutter;
    late List<MethodCall> log;

    setUp(() async {
      pipecatFlutter = PipecatFlutterIOS();

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
      PipecatFlutterIOS.registerWith();
      expect(PipecatFlutterPlatform.instance, isA<PipecatFlutterIOS>());
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

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pipecat_flutter/pipecat_flutter.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPipecatFlutterPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PipecatFlutterPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(PipecatFlutterPlatform, () {
    late PipecatFlutterPlatform pipecatFlutterPlatform;

    setUp(() {
      pipecatFlutterPlatform = MockPipecatFlutterPlatform();
      PipecatFlutterPlatform.instance = pipecatFlutterPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name when platform implementation exists',
          () async {
        const platformName = '__test_platform__';
        when(
          () => pipecatFlutterPlatform.getPlatformName(),
        ).thenAnswer((_) async => platformName);

        final actualPlatformName = await getPlatformName();
        expect(actualPlatformName, equals(platformName));
      });

      test('throws exception when platform implementation is missing',
          () async {
        when(
          () => pipecatFlutterPlatform.getPlatformName(),
        ).thenAnswer((_) async => null);

        expect(getPlatformName, throwsException);
      });
    });
  });
}

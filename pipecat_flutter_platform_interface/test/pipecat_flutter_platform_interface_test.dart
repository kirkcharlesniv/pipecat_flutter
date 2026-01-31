import 'package:flutter_test/flutter_test.dart';
import 'package:pipecat_flutter_platform_interface/pipecat_flutter_platform_interface.dart';

class PipecatFlutterMock extends PipecatFlutterPlatform {
  static const mockPlatformName = 'Mock';

  @override
  Future<String?> getPlatformName() async => mockPlatformName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PipecatFlutterPlatformInterface', () {
    late PipecatFlutterPlatform pipecatFlutterPlatform;

    setUp(() {
      pipecatFlutterPlatform = PipecatFlutterMock();
      PipecatFlutterPlatform.instance = pipecatFlutterPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name', () async {
        expect(
          await PipecatFlutterPlatform.instance.getPlatformName(),
          equals(PipecatFlutterMock.mockPlatformName),
        );
      });
    });
  });
}

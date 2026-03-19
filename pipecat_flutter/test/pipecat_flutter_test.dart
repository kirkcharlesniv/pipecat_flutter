import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipecat_flutter/pipecat_flutter.dart';

class _FakePlatform extends PipecatFlutterPlatform {
  final timelineController = StreamController<TimelineEvent>.broadcast();
  final localAudioController = StreamController<AudioLevel>.broadcast();
  final remoteAudioController = StreamController<AudioLevel>.broadcast();
  String? lastFunctionName;
  String? lastToolCallId;
  String? lastArgumentsJson;
  String? lastResultJson;

  @override
  Stream<TimelineEvent> get timelineEventStream => timelineController.stream;

  @override
  Stream<AudioLevel> get localAudioLevelStream => localAudioController.stream;

  @override
  Stream<AudioLevel> get remoteAudioLevelStream => remoteAudioController.stream;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> muteBotMicrophone({required bool isMuted}) async {}

  @override
  Future<void> sendText({
    required String content,
    bool? runImmediately,
    bool? audioResponse,
  }) async {}

  @override
  Future<void> sendLlmFunctionCallResult({
    required String functionName,
    required String toolCallId,
    required String argumentsJson,
    required String resultJson,
  }) async {
    lastFunctionName = functionName;
    lastToolCallId = toolCallId;
    lastArgumentsJson = argumentsJson;
    lastResultJson = resultJson;
  }

  @override
  Future<void> startAndConnect(StartBotParams params) async {}

  @override
  Future<void> toggleCamera({required bool isEnabled}) async {}

  @override
  Future<void> toggleMicrophone({required bool isEnabled}) async {}

  Future<void> close() async {
    await timelineController.close();
    await localAudioController.close();
    await remoteAudioController.close();
  }
}

void main() {
  group('PipecatFlutter timeline facade', () {
    late _FakePlatform fakePlatform;

    setUp(() {
      fakePlatform = _FakePlatform();
      PipecatFlutterPlatform.instance = fakePlatform;
    });

    tearDown(() async {
      await fakePlatform.close();
    });

    test('events stream unwraps timeline events in order', () async {
      final emitted = <PipecatEvent>[];
      final sub = PipecatFlutter.instance.events.listen(emitted.add);

      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: 1,
          sessionEpoch: 1,
          emittedAtMs: 1000,
          event: ConnectionStateEvent(state: ConnectionState.connecting),
        ),
      );
      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: 2,
          sessionEpoch: 1,
          emittedAtMs: 1001,
          event: SpeakingEvent(state: SpeakingState.botStartedSpeaking),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted, hasLength(2));
      expect(emitted.first, isA<ConnectionStateEvent>());
      expect(emitted.last, isA<SpeakingEvent>());
    });

    test('convenience filtered streams are sourced from timeline', () async {
      final connectionStates = <ConnectionState>[];
      final speakingStates = <SpeakingState>[];

      final connectionSub = PipecatFlutter.instance.connectionStateEvents
          .listen(
            (event) => connectionStates.add(event.state),
          );
      final speakingSub = PipecatFlutter.instance.speakingEvents.listen(
        (event) => speakingStates.add(event.state),
      );

      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: 1,
          sessionEpoch: 7,
          emittedAtMs: 1,
          event: ConnectionStateEvent(state: ConnectionState.connected),
        ),
      );
      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: 2,
          sessionEpoch: 7,
          emittedAtMs: 2,
          event: SpeakingEvent(state: SpeakingState.userStartedSpeaking),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await connectionSub.cancel();
      await speakingSub.cancel();

      expect(connectionStates, [ConnectionState.connected]);
      expect(speakingStates, [SpeakingState.userStartedSpeaking]);
    });

    test('botLlmTextEvents reads from timeline, not audio streams', () async {
      final botLlm = <BotLLMText>[];
      final sub = PipecatFlutter.instance.botLlmTextEvents.listen(botLlm.add);

      fakePlatform.localAudioController.add(AudioLevel(level: 0.9));
      fakePlatform.remoteAudioController.add(AudioLevel(level: 0.7));

      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: 1,
          sessionEpoch: 3,
          emittedAtMs: 99,
          event: BotLLMText(text: 'hello world'),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(botLlm, hasLength(1));
      expect(botLlm.single.text, 'hello world');
    });

    test('sendLlmFunctionCallResult forwards payload unchanged', () async {
      await PipecatFlutter.instance.sendLlmFunctionCallResult(
        functionName: 'select_coach',
        toolCallId: 'tool-123',
        argumentsJson: '{"coachSlug":"john"}',
        resultJson: '{"ok":true}',
      );

      expect(fakePlatform.lastFunctionName, 'select_coach');
      expect(fakePlatform.lastToolCallId, 'tool-123');
      expect(fakePlatform.lastArgumentsJson, '{"coachSlug":"john"}');
      expect(fakePlatform.lastResultJson, '{"ok":true}');
    });
  });
}

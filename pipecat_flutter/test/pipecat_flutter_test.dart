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
  String? lastClientMessageType;
  String? lastClientMessageDataJson;
  String? lastClientRequestType;
  String? lastClientRequestDataJson;

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
  Future<void> sendClientMessage({
    required String msgType,
    required String dataJson,
  }) async {
    lastClientMessageType = msgType;
    lastClientMessageDataJson = dataJson;
  }

  @override
  Future<SendClientRequestResult> sendClientRequest({
    required String msgType,
    required String dataJson,
  }) async {
    lastClientRequestType = msgType;
    lastClientRequestDataJson = dataJson;
    return SendClientRequestResult(
      msgType: msgType,
      dataJson: dataJson,
    );
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
      final userMuteStates = <UserMuteState>[];

      final connectionSub = PipecatFlutter.instance.connectionStateEvents
          .listen(
            (event) => connectionStates.add(event.state),
          );
      final speakingSub = PipecatFlutter.instance.speakingEvents.listen(
        (event) => speakingStates.add(event.state),
      );
      final userMuteSub = PipecatFlutter.instance.userMuteEvents.listen(
        (event) => userMuteStates.add(event.state),
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
      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: 3,
          sessionEpoch: 7,
          emittedAtMs: 3,
          event: UserMuteEvent(state: UserMuteState.started),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await connectionSub.cancel();
      await speakingSub.cancel();
      await userMuteSub.cancel();

      expect(connectionStates, [ConnectionState.connected]);
      expect(speakingStates, [SpeakingState.userStartedSpeaking]);
      expect(userMuteStates, [UserMuteState.started]);
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

    test('sendClientMessage forwards payload unchanged', () async {
      await PipecatFlutter.instance.sendClientMessage(
        msgType: 'onboarding.voice_preview.request',
        dataJson: '{"request_id":"abc"}',
      );

      expect(
        fakePlatform.lastClientMessageType,
        'onboarding.voice_preview.request',
      );
      expect(fakePlatform.lastClientMessageDataJson, '{"request_id":"abc"}');
    });

    test('sendClientRequest forwards payload and returns response', () async {
      final result = await PipecatFlutter.instance.sendClientRequest(
        msgType: 'onboarding.state.sync',
        dataJson: '{"stateRevision":1}',
      );

      expect(fakePlatform.lastClientRequestType, 'onboarding.state.sync');
      expect(fakePlatform.lastClientRequestDataJson, '{"stateRevision":1}');
      expect(result.msgType, 'onboarding.state.sync');
      expect(result.dataJson, '{"stateRevision":1}');
    });
  });

  group('Server-message function-call synthesizer', () {
    late _FakePlatform fakePlatform;

    setUp(() {
      fakePlatform = _FakePlatform();
      PipecatFlutterPlatform.instance = fakePlatform;
    });

    tearDown(() async {
      await fakePlatform.close();
    });

    void pushServerMessage(String rawJson, {int sequence = 1}) {
      fakePlatform.timelineController.add(
        TimelineEvent(
          sequence: sequence,
          sessionEpoch: 1,
          emittedAtMs: 1000 + sequence,
          event: ServerMessageEvent(rawJson: rawJson),
        ),
      );
    }

    test(
      'compat bridge envelope synthesizes an in-progress event alongside the '
      'original server message',
      () async {
        final emitted = <PipecatEvent>[];
        final sub = PipecatFlutter.instance.events.listen(emitted.add);

        pushServerMessage(
          '{"compat":{"bridge":"rtvi_tool_call_server_message_v1",'
          '"source":"trt-bot-runner"},'
          '"tool_call":{"id":"tc-1","function_name":"set_identity_candidate",'
          '"arguments":{"userName":"Charles"}}}',
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(emitted, hasLength(2));
        expect(emitted.first, isA<ServerMessageEvent>());
        final synthesized =
            emitted.last as LlmFunctionCallInProgressEvent;
        expect(synthesized.toolCallId, 'tc-1');
        expect(synthesized.functionName, 'set_identity_candidate');
        expect(synthesized.argumentsJson, '{"userName":"Charles"}');
      },
    );

    test(
      'native in-progress event suppresses the compat-bridge synthesis for the '
      'same toolCallId',
      () async {
        final inProgressEvents = <LlmFunctionCallInProgressEvent>[];
        final sub = PipecatFlutter.instance.llmFunctionCallInProgressEvents
            .listen(inProgressEvents.add);

        fakePlatform.timelineController.add(
          TimelineEvent(
            sequence: 1,
            sessionEpoch: 1,
            emittedAtMs: 1,
            event: LlmFunctionCallInProgressEvent(
              toolCallId: 'tc-2',
              functionName: 'set_identity_candidate',
              argumentsJson: '{"userName":"Charles"}',
            ),
          ),
        );
        pushServerMessage(
          '{"compat":{"bridge":"rtvi_tool_call_server_message_v1"},'
          '"tool_call":{"id":"tc-2","function_name":"set_identity_candidate",'
          '"arguments":{"userName":"Charles"}}}',
          sequence: 2,
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(inProgressEvents, hasLength(1));
        expect(inProgressEvents.single.toolCallId, 'tc-2');
      },
    );

    test('tunneled modern envelopes map to the three lifecycle events',
        () async {
      final started = <LlmFunctionCallStartedEvent>[];
      final inProgress = <LlmFunctionCallInProgressEvent>[];
      final stopped = <LlmFunctionCallStoppedEvent>[];

      final startedSub = PipecatFlutter
          .instance.llmFunctionCallStartedEvents
          .listen(started.add);
      final inProgressSub = PipecatFlutter
          .instance.llmFunctionCallInProgressEvents
          .listen(inProgress.add);
      final stoppedSub = PipecatFlutter
          .instance.llmFunctionCallStoppedEvents
          .listen(stopped.add);

      pushServerMessage(
        '{"type":"llm-function-call-started",'
        '"data":{"function_name":"set_identity_candidate"}}',
      );
      pushServerMessage(
        '{"type":"llm-function-call-in-progress",'
        '"data":{"tool_call_id":"tc-3",'
        '"function_name":"set_identity_candidate",'
        '"arguments":{"userName":"Charles"}}}',
        sequence: 2,
      );
      pushServerMessage(
        '{"type":"llm-function-call-stopped",'
        '"data":{"tool_call_id":"tc-3","cancelled":false,'
        '"function_name":"set_identity_candidate",'
        '"result":{"status":"acknowledged"}}}',
        sequence: 3,
      );

      await Future<void>.delayed(Duration.zero);
      await startedSub.cancel();
      await inProgressSub.cancel();
      await stoppedSub.cancel();

      expect(started.single.functionName, 'set_identity_candidate');
      expect(inProgress.single.toolCallId, 'tc-3');
      expect(inProgress.single.argumentsJson, '{"userName":"Charles"}');
      expect(stopped.single.toolCallId, 'tc-3');
      expect(stopped.single.cancelled, isFalse);
      expect(stopped.single.resultJson, '{"status":"acknowledged"}');
    });

    test(
      'malformed JSON and unrecognized shapes do not synthesize and do not '
      'throw',
      () async {
        final synthesized = <PipecatEvent>[];
        final sub = PipecatFlutter.instance.events
            .where(
              (event) =>
                  event is LlmFunctionCallStartedEvent ||
                  event is LlmFunctionCallInProgressEvent ||
                  event is LlmFunctionCallStoppedEvent,
            )
            .listen(synthesized.add);

        pushServerMessage('not json at all');
        pushServerMessage('{"type":"some-other-event"}', sequence: 2);
        pushServerMessage(
          '{"type":"llm-function-call-in-progress","data":{}}',
          sequence: 3,
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(synthesized, isEmpty);
      },
    );
  });
}

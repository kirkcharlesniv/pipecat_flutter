# pipecat_flutter

A Flutter **federated plugin** that provides a **Pipecat SDK** implementation for:

- **Android (Kotlin)**
- **iOS (Swift)**

---

## Supported Platforms

| Platform | Supported |
| -------- | --------- |
| Android  | ✅        |
| iOS      | ✅        |
| Web      | ❌        |
| Windows  | ❌        |
| macOS    | ❌        |
| Linux    | ❌        |

---

## Features

### Implemented API (Dart)

| Method       | Description                                                       |
| ------------ | ----------------------------------------------------------------- |
| `connect`    | Creates and connects a Pipecat client using the native transport. |
| `disconnect` | Disconnects and releases the native client/transport.             |

> Note: The native implementation uses a Daily transport (`DailyTransport`) under the hood.

---

## Event Streams

The plugin exposes multiple event streams (Android Kotlin + iOS Swift mirror the same set of streams).

| Stream                  | Purpose                                   | Typical Payload                                     |
| ----------------------- | ----------------------------------------- | --------------------------------------------------- |
| `events`                | General server/client events and insights | backend errors, LLM/TTS text, server insight events |
| `localAudioLevel`       | Local user audio energy/level             | `double` level                                      |
| `remoteAudioLevel`      | Remote participant audio energy/level     | `double` level                                      |
| `botOutput`             | Bot output messages                       | text, spoken flag, aggregated-by metadata           |
| `userTranscriptions`    | User transcription updates                | text, isFinal, timestamp, userId                    |
| `connectionStateEvents` | Connection lifecycle & state transitions  | connecting/connected/disconnected                   |
| `speakingEvents`        | Speaking activity events                  | user/bot started/stopped                            |
| `inputStatusEvents`     | Mic/cam/bot-audio mute state changes      | micEnabled, camEnabled, botAudioMuted               |

---

## Usage

### Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  pipecat_flutter: ^<latest>
```

### Connect / Disconnect

```dart
await PipecatFlutter.instance.startAndConnect(
  url: roomUrl,
  token: meetingToken,
  enableMicrophone: true,
  enableCamera: false,
);

await PipecatFlutter.instance.disconnect();
```

### Listen to streams

```dart
PipecatFlutter.instance.connectionStateEvents.listen((state) {
  // CONNECTING / CONNECTED / DISCONNECTED
});

PipecatFlutter.instance.userTranscriptionEvents.listen((t) {
  // text, isFinal, timestamp, userId
});

PipecatFlutter.instance.botOutputEvents.listen((o) {
  // text, isSpoken, aggregatedBy
});
```

### Platform Notes

#### Android

Implemented in Kotlin with PipecatClient<DailyTransport, DailyTransportConnectParams>.

Emits connection state based on transport state transitions.

Supports local/remote audio level callbacks, transcription, bot output, and server insight events.

#### iOS

Implemented in Swift 6 with equivalent stream/event mappings from `PipecatClientDelegate`

## Contributing

Issues and pull requests are welcome. Please run:

```sh
dart format .

dart analyze

flutter test
```

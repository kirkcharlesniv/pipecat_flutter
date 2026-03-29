# pipecat_flutter (workspace)

Federated Flutter plugin workspace for Pipecat realtime voice sessions.

## Messaging APIs

Use the right channel for the job:

- `sendClientMessage(...)`: fire-and-forget `client-message`.
- `sendClientRequest(...)`: request/response `client-message` that waits for `server-response` (or `error-response`).
- `sendText(...)`: sends user text into LLM conversation context. Do not use for control-plane state sync.

## Why `sendClientRequest` exists

State synchronization and workflow transitions should be acknowledged by the server.
`sendClientRequest` uses RTVI request correlation (`id`) so callers can:

- know when the server accepted a request,
- fail closed on timeout/error,
- avoid assuming state was applied.

## `sendClientMessage` example (fire-and-forget)

```dart
await PipecatFlutter.instance.sendClientMessage(
  msgType: 'onboarding.voice_preview.request',
  dataJson: '{"request_id":"abc-123","coachSlug":"John"}',
);
```

## `sendClientRequest` example (acknowledged)

```dart
import 'dart:convert';

final requestPayload = {
  'screen': 'SelectCoaches',
  'selectedLanguage': 'en-GB',
  'selectedPurpose': 'goal',
  'allowedPurposeOptionIds': ['challenge', 'goal', 'roleplay'],
  'allowedCoachSlugs': ['John'],
  'allowedCoaches': [
    {'slug': 'John', 'name': 'Jonathan'},
  ],
  'isGuest': true,
  'stateRevision': 7,
  'runImmediately': true,
};

final response = await PipecatFlutter.instance.sendClientRequest(
  msgType: 'onboarding.state.sync',
  dataJson: jsonEncode(requestPayload),
);

final responseType = response.msgType; // server-response data.t
final responseData = jsonDecode(response.dataJson); // server-response data.d
```

## Error behavior

`sendClientRequest` throws platform exceptions on failure. Normalized error codes:

- `SEND_CLIENT_REQUEST_TIMEOUT`: request timed out waiting for `server-response`.
- `SEND_CLIENT_REQUEST_ERROR_RESPONSE`: backend returned RTVI `error-response`.
- `SEND_CLIENT_REQUEST_ERROR`: request failed for other reasons.
- `NO_CLIENT`: session is not connected/ready.

Recommended caller behavior for critical state sync is fail-closed: treat any thrown exception as not applied.

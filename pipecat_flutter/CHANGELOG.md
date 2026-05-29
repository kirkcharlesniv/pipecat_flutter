## 3.0.1

- fix: Ship the Android and iOS native microphone-state rewrite with authoritative Daily input plus publishing reconciliation.
- fix: Keep mute/unmute completion listener-driven, with bounded fallback polling instead of optimistic state flips.
- fix: Align the vendored iOS Daily dependency to `0.37.0`.
- chore: Raise endorsed platform minimums to `pipecat_flutter_android 3.0.1` and `pipecat_flutter_ios 3.0.4`.

## 3.0.0

- **BREAKING**: Remove `LlmFunctionCallEvent`. Migrate to the new
  `LlmFunctionCallStartedEvent` / `LlmFunctionCallInProgressEvent` /
  `LlmFunctionCallStoppedEvent` lifecycle. The in-progress event is the one
  app code should listen to for actually executing tools.
- feat: Expose `llmFunctionCallStartedEvents`, `llmFunctionCallInProgressEvents`,
  and `llmFunctionCallStoppedEvents` filtered streams on `PipecatFlutter`.
- feat: Add a Dart-side synthesizer on `events` that recognizes the legacy
  `rtvi_tool_call_server_message_v1` compat bridge and the three modern
  lifecycle messages when they are tunneled via `server-message`, and emits
  the matching new event. Dedupe is per-subscription so native and
  synthesized in-progress events for the same `toolCallId` aren't double-fired.

## 2.4.1

- fix: Make local microphone mute state authoritative and self-healing against Daily input and publishing state.
- fix: Keep local audio visualizer and user-speaking events silent while the local microphone is muted.
- docs: Clarify local microphone control versus bot-audio subscription muting.

## 2.4.0

- fix: Android bot audio muting now uses correct subscription API.
- fix: iOS and Android bot participant ID stored on connect for stable mute targeting.
- feat: Android reactive track state via `CallClientListener`.

## 2.3.0

- feat: Add transport diagnostics.
- feat: Add sub-phases connection statuses.

## 2.2.0

- chore: Bump package version to `2.2.0`.

## 2.1.0

- feat: Implement `client-message`

## 2.0.2

- feat: send LLM tool call result
- fix: missing argument for parameter

## 2.0.0

- Refactor: single canonical stream

## 0.2.0+3

- Update federated dependency constraints to `^0.2.0`.

## 0.2.0+2

- Integrate `sendText`

## 0.1.0+1

- Integrates native SDK

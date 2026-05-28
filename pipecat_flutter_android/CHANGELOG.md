## 3.0.0

- **BREAKING**: Drop `LlmFunctionCallEvent` emission. Migrate to the new
  `LlmFunctionCall{Started,InProgress,Stopped}Event` lifecycle exposed by
  `pipecat_flutter` 3.0.0.
- chore: `onLLMFunctionCall` is a no-op pending an Android-side SDK patch
  mirroring iOS. Until then, Android clients receive tool calls via the
  Dart-side compat-bridge synthesizer in `pipecat_flutter` (the bot runner's
  `rtvi_tool_call_server_message_v1` envelope).

## 2.4.1

- fix: Make local microphone mute state authoritative and self-healing against Daily input and publishing state.
- fix: Force local audio levels and user-speaking events to silence while the local microphone is muted.

## 2.4.0

- fix: Replace broken `updateRemoteParticipants` bot audio muting with correct `updateSubscriptionsForParticipants` (local subscription control).
- fix: Store bot participant ID on `onBotConnected` instead of fragile runtime lookup.
- fix: Set `isBotAudioMuted` only after async subscription call succeeds.
- feat: Register `CallClientListener` for reactive `onInputsUpdated` and `onSubscriptionsUpdated` track events.
- fix: Return `BOT_NOT_CONNECTED` error if `muteBotAudio` called before bot joins.

## 2.3.0

- feat: Add transport diagnostics.
- feat: Add sub-phases connection statuses.

## 2.2.0

- chore: Bump package version to `2.2.0`.

## 2.1.0

- feat: Implement `client-message`

## 2.0.5

- Fix: Delay call of release() on failed connection

## 2.0.4

- Fix: SIGSEGV

## 2.0.3

- Fix: type mismatch for LLMFunctionCallData.args after pipecat client SDK update (Value? → JsonElement)

## 2.0.2

- feat: send LLM tool call result
- fix: missing argument for parameter

## 2.0.1

- Fix: failed to build in Android

## 2.0.0

- Refactor: single canonical stream

## 0.2.0+3

- Update `pipecat_flutter_platform_interface` dependency constraint to `^0.2.0`.

## 0.2.0+2

- Integrate `sendText`

## 0.1.0+1

- Integrates `ai.pipecat:daily-transport:1.1.0`
